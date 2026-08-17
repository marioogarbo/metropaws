import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/token_response.dart';
import '../models/member.dart';
import '../models/pet.dart';
import '../models/service_type.dart';
import '../models/booking.dart';
import '../models/clinic_partner.dart';
import '../models/plan.dart';
import '../models/plan_quote.dart';
import '../models/payment.dart';
import '../models/clinic_scan_result.dart';
import '../models/clinic_booking.dart';
import '../models/paw_points.dart';
import '../models/reimbursement.dart';
import '../models/reimbursement_provider.dart';
import '../models/app_notification.dart';
import '../models/promo.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Every HTTP request is bounded by this. Without it, a stuck or very slow
/// response — a cold-started backend, a flaky connection, or a hung endpoint —
/// leaves any screen that awaits the call spinning forever. That is exactly
/// what stranded the dashboard's Home and Account tabs (both block on
/// GET /members/me): with no ceiling, `MemberLoadRequested` never resolved to
/// success OR failure, so the loading skeleton showed indefinitely.
const Duration _requestTimeout = Duration(seconds: 60);

/// Wraps an [http.Client] so a request that doesn't respond in time fails with
/// a friendly [ApiException] instead of hanging. Everything — get/post/put/
/// delete and multipart uploads — funnels through [send], so bounding it here
/// covers every call in [ApiService] at once.
class _TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  _TimeoutClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(
      _requestTimeout,
      onTimeout: () => throw const ApiException(
        408,
        'The server took too long to respond. '
        'Please check your connection and try again.',
      ),
    );
  }
}

class ApiService {
  static final http.Client _client = _TimeoutClient(http.Client());

