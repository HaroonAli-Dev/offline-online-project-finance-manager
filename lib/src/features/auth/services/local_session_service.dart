import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable model representing locally persisted authenticated session data.
@immutable
class LocalSessionData {
  const LocalSessionData({
    required this.userId,
    required this.email,
    required this.rememberMe,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final bool rememberMe;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'rememberMe': rememberMe,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LocalSessionData.fromJson(Map<String, dynamic> json) =>
      LocalSessionData(
        userId: json['userId'] as String,
        email: json['email'] as String,
        rememberMe: json['rememberMe'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalSessionData &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          email == other.email &&
          rememberMe == other.rememberMe;

  @override
  int get hashCode => Object.hash(userId, email, rememberMe);

  @override
  String toString() =>
      'LocalSessionData(userId: $userId, email: $email, rememberMe: $rememberMe, createdAt: $createdAt)';
}

/// Service managing locally persisted authenticated session state.
///
/// Handles session persistence, Remember Me status, and restoration eligibility
/// across application launches using [SharedPreferences].
class LocalSessionService {
  LocalSessionService({this._prefs});

  SharedPreferences? _prefs;

  static final LocalSessionService instance = LocalSessionService();

  static const String _kUserIdKey = 'app_auth_user_id';
  static const String _kEmailKey = 'app_auth_user_email';
  static const String _kRememberMeKey = 'app_auth_remember_me';
  static const String _kRestorationEligibleKey =
      'app_auth_restoration_eligible';
  static const String _kCreatedAtKey = 'app_auth_session_created_at';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Sets the underlying [SharedPreferences] instance (useful for testing or bootstrap preloading).
  void setPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// Saves the authenticated session information.
  ///
  /// If [rememberMe] is true:
  /// - Sets `rememberMe = true`
  /// - Sets `restorationEligible = true`
  /// This permits subsequent offline or online startup to restore the user session.
  ///
  /// If [rememberMe] is false:
  /// - Sets `rememberMe = false`
  /// - Sets `restorationEligible = false`
  /// On next startup or app closure, the session will NOT be restored and login is required.
  Future<void> saveSession({
    required String userId,
    required String email,
    required bool rememberMe,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(_kUserIdKey, userId);
    await prefs.setString(_kEmailKey, email);
    await prefs.setBool(_kRememberMeKey, rememberMe);
    await prefs.setBool(_kRestorationEligibleKey, rememberMe);
    await prefs.setString(_kCreatedAtKey, DateTime.now().toIso8601String());
  }

  /// Loads the restored session if and only if:
  /// 1. A local user session exists, and
  /// 2. Remember Me was enabled and marked eligible for restoration.
  ///
  /// Returns `null` if no session exists or if Remember Me was disabled.
  Future<LocalSessionData?> loadRestorationSession() async {
    final prefs = await _getPrefs();
    final userId = prefs.getString(_kUserIdKey);
    final email = prefs.getString(_kEmailKey);
    final rememberMe = prefs.getBool(_kRememberMeKey) ?? false;
    final eligible = prefs.getBool(_kRestorationEligibleKey) ?? false;

    if (userId == null || email == null) return null;
    if (!rememberMe || !eligible) return null;

    final createdAtStr = prefs.getString(_kCreatedAtKey);
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    return LocalSessionData(
      userId: userId,
      email: email,
      rememberMe: rememberMe,
      createdAt: createdAt,
    );
  }

  /// Returns the raw stored session information regardless of restoration eligibility.
  /// Useful for startup decision routing when checking if an un-remembered session needs clearing.
  Future<LocalSessionData?> getRawSession() async {
    final prefs = await _getPrefs();
    final userId = prefs.getString(_kUserIdKey);
    final email = prefs.getString(_kEmailKey);

    if (userId == null || email == null) return null;

    final rememberMe = prefs.getBool(_kRememberMeKey) ?? false;
    final createdAtStr = prefs.getString(_kCreatedAtKey);
    final createdAt = createdAtStr != null
        ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
        : DateTime.now();

    return LocalSessionData(
      userId: userId,
      email: email,
      rememberMe: rememberMe,
      createdAt: createdAt,
    );
  }

  /// Returns whether Remember Me is enabled and eligible for restoration.
  Future<bool> isRememberMeEnabled() async {
    final prefs = await _getPrefs();
    final rememberMe = prefs.getBool(_kRememberMeKey) ?? false;
    final eligible = prefs.getBool(_kRestorationEligibleKey) ?? false;
    return rememberMe && eligible;
  }

  /// Clears all local authentication and restoration session data.
  ///
  /// Called on explicit sign out or when cleaning up an unchecked Remember Me session.
  Future<void> clearSession() async {
    final prefs = await _getPrefs();
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kRememberMeKey);
    await prefs.remove(_kRestorationEligibleKey);
    await prefs.remove(_kCreatedAtKey);
  }
}
