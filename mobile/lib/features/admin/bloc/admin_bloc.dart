import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/member.dart';
import '../../../core/models/service_type.dart';
import '../../../core/services/api_service.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc() : super(AdminInitial()) {
    on<AdminScanRequested>(_onScan);
    on<AdminReset>(_onReset);
    on<AdminDeployServiceRequested>(_onDeploy);
  }

  Future<void> _onScan(
    AdminScanRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      // The member and the service-type catalog are independent — fetch in
      // parallel so the deploy screen has both the moment the scan resolves.
      final results = await Future.wait([
        ApiService.scanQr(event.token),
        ApiService.listServiceTypes(),
      ]);
      emit(AdminScanSuccess(
        member: results[0] as Member,
        serviceTypes: results[1] as List<ServiceType>,
      ));
    } on ApiException catch (e) {
      emit(AdminFailure(e.message));
    } catch (_) {
      emit(AdminFailure('Could not connect. Check your connection and try again.'));
    }
  }

  void _onReset(AdminReset event, Emitter<AdminState> emit) {
    emit(AdminInitial());
  }

  Future<void> _onDeploy(
    AdminDeployServiceRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminDeploying());
    try {
      await ApiService.deployService(
        memberId: event.memberId,
        serviceTypeId: event.serviceTypeId,
        petId: event.petId,
        notes: event.notes,
      );
      emit(AdminDeploySuccess('Service deployed successfully.'));
    } on ApiException catch (e) {
      emit(AdminDeployFailure(e.message));
    } catch (_) {
      emit(AdminDeployFailure('Could not connect. Check your connection and try again.'));
    }
  }
}
