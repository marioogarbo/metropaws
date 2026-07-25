import '../../../core/models/member.dart';
import '../../../core/models/service_type.dart';

abstract class AdminState {}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminScanSuccess extends AdminState {
  final Member member;
  final List<ServiceType> serviceTypes;

  AdminScanSuccess({required this.member, required this.serviceTypes});
}

class AdminFailure extends AdminState {
  final String message;
  AdminFailure(this.message);
}

class AdminDeploying extends AdminState {}

class AdminDeploySuccess extends AdminState {
  final String message;
  AdminDeploySuccess(this.message);
}

class AdminDeployFailure extends AdminState {
  final String message;
  AdminDeployFailure(this.message);
}
