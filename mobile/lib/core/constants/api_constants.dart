import 'package:flutter/foundation.dart' show kReleaseMode;

class ApiConstants {
  // ── Environment selection (build-time) ───────────────────────────────────
  // Pick the backend at launch with --dart-define, no code edits required:
  //   flutter run                              -> local  (http://localhost:8000)
  //   flutter run --dart-define=ENV=dev        -> dev server
  //   flutter run --dart-define=ENV=prod       -> production
  // One-off custom host (e.g. Android emulator -> host machine) takes priority:
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8000
  //
  // A release build MUST pass ENV=prod, e.g.:
  //   flutter build apk --dart-define=ENV=prod
  static const String _apiUrlOverride = String.fromEnvironment('API_URL');
  // Release builds default to 'prod' even if --dart-define=ENV is forgotten.
  // A shipped APK that fell back to localhost is exactly why Google review
  // "couldn't log in" (the reviewer's device has no backend on localhost).
  // Debug still defaults to 'local' for dev convenience; override either build
  // with --dart-define=ENV=dev|prod or --dart-define=API_URL=...
  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: kReleaseMode ? 'prod' : 'local',
  );

  /// Current build environment ('local' | 'dev' | 'prod'). Exposed for
  /// diagnostics/UI (e.g. the Account-screen version footer) so a non-prod
  /// build is instantly recognisable in the field.
  static const String env = _env;
  static const bool isProd = _env == 'prod';

  static const String baseUrl = _apiUrlOverride != ''
      ? _apiUrlOverride
      : _env == 'prod'
          ? 'https://metropaws-backend.onrender.com'
          : _env == 'dev'
              ? 'https://metropaws-backend-dev.onrender.com'
              : 'http://localhost:8000';

  // Public website URL — used for deep-links into legal pages and member
  // documents (ToS, Privacy, Member Manual). Env-aware exactly like baseUrl so a
  // dev build doesn't open the production site (a separate Vercel deployment).
  // Override for one-off previews with --dart-define=WEB_URL=https://...
  static const String _webUrlOverride = String.fromEnvironment('WEB_URL');

  static const String webUrl = _webUrlOverride != ''
      ? _webUrlOverride
      : _env == 'prod'
          ? 'https://metropaws.ph'
          : _env == 'dev'
              ? 'https://staging-metropaws.vercel.app'
              : 'http://localhost:3000';

  static const checkEmail = '/auth/check-email';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const myProfile = '/members/me';
  static const myProfilePhoto = '/members/me/photo';
  static const selectPlan = '/members/me/plan';
  static const myBookings = '/members/me/bookings';
  static const clinics = '/members/clinics';
  static const pets = '/pets/';
  static String pet(String petId) => '/pets/$petId';
  static String activatePetPlan(String petId) => '/pets/$petId/activate-plan';

  static const paymentsEnabled = '/settings/payments-enabled';
  // Feature flags read at startup (booking on standby until partner clinics).
  static const mobileConfig = '/settings/mobile-config';

  // Events & Promos (Book tab stand-in while booking is disabled)
  static const promos = '/promos';

  static String scanQr(String token) => '/admin/scan/$token';
  static const deployService = '/admin/deploy-service';
  static const listMembers = '/admin/members';
  static const listServiceTypes = '/admin/service-types';
  static const assignService = '/admin/assign-service';
  static const adminBookings = '/admin/bookings';
  static String confirmBooking(String id) => '/admin/bookings/$id/confirm';
  static String cancelBooking(String id) => '/admin/bookings/$id/cancel';

  static const plans = '/plans';

  static const paymentsCheckout = '/payments/checkout';
  static const paymentsQuotes = '/payments/quotes';
  static String paymentStatus(String id) => '/payments/$id';

  static String clinicScan(String token) => '/clinic/scan/$token';
  static const clinicBookings = '/clinic/bookings';
  static String clinicConfirmBooking(String id) =>
      '/clinic/bookings/$id/confirm';
  static String clinicCancelBooking(String id) => '/clinic/bookings/$id/cancel';

  // PawPoints
  static const pawPointsBalance = '/paw-points/balance';
  static const pawPointsHistory = '/paw-points/history';
  static const pawPointsRewards = '/paw-points/rewards';
  static const adminAwardPoints = '/admin/paw-points/award';

  // Notifications
  static const notifications = '/members/me/notifications';
  static const notificationsUnreadCount = '/members/me/notifications/unread-count';
  static String notificationRead(String id) => '/members/me/notifications/$id/read';
  static const notificationsReadAll = '/members/me/notifications/read-all';

  // Reimbursements
  static const reimbursements = '/members/me/reimbursements';
  static String reimbursementResubmit(String id) =>
      '/members/me/reimbursements/$id/resubmit';
  static const wallet = '/members/me/wallet';
  // Verified direct-pay providers (for the "pay the provider directly" option).
  static const reimbursementProviders = '/members/reimbursement-providers';

  // Legal & member documents — derived from webUrl so they follow the ENV.
  static const tosUrl = '$webUrl/terms-of-service';
  static const privacyUrl = '$webUrl/privacy-policy';
  // Membership Agreement is served by the ToS page (it doubles as the agreement).
  static const agreementUrl = tosUrl;
  static const manualUrl = '$webUrl/docs/member-manual.pdf';
}
