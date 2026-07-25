import '../../../core/models/member.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/paw_points.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/reimbursement.dart';
import '../../../core/models/reimbursement_provider.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/models/promo.dart';

abstract class MemberState {}

class MemberInitial extends MemberState {}

class MemberLoading extends MemberState {}

class MemberLoaded extends MemberState {
  final Member member;
  MemberLoaded(this.member);
}

class MemberFailure extends MemberState {
  final String message;
  MemberFailure(this.message);
}

class PetOperationLoading extends MemberState {}

class PetOperationSuccess extends MemberState {
  final String message;
  final Member member;
  PetOperationSuccess(this.message, this.member);
}

class PetOperationFailure extends MemberState {
  final String message;
  PetOperationFailure(this.message);
}

class BookingSubmitting extends MemberState {}

class BookingSubmitSuccess extends MemberState {
  final Booking booking;
  BookingSubmitSuccess(this.booking);
}

class BookingSubmitFailure extends MemberState {
  final String message;
  BookingSubmitFailure(this.message);
}

class BookingsLoaded extends MemberState {
  final List<Booking> bookings;
  BookingsLoaded(this.bookings);
}

class BookingCancelSuccess extends MemberState {}

class BookingCancelFailure extends MemberState {
  final String message;
  BookingCancelFailure(this.message);
}

class PawPointsLoaded extends MemberState {
  final PawPointsBalance balance;
  final List<PawPointsTransaction> history;
  final List<PawReward> rewards;
  PawPointsLoaded({
    required this.balance,
    required this.history,
    required this.rewards,
  });
}

class PawPointsFailure extends MemberState {
  final String message;
  PawPointsFailure(this.message);
}

class PlansLoaded extends MemberState {
  final List<Plan> plans;
  final bool paymentsEnabled;
  PlansLoaded({required this.plans, required this.paymentsEnabled});
}

class CheckoutLoading extends MemberState {}

class CheckoutReady extends MemberState {
  final String checkoutUrl;
  final String paymentId;
  CheckoutReady({required this.checkoutUrl, required this.paymentId});
}

class CheckoutFailed extends MemberState {
  final String message;
  CheckoutFailed(this.message);
}

class PaymentVerified extends MemberState {}

class PaymentDeclined extends MemberState {}

class ReimbursementLoading extends MemberState {}

class ReimbursementLoaded extends MemberState {
  final Wallet wallet;
  final List<Reimbursement> claims;
  // Verified direct-pay providers for the Submit form's picker — only
  // populated when direct-provider-payment is enabled (see MobileConfigLoaded).
  final List<ReimbursementProvider> providers;
  ReimbursementLoaded({
    required this.wallet,
    required this.claims,
    this.providers = const [],
  });
}

class ReimbursementFailure extends MemberState {
  final String message;
  ReimbursementFailure(this.message);
}

class ReimbursementSubmitting extends MemberState {}

class ReimbursementSubmitSuccess extends MemberState {
  final String message;
  ReimbursementSubmitSuccess(this.message);
}

class ReimbursementSubmitFailure extends MemberState {
  final String message;
  ReimbursementSubmitFailure(this.message);
}

class NotificationsLoaded extends MemberState {
  final List<AppNotification> notifications;
  NotificationsLoaded(this.notifications);
}

class NotificationsCount extends MemberState {
  final int unread;
  NotificationsCount(this.unread);
}

class NotificationsFailure extends MemberState {
  final String message;
  NotificationsFailure(this.message);
}

class ProfilePhotoSaving extends MemberState {}

class ProfilePhotoSaveSuccess extends MemberState {
  final Member member;
  ProfilePhotoSaveSuccess(this.member);
}

class ProfilePhotoSaveFailure extends MemberState {
  final String message;
  ProfilePhotoSaveFailure(this.message);
}

/// Startup feature flags. Only emitted when the fetch succeeds — on failure
/// the shell keeps its default (booking hidden), which is the safe state.
class MobileConfigLoaded extends MemberState {
  final bool bookingEnabled;
  final bool directProviderPaymentEnabled;
  MobileConfigLoaded(
    this.bookingEnabled, {
    this.directProviderPaymentEnabled = false,
  });
}

class PromosLoading extends MemberState {}

class PromosLoaded extends MemberState {
  final List<Promo> promos;
  PromosLoaded(this.promos);
}

class PromosFailure extends MemberState {
  final String message;
  PromosFailure(this.message);
}

class PayoutSaving extends MemberState {}

class PayoutSaveSuccess extends MemberState {
  final Member member;
  PayoutSaveSuccess(this.member);
}

class PayoutSaveFailure extends MemberState {
  final String message;
  PayoutSaveFailure(this.message);
}