  // Matches the backend's MAX_FILE_BYTES (storage.py) so oversized photos and
  // receipts are rejected the moment they're picked, not after the member has
  // already stepped through the rest of a multi-step form.
  static const maxUploadBytes = 8 * 1024 * 1024;
  static const maxUploadMb = 8;

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await AuthStorage.getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  static T _decode<T>(http.Response res, T Function(dynamic) fromJson) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return fromJson(jsonDecode(res.body));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    final detail = body?['detail']?.toString() ?? 'Request failed';
    throw ApiException(res.statusCode, detail);
  }

  static Future<bool> isEmailAvailable(String email) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.checkEmail}')
        .replace(queryParameters: {'email': email});
    final res = await _client.get(uri, headers: await _headers(auth: false));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['available'] as bool? ?? true;
    }
    return true; // fail open — backend will catch it on register
  }

  static Future<TokenResponse> login(String email, String password) async {
    final res = await _client.post(
      _uri(ApiConstants.login),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(
      res,
      (j) => TokenResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  static Future<TokenResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    bool agreementAccepted = false,
    String? agreementVersion,
  }) async {
    final res = await _client.post(
      _uri(ApiConstants.register),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'role': 'member',
        'agreement_accepted': agreementAccepted,
        if (agreementVersion != null) 'agreement_version': agreementVersion,
      }),
    );
    return _decode(
      res,
      (j) => TokenResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  static Future<void> requestPasswordReset(String email) async {
    final res = await _client.post(
      _uri(ApiConstants.forgotPassword),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final detail = body?['detail']?.toString() ?? 'Request failed';
      throw ApiException(res.statusCode, detail);
    }
  }

  static Future<Member> getMyProfile() async {
    final res = await _client.get(
      _uri(ApiConstants.myProfile),
      headers: await _headers(),
    );
    return _decode(res, (j) => Member.fromJson(j as Map<String, dynamic>));
  }

  static Future<Member> updateMyProfile(Map<String, dynamic> fields) async {
    final res = await _client.put(
      _uri(ApiConstants.myProfile),
      headers: await _headers(),
      body: jsonEncode(fields),
    );
    return _decode(res, (j) => Member.fromJson(j as Map<String, dynamic>));
  }

  static Future<Member> uploadMyPhoto(Uint8List photoBytes, String photoExt) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('POST', _uri(ApiConstants.myProfilePhoto));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: 'photo.$photoExt',
      ),
    );
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Member.fromJson(j as Map<String, dynamic>));
  }

  static Future<Member> selectPlan(String planId) async {
    final res = await _client.post(
      _uri(ApiConstants.selectPlan),
      headers: await _headers(),
      body: jsonEncode({'plan_id': planId}),
    );
    return _decode(res, (j) => Member.fromJson(j as Map<String, dynamic>));
  }

  static Future<Member> scanQr(String token) async {
    final res = await _client.get(
      _uri(ApiConstants.scanQr(token)),
      headers: await _headers(),
    );
    return _decode(res, (j) => Member.fromJson(j as Map<String, dynamic>));
  }

  static Future<void> deployService({
    required String memberId,
    required String serviceTypeId,
    String? petId,
    String? notes,
  }) async {
    final res = await _client.post(
      _uri(ApiConstants.deployService),
      headers: await _headers(),
      body: jsonEncode({
        'member_id': memberId,
        'service_type_id': serviceTypeId,
        'pet_id': petId,
        'notes': notes,
      }),
    );
    _decode(res, (j) => j);
  }

  static Future<List<ServiceType>> listServiceTypes() async {
    final res = await _client.get(
      _uri(ApiConstants.listServiceTypes),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => ServiceType.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Pet> createPet({
    required String name,
    String? species,
    required String breed,
    required int birthMonth,
    required int birthYear,
    int? birthDay,
    required double weightKg,
    String? sex,
    String? notes,
    required Uint8List photoBytes,
    required String photoExt,
    required Uint8List fullBodyBytes,
    required String fullBodyExt,
    required Uint8List ownerBytes,
    required String ownerExt,
    Uint8List? vaxBytes,
    String? vaxExt,
  }) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('POST', _uri(ApiConstants.pets));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    if (species != null && species.isNotEmpty) request.fields['species'] = species;
    request.fields['breed'] = breed;
    request.fields['birth_month'] = birthMonth.toString();
    request.fields['birth_year'] = birthYear.toString();
    if (birthDay != null) request.fields['birth_day'] = birthDay.toString();
    request.fields['weight_kg'] = weightKg.toString();
    if (sex != null && sex.isNotEmpty) request.fields['sex'] = sex;
    if (notes != null && notes.isNotEmpty) request.fields['notes'] = notes;
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: 'photo.$photoExt',
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo_full_body',
        fullBodyBytes,
        filename: 'photo_full_body.$fullBodyExt',
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo_with_owner',
        ownerBytes,
        filename: 'photo_with_owner.$ownerExt',
      ),
    );
    if (vaxBytes != null && vaxExt != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'vax_card',
          vaxBytes,
          filename: 'vax-card.$vaxExt',
        ),
      );
    }
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Pet.fromJson(j as Map<String, dynamic>));
  }

  static Future<List<Pet>> listPets() async {
    final res = await _client.get(
      _uri(ApiConstants.pets),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Pet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Pet> updatePet(
    String petId, {
    String? name,
    String? species,
    String? breed,
    int? birthMonth,
    int? birthYear,
    int? birthDay,
    double? weightKg,
    String? sex,
    String? notes,
    Uint8List? photoBytes,
    String? photoExt,
  }) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('PUT', _uri(ApiConstants.pet(petId)));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (name != null && name.isNotEmpty) request.fields['name'] = name;
    if (species != null && species.isNotEmpty) request.fields['species'] = species;
    if (breed != null) request.fields['breed'] = breed;
    if (birthMonth != null) request.fields['birth_month'] = birthMonth.toString();
    if (birthYear != null) request.fields['birth_year'] = birthYear.toString();
    if (birthDay != null) request.fields['birth_day'] = birthDay.toString();
    if (weightKg != null) request.fields['weight_kg'] = weightKg.toString();
    if (sex != null && sex.isNotEmpty) request.fields['sex'] = sex;
    if (notes != null) request.fields['notes'] = notes;
    if (photoBytes != null && photoExt != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: 'photo.$photoExt',
        ),
      );
    }
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Pet.fromJson(j as Map<String, dynamic>));
  }

  static Future<void> deletePet(String petId) async {
    final res = await _client.delete(
      _uri(ApiConstants.pet(petId)),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final detail = body?['detail']?.toString() ?? 'Failed to delete pet';
      throw ApiException(res.statusCode, detail);
    }
  }

  static Future<Pet> uploadPetPhoto(
    String petId,
    Uint8List bytes,
    String extension,
  ) async {
    return uploadPetPhotoSlot(petId, 'photo', bytes, extension);
  }

  /// Uploads one of a pet's identity-photo slots (front face, full body,
  /// pet+owner, or one of the optional angles added later from the pet's
  /// profile). [field] is the backend form-field name, e.g. 'photo',
  /// 'photo_left_profile', 'photo_with_id_card' — see [Pet.remainingPhotoSlots].
  /// Returns the updated pet so callers can refresh photo URLs and
  /// [Pet.isProfileVerified] without a separate fetch.
  static Future<Pet> uploadPetPhotoSlot(
    String petId,
    String field,
    Uint8List bytes,
    String extension,
  ) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('PUT', _uri(ApiConstants.pet(petId)));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: '$field.$extension',
      ),
    );
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Pet.fromJson(j as Map<String, dynamic>));
  }

  static Future<List<ClinicPartner>> getClinics() async {
    final res = await _client.get(
      _uri(ApiConstants.clinics),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => ClinicPartner.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Booking> createBooking({
    required String serviceTypeId,
    required String clinicId,
    required DateTime bookingDate,
    required String timeSlot,
    String? notes,
  }) async {
    final res = await _client.post(
      _uri(ApiConstants.myBookings),
      headers: await _headers(),
      body: jsonEncode({
        'service_type_id': serviceTypeId,
        'clinic_id': clinicId,
        'booking_date':
            '${bookingDate.year}-${bookingDate.month.toString().padLeft(2, '0')}-${bookingDate.day.toString().padLeft(2, '0')}',
        'time_slot': timeSlot,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    return _decode(res, (j) => Booking.fromJson(j as Map<String, dynamic>));
  }

  static Future<List<Booking>> getMyBookings() async {
    final res = await _client.get(
      _uri(ApiConstants.myBookings),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<List<Booking>> getAdminBookings({String? status}) async {
    final uri = _uri(ApiConstants.adminBookings +
        (status != null ? '?status=$status' : ''));
    final res = await _client.get(uri, headers: await _headers());
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Booking> confirmBooking(String bookingId) async {
    final res = await _client.put(
      _uri(ApiConstants.confirmBooking(bookingId)),
      headers: await _headers(),
    );
    return _decode(res, (j) => Booking.fromJson(j as Map<String, dynamic>));
  }

  static Future<Booking> cancelBooking(String bookingId) async {
    final res = await _client.put(
      _uri(ApiConstants.cancelBooking(bookingId)),
      headers: await _headers(),
    );
    return _decode(res, (j) => Booking.fromJson(j as Map<String, dynamic>));
  }

  static Future<ClinicScanResult> clinicScanQr(String token) async {
    final res = await _client.get(
      _uri(ApiConstants.clinicScan(token)),
      headers: await _headers(),
    );
    return _decode(res, (j) => ClinicScanResult.fromJson(j as Map<String, dynamic>));
  }

  static Future<ClinicBooking> confirmClinicBooking(String bookingId) async {
    final res = await _client.put(
      _uri(ApiConstants.clinicConfirmBooking(bookingId)),
      headers: await _headers(),
    );
    return _decode(res, (j) => ClinicBooking.fromJson(j as Map<String, dynamic>));
  }

  static Future<ClinicBooking> cancelClinicBooking(String bookingId) async {
    final res = await _client.put(
      _uri(ApiConstants.clinicCancelBooking(bookingId)),
      headers: await _headers(),
    );
    return _decode(res, (j) => ClinicBooking.fromJson(j as Map<String, dynamic>));
  }

  static Future<List<ClinicBooking>> getClinicBookings({
    String? date,
    String? status,
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    if (status != null) params['status'] = status;
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.clinicBookings}')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: await _headers());
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => ClinicBooking.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<List<Plan>> fetchPlans() async {
    final res = await _client.get(
      _uri(ApiConstants.plans),
      headers: await _headers(auth: false),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Plan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Member-specific plan prices with the Pack Discount applied server-side.
  /// [petId] = the pet being (re)activated (excluded from the discount's
  /// anchor set); omit for a pet not yet created (Add-a-Pet flow).
  static Future<List<PlanQuote>> fetchPlanQuotes({String? petId}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.paymentsQuotes}')
        .replace(queryParameters: petId == null ? null : {'pet_id': petId});
    final res = await _client.get(uri, headers: await _headers());
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => PlanQuote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Start paying for a plan. `cadence` is 'annual' (the default, and what the
  /// server assumes when the field is absent) or 'monthly', which opens an
  /// instalment subscription and charges the plan's monthly price.
  static Future<CheckoutResponse> createCheckout(
    String planId,
    String petId, {
    String cadence = 'annual',
  }) async {
    final res = await _client.post(
      _uri(ApiConstants.paymentsCheckout),
      headers: await _headers(),
      body: jsonEncode({
        'plan_id': planId,
        'pet_id': petId,
        'cadence': cadence,
      }),
    );
    return _decode(
      res,
      (j) => CheckoutResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Pay the next instalment on a pet's existing monthly membership.
  ///
  /// Member-initiated because nothing bills automatically: there is no
  /// scheduler behind the API, and no saved card to charge while QR Ph is the
  /// only live method. This call is what keeps a monthly membership running.
  static Future<CheckoutResponse> payInstallment(String petId) async {
    final res = await _client.post(
      _uri(ApiConstants.paymentsInstallment),
      headers: await _headers(),
      body: jsonEncode({'pet_id': petId}),
    );
    return _decode(
      res,
      (j) => CheckoutResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  static Future<Pet> activatePetPlan(String petId, String planId) async {
    final res = await _client.post(
      _uri(ApiConstants.activatePetPlan(petId)),
      headers: await _headers(),
      body: jsonEncode({'plan_id': planId}),
    );
    return _decode(res, (j) => Pet.fromJson(j as Map<String, dynamic>));
  }

  static Future<bool> fetchPaymentsEnabled() async {
    final res = await _client.get(
      _uri(ApiConstants.paymentsEnabled),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as Map<String, dynamic>)['payments_enabled'] as bool,
    );
  }

  /// Feature flags read at app-shell startup: whether the Book tab should be
  /// shown (booking is on standby until partner clinics exist) and whether
  /// the reimbursement Submit form may offer "pay the provider directly".
  /// Both live in the backend so either can flip without an app release.
  static Future<
      ({bool bookingEnabled, bool directProviderPaymentEnabled})>
      fetchMobileConfig() async {
    final res = await _client.get(
      _uri(ApiConstants.mobileConfig),
      headers: await _headers(auth: false),
    );
    return _decode(res, (j) {
      final map = j as Map<String, dynamic>;
      return (
        bookingEnabled: map['booking_enabled'] as bool? ?? false,
        directProviderPaymentEnabled:
            map['direct_provider_payment_enabled'] as bool? ?? false,
      );
    });
  }

  static Future<List<Promo>> getPromos() async {
    final res = await _client.get(
      _uri(ApiConstants.promos),
      headers: await _headers(auth: false),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Promo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Whether the Book tab should be shown. Booking is on standby until
  /// partner clinics exist — the flag lives in the backend so it can flip
  /// without an app release.
  static Future<bool> fetchBookingEnabled() async {
    final res = await _client.get(
      _uri(ApiConstants.mobileConfig),
      headers: await _headers(auth: false),
    );
    return _decode(
      res,
      (j) => (j as Map<String, dynamic>)['booking_enabled'] as bool? ?? false,
    );
  }

  static Future<PaymentRecord> getPayment(String paymentId) async {
    final res = await _client.get(
      _uri(ApiConstants.paymentStatus(paymentId)),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => PaymentRecord.fromJson(j as Map<String, dynamic>),
    );
  }

  static Future<PawPointsBalance> getPawPointsBalance() async {
    final res = await _client.get(
      _uri(ApiConstants.pawPointsBalance),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => PawPointsBalance.fromJson(j as Map<String, dynamic>),
    );
  }

  static Future<List<PawPointsTransaction>> getPawPointsHistory() async {
    final res = await _client.get(
      _uri(ApiConstants.pawPointsHistory),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => PawPointsTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<List<PawReward>> getPawPointsRewards() async {
    final res = await _client.get(
      _uri(ApiConstants.pawPointsRewards),
      headers: await _headers(auth: false),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => PawReward.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<void> uploadVaxCard(
    String petId,
    Uint8List bytes,
    String extension,
  ) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('PUT', _uri(ApiConstants.pet(petId)));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'vax_card',
        bytes,
        filename: 'vax-card.$extension',
      ),
    );
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      final detail =
          (jsonDecode(body) as Map<String, dynamic>?)?['detail']?.toString() ??
          'Upload failed';
      throw ApiException(streamed.statusCode, detail);
    }
  }

  // ── Notifications ───────────────────────────────────────────────────────

  static Future<List<AppNotification>> getNotifications() async {
    final res = await _client.get(
      _uri(ApiConstants.notifications),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<int> getUnreadNotificationCount() async {
    final res = await _client.get(
      _uri(ApiConstants.notificationsUnreadCount),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as Map<String, dynamic>)['unread'] as int? ?? 0,
    );
  }

  static Future<void> markNotificationRead(String id) async {
    final res = await _client.put(
      _uri(ApiConstants.notificationRead(id)),
      headers: await _headers(),
    );
    _decode(res, (j) => j);
  }

  static Future<void> markAllNotificationsRead() async {
    final res = await _client.put(
      _uri(ApiConstants.notificationsReadAll),
      headers: await _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final detail = body?['detail']?.toString() ?? 'Request failed';
      throw ApiException(res.statusCode, detail);
    }
  }

  // ── Reimbursements ──────────────────────────────────────────────────────

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Wallet> getWallet() async {
    final res = await _client.get(
      _uri(ApiConstants.wallet),
      headers: await _headers(),
    );
    return _decode(res, (j) => Wallet.fromJson(j as Map<String, dynamic>));
  }

  static Future<List<Reimbursement>> getMyReimbursements() async {
    final res = await _client.get(
      _uri(ApiConstants.reimbursements),
      headers: await _headers(),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => Reimbursement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Verified providers members can pick for the "pay the provider directly"
  /// option. Unauthenticated, like getClinics — active ones only.
  static Future<List<ReimbursementProvider>> getReimbursementProviders() async {
    final res = await _client.get(
      _uri(ApiConstants.reimbursementProviders),
      headers: await _headers(auth: false),
    );
    return _decode(
      res,
      (j) => (j as List<dynamic>)
          .map((e) => ReimbursementProvider.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<Reimbursement> submitReimbursement({
    required String petId,
    required String serviceTypeId,
    required String providerName,
    required DateTime serviceDate,
    required int claimedAmountCentavos,
    String? receiptReference,
    String? memberNotes,
    required Uint8List receiptBytes,
    required String receiptExt,
    String payoutTarget = 'member',
    String? providerId,
  }) async {
    final token = await AuthStorage.getToken();
    final request =
        http.MultipartRequest('POST', _uri(ApiConstants.reimbursements));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['pet_id'] = petId;
    request.fields['service_type_id'] = serviceTypeId;
    request.fields['provider_name'] = providerName;
    request.fields['service_date'] = _ymd(serviceDate);
    request.fields['claimed_amount_centavos'] = claimedAmountCentavos.toString();
    request.fields['payout_target'] = payoutTarget;
    if (providerId != null && providerId.isNotEmpty) {
      request.fields['provider_id'] = providerId;
    }
    if (receiptReference != null && receiptReference.isNotEmpty) {
      request.fields['receipt_reference'] = receiptReference;
    }
    if (memberNotes != null && memberNotes.isNotEmpty) {
      request.fields['member_notes'] = memberNotes;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'receipt',
        receiptBytes,
        filename: 'receipt.$receiptExt',
      ),
    );
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Reimbursement.fromJson(j as Map<String, dynamic>));
  }

  static Future<Reimbursement> resubmitReimbursement(
    String id, {
    String? providerName,
    DateTime? serviceDate,
    int? claimedAmountCentavos,
    String? memberNotes,
    Uint8List? receiptBytes,
    String? receiptExt,
  }) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest(
      'POST',
      _uri(ApiConstants.reimbursementResubmit(id)),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (providerName != null && providerName.isNotEmpty) {
      request.fields['provider_name'] = providerName;
    }
    if (serviceDate != null) request.fields['service_date'] = _ymd(serviceDate);
    if (claimedAmountCentavos != null) {
      request.fields['claimed_amount_centavos'] =
          claimedAmountCentavos.toString();
    }
    if (memberNotes != null && memberNotes.isNotEmpty) {
      request.fields['member_notes'] = memberNotes;
    }
    if (receiptBytes != null && receiptExt != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'receipt',
          receiptBytes,
          filename: 'receipt.$receiptExt',
        ),
      );
    }
    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res, (j) => Reimbursement.fromJson(j as Map<String, dynamic>));
  }
}
