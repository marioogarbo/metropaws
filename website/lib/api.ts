import axios from 'axios';
import Cookies from 'js-cookie';

// Prod backend is the default so a deployed build never silently falls back to
// localhost (which made the reset-password POST fail with no response). For a
// local backend, set NEXT_PUBLIC_API_URL=http://localhost:8000 in .env.local.
const BASE = process.env.NEXT_PUBLIC_API_URL || 'https://metropaws-backend.onrender.com';
const COOKIE_OPTS: Cookies.CookieAttributes = { path: '/', sameSite: 'lax', expires: 7 };

export const api = axios.create({ baseURL: BASE });

api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('mp_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (typeof window !== 'undefined' && err?.response?.status === 401) {
      logout();
      window.location.href = '/admin/login';
    }
    return Promise.reject(err);
  }
);

// --- Types ---
export interface TokenResponse {
  access_token: string;
  token_type: string;
  role: 'member' | 'admin' | 'clinic';
  member_id?: string;
  user_id: string;
}

export interface ServiceType {
  id: string;
  name: string;
  description?: string;
  icon: string;
}

export interface MemberService {
  id: string;
  service_type: ServiceType;
  total_sessions: number;
  used_sessions: number;
  remaining_sessions: number;
  expires_at?: string;
}

export interface Pet {
  id: string;
  name: string;
  breed?: string;
  age_years?: number;
  weight_kg?: number;
  photo_url?: string;
  vax_card_url?: string;
  notes?: string;
  created_at: string;
  plan_id: string | null;
  plan_type: string | null;
  plan_activated_at: string | null;
}

export interface Member {
  id: string;
  user_id: string;
  email?: string;
  first_name: string;
  last_name: string;
  phone?: string;
  address?: string;
  plan_type: string;
  qr_token: string;
  is_founding: boolean;
  previous_plan_tier: string | null;
  joined_at: string;
  pets: Pet[];
  services: MemberService[];
}

export interface Founding50Status {
  enabled: boolean;
  limit: number;
  claimed: number;
}

export interface Plan {
  id: string;
  name: string;
  price: number;
  price_monthly?: number;
  tagline?: string;
  features: string[];
  is_featured: boolean;
  is_active: boolean;
  sort_order: number;
}

export interface PlanCreate {
  name: string;
  price: number;
  price_monthly?: number;
  tagline?: string;
  features: string[];
  is_featured: boolean;
  is_active: boolean;
  sort_order: number;
}

// --- Auth ---
export async function login(email: string, password: string): Promise<TokenResponse> {
  const { data } = await api.post<TokenResponse>('/auth/login', { email, password });
  localStorage.setItem('mp_token', data.access_token);
  localStorage.setItem('mp_role', data.role);
  if (data.member_id) localStorage.setItem('mp_member_id', data.member_id);
  localStorage.setItem('mp_user_id', data.user_id);
  Cookies.set('mp_token', data.access_token, COOKIE_OPTS);
  Cookies.set('mp_role', data.role, COOKIE_OPTS);
  return data;
}

export async function register(payload: {
  email: string; password: string; first_name: string; last_name: string; phone: string; address?: string;
}): Promise<TokenResponse> {
  const { data } = await api.post<TokenResponse>('/auth/register', { ...payload, role: 'member' });
  localStorage.setItem('mp_token', data.access_token);
  localStorage.setItem('mp_role', data.role);
  if (data.member_id) localStorage.setItem('mp_member_id', data.member_id);
  Cookies.set('mp_token', data.access_token, COOKIE_OPTS);
  Cookies.set('mp_role', data.role, COOKIE_OPTS);
  return data;
}

export function logout() {
  localStorage.removeItem('mp_token');
  localStorage.removeItem('mp_role');
  localStorage.removeItem('mp_member_id');
  localStorage.removeItem('mp_user_id');
  Cookies.remove('mp_token', { path: '/' });
  Cookies.remove('mp_role', { path: '/' });
}

export function getRole(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('mp_role');
}

export function isAuthenticated(): boolean {
  if (typeof window === 'undefined') return false;
  return !!localStorage.getItem('mp_token');
}

export async function forgotPassword(email: string): Promise<{ message: string }> {
  const { data } = await api.post<{ message: string }>('/auth/forgot-password', { email });
  return data;
}

export async function resetPassword(token: string, newPassword: string): Promise<{ message: string }> {
  const { data } = await api.post<{ message: string }>('/auth/reset-password', { token, new_password: newPassword });
  return data;
}

// --- Member ---
export async function getMyProfile(): Promise<Member> {
  const { data } = await api.get<Member>('/members/me');
  return data;
}

// --- Admin: Member Management ---
export interface MemberCreate {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  phone?: string;
  address?: string;
}

export interface MemberUpdate {
  first_name?: string;
  last_name?: string;
  phone?: string;
  address?: string;
}

export async function createMember(payload: MemberCreate): Promise<Member> {
  const { data } = await api.post<Member>('/admin/members', payload);
  return data;
}

export async function updateMember(id: string, payload: MemberUpdate): Promise<Member> {
  const { data } = await api.put<Member>(`/admin/members/${id}`, payload);
  return data;
}

export async function deleteMember(id: string): Promise<void> {
  await api.delete(`/admin/members/${id}`);
}

export async function listMembers(): Promise<Member[]> {
  const { data } = await api.get<Member[]>('/admin/members');
  return data;
}

