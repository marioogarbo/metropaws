import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_storage.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final token = await AuthStorage.getToken();
      final role = await AuthStorage.getRole();
      if (token != null && role != null) {
        final memberId = await AuthStorage.getMemberId();
        // Validate the token is still accepted by the server.
        // On 401/404 the user/token no longer exists — clear and redirect to login.
        // Network errors are ignored so offline users aren't logged out.
        if (role == 'member') {
          try {
            await ApiService.getMyProfile();
          } on ApiException catch (e) {
            if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
              await AuthStorage.clear();
              emit(AuthUnauthenticated());
              return;
            }
          }
        }
        emit(AuthAuthenticated(role: role, memberId: memberId));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final res = await ApiService.login(event.email, event.password);
      await AuthStorage.save(
        token: res.accessToken,
        role: res.role,
        memberId: res.memberId,
        userId: res.userId,
      );
      emit(AuthAuthenticated(role: res.role, memberId: res.memberId));
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (_) {
      emit(
        AuthFailure('Could not connect. Check your connection and try again.'),
      );
    }
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final res = await ApiService.register(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
        agreementAccepted: event.agreementAccepted,
        agreementVersion: event.agreementVersion,
      );
      await AuthStorage.save(
        token: res.accessToken,
        role: res.role,
        memberId: res.memberId,
        userId: res.userId,
      );
      emit(AuthRegistrationComplete());
    } on ApiException catch (e) {
      emit(AuthFailure(e.message));
    } catch (_) {
      emit(
        AuthFailure('Could not connect. Check your connection and try again.'),
      );
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await AuthStorage.clear();
    emit(AuthUnauthenticated());
  }
}
