import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  // encryptedSharedPreferences requires API 23+; Keystore-backed AES works from API 18
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );
  static const _keyToken = 'mp_token';
  static const _keyRole = 'mp_role';
  static const _keyMemberId = 'mp_member_id';
  static const _keyUserId = 'mp_user_id';

  static Future<void> save({
    required String token,
    required String role,
    String? memberId,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyRole, value: role),
      _storage.write(key: _keyUserId, value: userId),
      if (memberId != null) _storage.write(key: _keyMemberId, value: memberId),
    ]);
  }

  static Future<String?> getToken() => _storage.read(key: _keyToken);
  static Future<String?> getRole() => _storage.read(key: _keyRole);
  static Future<String?> getMemberId() => _storage.read(key: _keyMemberId);
  static Future<String?> getUserId() => _storage.read(key: _keyUserId);

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyRole),
      _storage.delete(key: _keyMemberId),
      _storage.delete(key: _keyUserId),
    ]);
  }
}
