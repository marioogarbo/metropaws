import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/api_service.dart';
import 'clinic_event.dart';
import 'clinic_state.dart';

class ClinicBloc extends Bloc<ClinicEvent, ClinicState> {
  ClinicBloc() : super(ClinicInitial()) {
    on<ClinicScanRequested>(_onScanRequested);
    on<ClinicReset>(_onReset);
    on<ClinicScheduleRequested>(_onScheduleRequested);
    on<ClinicBookingConfirmRequested>(_onBookingConfirmRequested);
    on<ClinicBookingCancelRequested>(_onBookingCancelRequested);
  }

  // Last date filter passed to ClinicScheduleRequested (null == "All").
  // Replayed after a booking action succeeds so the list reflects the
  // server's latest status without the screen having to re-dispatch
  // ClinicScheduleRequested itself.
  String? _lastDate;

  Future<void> _onScanRequested(
    ClinicScanRequested event,
    Emitter<ClinicState> emit,
  ) async {
    emit(ClinicLoading());
    try {
      final result = await ApiService.clinicScanQr(event.token);
      emit(ClinicScanSuccess(result));
    } on ApiException catch (e) {
      emit(ClinicFailure(e.message));
    } catch (_) {
      emit(
        ClinicFailure('Could not connect. Check your connection and try again.'),
      );
    }
  }

  void _onReset(ClinicReset event, Emitter<ClinicState> emit) {
    emit(ClinicInitial());
  }

  Future<void> _onScheduleRequested(
    ClinicScheduleRequested event,
    Emitter<ClinicState> emit,
  ) async {
    _lastDate = event.date;
    emit(ClinicScheduleLoading());
    try {
      final bookings = await ApiService.getClinicBookings(date: event.date);
      emit(ClinicScheduleLoaded(bookings));
    } on ApiException catch (e) {
      emit(ClinicScheduleError(e.message));
    } catch (_) {
      emit(
        ClinicScheduleError(
          'Could not connect. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _onBookingConfirmRequested(
    ClinicBookingConfirmRequested event,
    Emitter<ClinicState> emit,
  ) async {
    emit(ClinicBookingActionInProgress(event.bookingId));
    try {
      await ApiService.confirmClinicBooking(event.bookingId);
      await _refreshSchedule(emit);
    } on ApiException catch (e) {
      emit(ClinicBookingActionError(e.message));
    } catch (_) {
      emit(
        ClinicBookingActionError(
          'Could not connect. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _onBookingCancelRequested(
    ClinicBookingCancelRequested event,
    Emitter<ClinicState> emit,
  ) async {
    emit(ClinicBookingActionInProgress(event.bookingId));
    try {
      await ApiService.cancelClinicBooking(event.bookingId);
      await _refreshSchedule(emit);
    } on ApiException catch (e) {
      emit(ClinicBookingActionError(e.message));
    } catch (_) {
      emit(
        ClinicBookingActionError(
          'Could not connect. Check your connection and try again.',
        ),
      );
    }
  }

  /// Re-fetches the schedule list (using the last date filter the screen
  /// asked for) after a booking action succeeds, so the card's status/
  /// confirm-cancel buttons update from a single source of truth (the
  /// server) rather than patching local state.
  Future<void> _refreshSchedule(Emitter<ClinicState> emit) async {
    try {
      final bookings = await ApiService.getClinicBookings(date: _lastDate);
      emit(ClinicScheduleLoaded(bookings));
    } catch (_) {
      // Leave the action-error state in place; the user can pull to refresh
      // or switch filters to retry the fetch.
    }
  }
}