export async function listServiceTypes(): Promise<ServiceType[]> {
  const { data } = await api.get<ServiceType[]>('/admin/service-types');
  return data;
}

export async function assignService(payload: {
  member_id: string; service_type_id: string; total_sessions: number;
}): Promise<void> {
  await api.post('/admin/assign-service', payload);
}

// --- Pets ---
export async function activatePetPlan(petId: string, planId: string): Promise<Pet> {
  const { data } = await api.post<Pet>(`/pets/${petId}/activate-plan`, { plan_id: planId });
  return data;
}

// --- Plans ---
export async function listPlans(): Promise<Plan[]> {
  const { data } = await api.get<Plan[]>('/plans');
  return data;
}

export async function listPlansAdmin(): Promise<Plan[]> {
  const { data } = await api.get<Plan[]>('/admin/plans');
  return data;
}

export async function createPlan(payload: PlanCreate): Promise<Plan> {
  const { data } = await api.post<Plan>('/admin/plans', payload);
  return data;
}

export async function updatePlan(id: string, payload: Partial<PlanCreate>): Promise<Plan> {
  const { data } = await api.put<Plan>(`/admin/plans/${id}`, payload);
  return data;
}

export async function deletePlan(id: string): Promise<void> {
  await api.delete(`/admin/plans/${id}`);
}

// --- Clinic Partners ---
export interface ClinicPartner {
  id: string;
  clinic_name: string;
  phone?: string;
  address?: string;
  user_id: string;
  email?: string;
  created_at: string;
}

export interface ClinicPartnerCreate {
  email: string;
  password: string;
  clinic_name: string;
  phone?: string;
  address?: string;
}

export async function listClinicPartners(): Promise<ClinicPartner[]> {
  const { data } = await api.get<ClinicPartner[]>('/admin/clinic-partners');
  return data;
}

export async function createClinicPartner(payload: ClinicPartnerCreate): Promise<ClinicPartner> {
  const { data } = await api.post<ClinicPartner>('/admin/clinic-partners', payload);
  return data;
}

export async function deleteClinicPartner(id: string): Promise<void> {
  await api.delete(`/admin/clinic-partners/${id}`);
}

// --- FAQs ---
export interface FAQ {
  id: string;
  question: string;
  answer: string;
  sort_order: number;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface FAQCreate {
  question: string;
  answer: string;
  sort_order?: number;
  is_published?: boolean;
}

export interface FAQUpdate {
  question?: string;
  answer?: string;
  sort_order?: number;
  is_published?: boolean;
}

export async function listFaqs(): Promise<FAQ[]> {
  const { data } = await api.get<FAQ[]>('/faqs');
  return data;
}

export async function listFaqsAdmin(): Promise<FAQ[]> {
  const { data } = await api.get<FAQ[]>('/admin/faqs');
  return data;
}

export async function createFaq(payload: FAQCreate): Promise<FAQ> {
  const { data } = await api.post<FAQ>('/admin/faqs', payload);
  return data;
}

export async function updateFaq(id: string, payload: FAQUpdate): Promise<FAQ> {
  const { data } = await api.put<FAQ>(`/admin/faqs/${id}`, payload);
  return data;
}

export async function deleteFaq(id: string): Promise<void> {
  await api.delete(`/admin/faqs/${id}`);
}

export async function reorderFaqs(ids: string[]): Promise<void> {
  await api.put('/admin/faqs/reorder', { ids });
}

// --- App Settings ---
export async function getPaymentsEnabled(): Promise<boolean> {
  const { data } = await api.get<{ payments_enabled: boolean }>('/settings/payments-enabled');
  return data.payments_enabled;
}

export async function setPaymentsEnabled(enabled: boolean): Promise<boolean> {
  const { data } = await api.put<{ payments_enabled: boolean }>(
    '/admin/settings/payments-enabled',
    { payments_enabled: enabled }
  );
  return data.payments_enabled;
}

export async function getFounding50Status(): Promise<Founding50Status> {
  const { data } = await api.get<Founding50Status>('/settings/founding-50');
  return data;
}

export async function setFounding50(enabled: boolean, limit = 50): Promise<Founding50Status> {
  const { data } = await api.put<Founding50Status>('/admin/settings/founding-50', { enabled, limit });
  return data;
}

export async function setMemberFounding(memberId: string, isFounding: boolean): Promise<Member> {
  const { data } = await api.put<Member>(`/admin/members/${memberId}/founding`, { is_founding: isFounding });
  return data;
}

// --- Founding 50 Reservations ---
export interface FoundingReservation {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  barangay: string;
  message?: string;
  status: 'pending' | 'approved' | 'rejected';
  admin_notes?: string;
  created_at: string;
}

export interface FoundingReservationSubmit {
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  barangay: string;
  message?: string;
}

export async function submitFoundingReservation(
  payload: FoundingReservationSubmit
): Promise<{ id: string; message: string }> {
  const { data } = await api.post('/founding-reservations', payload);
  return data;
}

export async function listFoundingReservations(): Promise<FoundingReservation[]> {
  const { data } = await api.get<FoundingReservation[]>('/admin/founding-reservations');
  return data;
}

export async function updateFoundingReservationStatus(
  id: string,
  status: 'pending' | 'approved' | 'rejected',
  admin_notes?: string
): Promise<FoundingReservation> {
  const { data } = await api.put<FoundingReservation>(
    `/admin/founding-reservations/${id}/status`,
    { status, admin_notes }
  );
  return data;
}
