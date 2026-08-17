import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/models/member.dart';
import '../../../core/models/paw_points.dart';
import '../../../core/models/plan.dart';
import '../../../core/models/plan_quote.dart';
import '../../../core/models/reimbursement.dart';
import '../../../core/models/reimbursement_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_storage.dart';
import 'member_event.dart';
import 'member_state.dart';

class MemberBloc extends Bloc<MemberEvent, MemberState> {
  MemberBloc() : super(MemberInitial()) {
    on<MemberLoadRequested>(_onLoad);
    on<ProfilePhotoUpdateRequested>(_onProfilePhotoUpdate);
    on<PetUpdateRequested>(_onPetUpdate);
    on<PetDeleteRequested>(_onPetDelete);
    on<BookingsLoadRequested>(_onBookingsLoad);
    on<BookingRequested>(_onBookingRequest);
    on<BookingCancelRequested>(_onBookingCancel);
    on<PawPointsLoadRequested>(_onPawPointsLoad);
    on<PawPointsBalanceLoadRequested>(_onPawPointsBalanceLoad);
    on<PlansLoadRequested>(_onPlansLoad);
    on<CheckoutRequested>(_onCheckout);
    on<InstallmentRequested>(_onInstallment);
    on<PaymentStatusPolled>(_onPaymentPoll);
    on<ReimbursementsLoadRequested>(_onReimbursementsLoad);
    on<ReimbursementSubmitted>(_onReimbursementSubmit);
    on<ReimbursementResubmitted>(_onReimbursementResubmit);
    on<PayoutDetailsSubmitted>(_onPayoutSubmit);
    on<MobileConfigRequested>(_onMobileConfig);
    on<PromosLoadRequested>(_onPromosLoad);
    on<NotificationsLoadRequested>(_onNotificationsLoad);
    on<NotificationsCountRequested>(_onNotificationsCount);
    on<NotificationReadRequested>(_onNotificationRead);
    on<NotificationsReadAllRequested>(_onNotificationsReadAll);
  }

  // Last-known flag from _onMobileConfig — lets reimbursement loads decide
  // whether to also fetch the provider picker list, without a second event.
  // Also readable by screens pushed after the shell's initial fetch (the
  // MobileConfigLoaded state itself may already have been superseded by the
  // time they mount, since MemberBloc only ever holds its single latest state).
  bool _directProviderPaymentEnabled = false;
  bool get directProviderPaymentEnabled => _directProviderPaymentEnabled;

  Future<Member> _enrichMember(Member member) async {
    final storedId = await AuthStorage.getMemberId();
    return member.withMemberId(storedId);
  }

  Future<void> _onLoad(
    MemberLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(MemberLoading());
    try {
      final member = await _enrichMember(await ApiService.getMyProfile());
      emit(MemberLoaded(member));
    } on ApiException catch (e) {
      emit(MemberFailure(e.message));
    } catch (_) {
      emit(MemberFailure('Could not load your profile. Please try again.'));
    }
  }

  Future<void> _onProfilePhotoUpdate(
    ProfilePhotoUpdateRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(ProfilePhotoSaving());
    try {
      final member = await _enrichMember(
        await ApiService.uploadMyPhoto(
          Uint8List.fromList(event.photoBytes),
          event.photoExt,
        ),
      );
      emit(ProfilePhotoSaveSuccess(member));
    } on ApiException catch (e) {
      emit(ProfilePhotoSaveFailure(e.message));
    } catch (_) {
      emit(ProfilePhotoSaveFailure('Could not update your photo. Please try again.'));
    }
  }

  Future<void> _onPetUpdate(
    PetUpdateRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(PetOperationLoading());
    try {
      await ApiService.updatePet(
        event.petId,
        name: event.name,
        species: event.species,
        breed: event.breed,
        birthMonth: event.birthMonth,
        birthYear: event.birthYear,
        birthDay: event.birthDay,
        weightKg: event.weightKg,
        sex: event.sex,
        notes: event.notes,
        photoBytes: event.photoBytes != null
            ? Uint8List.fromList(event.photoBytes!)
            : null,
        photoExt: event.photoExt,
      );
      final member = await _enrichMember(await ApiService.getMyProfile());
      emit(PetOperationSuccess('${event.name} updated!', member));
    } on ApiException catch (e) {
      emit(PetOperationFailure(e.message));
    } catch (_) {
      emit(PetOperationFailure('Could not update pet. Please try again.'));
    }
  }

  Future<void> _onPetDelete(
    PetDeleteRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(PetOperationLoading());
    try {
      await ApiService.deletePet(event.petId);
      final member = await _enrichMember(await ApiService.getMyProfile());
      emit(PetOperationSuccess('Pet removed.', member));
    } on ApiException catch (e) {
      emit(PetOperationFailure(e.message));
    } catch (_) {
      emit(PetOperationFailure('Could not remove pet. Please try again.'));
    }
  }

  Future<void> _onBookingsLoad(
    BookingsLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final bookings = await ApiService.getMyBookings();
      emit(BookingsLoaded(bookings));
    } on ApiException catch (e) {
      emit(BookingSubmitFailure(e.message));
    } catch (_) {
      emit(BookingSubmitFailure('Could not load bookings.'));
    }
  }

  Future<void> _onBookingRequest(
    BookingRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(BookingSubmitting());
    try {
      final booking = await ApiService.createBooking(
        serviceTypeId: event.serviceTypeId,
        clinicId: event.clinicId,
        bookingDate: event.bookingDate,
        timeSlot: event.timeSlot,
        notes: event.notes,
      );
      emit(BookingSubmitSuccess(booking));
    } on ApiException catch (e) {
      emit(BookingSubmitFailure(e.message));
    } catch (_) {
      emit(BookingSubmitFailure('Could not submit booking. Please try again.'));
    }
  }

  Future<void> _onBookingCancel(
    BookingCancelRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      await ApiService.cancelBooking(event.bookingId);
      emit(BookingCancelSuccess());
    } on ApiException catch (e) {
      emit(BookingCancelFailure(e.message));
    } catch (_) {
      emit(BookingCancelFailure('Could not cancel booking. Please try again.'));
    }
  }

  Future<void> _onPawPointsLoad(
    PawPointsLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      // Three independent endpoints — fetch in parallel; sequential awaits
      // tripled the screen's load time on slow connections.
      final results = await Future.wait([
        ApiService.getPawPointsBalance(),
        ApiService.getPawPointsHistory(),
        ApiService.getPawPointsRewards(),
      ]);
      emit(PawPointsLoaded(
        balance: results[0] as PawPointsBalance,
        history: results[1] as List<PawPointsTransaction>,
        rewards: results[2] as List<PawReward>,
      ));
    } on ApiException catch (e) {
      emit(PawPointsFailure(e.message));
    } catch (_) {
      emit(PawPointsFailure('Could not load PawPoints.'));
    }
  }

  Future<void> _onPawPointsBalanceLoad(
    PawPointsBalanceLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final balance = await ApiService.getPawPointsBalance();
      emit(PawPointsLoaded(balance: balance, history: [], rewards: []));
    } on ApiException catch (e) {
      emit(PawPointsFailure(e.message));
    } catch (_) {
      emit(PawPointsFailure('Could not load PawPoints.'));
    }
  }

  Future<void> _onPlansLoad(
    PlansLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final results = await Future.wait([
        ApiService.fetchPlans(),
        ApiService.fetchPaymentsEnabled(),
        // Pack Discount quotes are an enhancement — if the fetch fails, plans
        // still render at full price and the backend applies any discount at
        // checkout anyway, so the member is never overcharged.
        ApiService.fetchPlanQuotes(petId: event.petId)
            .then<List<PlanQuote>>((q) => q)
            .catchError((_) => <PlanQuote>[]),
      ]);
      final quotes = {
        for (final q in results[2] as List<PlanQuote>) q.planId: q,
      };
      emit(PlansLoaded(
        plans: results[0] as List<Plan>,
        paymentsEnabled: results[1] as bool,
        quotes: quotes,
      ));
    } catch (_) {
      emit(MemberFailure('Could not load plans.'));
    }
  }

  Future<void> _onCheckout(
    CheckoutRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(CheckoutLoading());
    try {
      final response = await ApiService.createCheckout(
        event.planId,
        event.petId,
        cadence: event.cadence,
      );
      emit(CheckoutReady(checkoutUrl: response.checkoutUrl, paymentId: response.paymentId));
    } on ApiException catch (e) {
      emit(CheckoutFailed(e.message));
    } catch (_) {
      emit(CheckoutFailed('Could not start checkout. Please try again.'));
    }
  }

  Future<void> _onInstallment(
    InstallmentRequested event,
    Emitter<MemberState> emit,
  ) async {
    // Reuses the checkout states on purpose: from the screen's point of view an
    // instalment is the same launch-and-poll dance, so nothing downstream needs
    // to learn a second flow.
    emit(CheckoutLoading());
    try {
      final response = await ApiService.payInstallment(event.petId);
      emit(CheckoutReady(checkoutUrl: response.checkoutUrl, paymentId: response.paymentId));
    } on ApiException catch (e) {
      emit(CheckoutFailed(e.message));
    } catch (_) {
      emit(CheckoutFailed('Could not start this payment. Please try again.'));
    }
  }

  Future<void> _onPaymentPoll(
    PaymentStatusPolled event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final payment = await ApiService.getPayment(event.paymentId);
      if (payment.isPaid) {
        emit(PaymentVerified());
      } else if (payment.isFailed) {
        emit(PaymentDeclined());
      }
    } catch (_) {
      // Swallow poll errors — polling continues via Timer
    }
  }

  Future<void> _onReimbursementsLoad(
    ReimbursementsLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(ReimbursementLoading());
    try {
      final results = await Future.wait([
        ApiService.getWallet(),
        ApiService.getMyReimbursements(),
        if (_directProviderPaymentEnabled) ApiService.getReimbursementProviders(),
      ]);
      emit(ReimbursementLoaded(
        wallet: results[0] as Wallet,
        claims: results[1] as List<Reimbursement>,
        providers: results.length > 2
            ? results[2] as List<ReimbursementProvider>
            : const [],
      ));
    } on ApiException catch (e) {
      emit(ReimbursementFailure(e.message));
    } catch (_) {
      emit(ReimbursementFailure('Could not load your reimbursements.'));
    }
  }

  Future<void> _reloadReimbursements(Emitter<MemberState> emit) async {
    try {
      final results = await Future.wait([
        ApiService.getWallet(),
        ApiService.getMyReimbursements(),
        if (_directProviderPaymentEnabled) ApiService.getReimbursementProviders(),
      ]);
      emit(ReimbursementLoaded(
        wallet: results[0] as Wallet,
        claims: results[1] as List<Reimbursement>,
        providers: results.length > 2
            ? results[2] as List<ReimbursementProvider>
            : const [],
      ));
    } catch (_) {
      // Leave the success state in place; the user can pull to refresh.
    }
  }

  Future<void> _onReimbursementSubmit(
    ReimbursementSubmitted event,
    Emitter<MemberState> emit,
  ) async {
    emit(ReimbursementSubmitting());
    try {
      await ApiService.submitReimbursement(
        petId: event.petId,
        serviceTypeId: event.serviceTypeId,
        providerName: event.providerName,
        serviceDate: event.serviceDate,
        claimedAmountCentavos: event.claimedAmountCentavos,
        receiptReference: event.receiptReference,
        memberNotes: event.memberNotes,
        receiptBytes: Uint8List.fromList(event.receiptBytes),
        receiptExt: event.receiptExt,
        payoutTarget: event.payoutTarget,
        providerId: event.providerId,
      );
      emit(ReimbursementSubmitSuccess('Claim submitted for review.'));
      await _reloadReimbursements(emit);
    } on ApiException catch (e) {
      emit(ReimbursementSubmitFailure(e.message));
    } catch (_) {
      emit(ReimbursementSubmitFailure('Could not submit your claim. Please try again.'));
    }
  }

  Future<void> _onReimbursementResubmit(
    ReimbursementResubmitted event,
    Emitter<MemberState> emit,
  ) async {
    emit(ReimbursementSubmitting());
    try {
      await ApiService.resubmitReimbursement(
        event.id,
        providerName: event.providerName,
        serviceDate: event.serviceDate,
        claimedAmountCentavos: event.claimedAmountCentavos,
        memberNotes: event.memberNotes,
        receiptBytes: event.receiptBytes != null
            ? Uint8List.fromList(event.receiptBytes!)
            : null,
        receiptExt: event.receiptExt,
      );
      emit(ReimbursementSubmitSuccess('Claim resubmitted for review.'));
      await _reloadReimbursements(emit);
    } on ApiException catch (e) {
      emit(ReimbursementSubmitFailure(e.message));
    } catch (_) {
      emit(ReimbursementSubmitFailure('Could not resubmit. Please try again.'));
    }
  }

  Future<void> _onPayoutSubmit(
    PayoutDetailsSubmitted event,
    Emitter<MemberState> emit,
  ) async {
    emit(PayoutSaving());
    try {
      await ApiService.updateMyProfile({
        'payout_method': event.method,
        'payout_account_name': event.accountName,
        'payout_account_number': event.accountNumber,
        'payout_bank_name': event.bankName,
      });
      final member = await _enrichMember(await ApiService.getMyProfile());
      emit(PayoutSaveSuccess(member));
    } on ApiException catch (e) {
      emit(PayoutSaveFailure(e.message));
    } catch (_) {
      emit(PayoutSaveFailure('Could not save payout details. Please try again.'));
    }
  }

  Future<void> _onMobileConfig(
    MobileConfigRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final config = await ApiService.fetchMobileConfig();
      _directProviderPaymentEnabled = config.directProviderPaymentEnabled;
      emit(MobileConfigLoaded(
        config.bookingEnabled,
        directProviderPaymentEnabled: config.directProviderPaymentEnabled,
      ));
    } catch (_) {
      // Silent — the shell's defaults (booking hidden, direct-pay off) are
      // the safe state.
    }
  }

  Future<void> _onPromosLoad(
    PromosLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    emit(PromosLoading());
    try {
      final promos = await ApiService.getPromos();
      emit(PromosLoaded(promos));
    } on ApiException catch (e) {
      emit(PromosFailure(e.message));
    } catch (_) {
      emit(PromosFailure('Could not load events and promos.'));
    }
  }

  Future<void> _onNotificationsLoad(
    NotificationsLoadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final notifications = await ApiService.getNotifications();
      emit(NotificationsLoaded(notifications));
    } on ApiException catch (e) {
      emit(NotificationsFailure(e.message));
    } catch (_) {
      emit(NotificationsFailure('Could not load notifications.'));
    }
  }

  Future<void> _onNotificationsCount(
    NotificationsCountRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      final unread = await ApiService.getUnreadNotificationCount();
      emit(NotificationsCount(unread));
    } catch (_) {
      // Silent — the badge poll must never surface errors.
    }
  }

  Future<void> _onNotificationRead(
    NotificationReadRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      await ApiService.markNotificationRead(event.id);
      // The two refresh reads are independent — fetch in parallel.
      final results = await Future.wait([
        ApiService.getNotifications(),
        ApiService.getUnreadNotificationCount(),
      ]);
      emit(NotificationsLoaded(results[0] as List<AppNotification>));
      emit(NotificationsCount(results[1] as int));
    } catch (_) {
      // Non-fatal — the item stays unread; user can tap again.
    }
  }

  Future<void> _onNotificationsReadAll(
    NotificationsReadAllRequested event,
    Emitter<MemberState> emit,
  ) async {
    try {
      await ApiService.markAllNotificationsRead();
      final notifications = await ApiService.getNotifications();
      emit(NotificationsLoaded(notifications));
      emit(NotificationsCount(0));
    } catch (_) {
      // Non-fatal.
    }
  }
}
