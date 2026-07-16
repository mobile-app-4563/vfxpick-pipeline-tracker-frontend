import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_controller.dart';
import '../../users/model/user_model.dart';

class AuthController extends ChangeNotifier {
  final ApiController _api = ApiController.instance;
  static const String _tokenStorageKey = 'auth_token';
  static const String _userStorageKey = 'auth_user';

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _rememberMe = false;
  String? _errorMessage;

  AuthController() {
    _bootstrapSession();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;

  bool get hasToken => (_api.getToken()?.isNotEmpty ?? false);
  bool get hasExpiredToken => _isTokenExpired(_api.getToken());
  bool get isAuthenticated => _currentUser != null && !hasExpiredToken;

  Future<void> _bootstrapSession() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenStorageKey);
    final storedUserJson = prefs.getString(_userStorageKey);

    if (storedToken == null || storedToken.isEmpty) {
      _isInitializing = false;
      notifyListeners();
      return;
    }

    _api.setToken(storedToken);

    if (storedUserJson != null && storedUserJson.isNotEmpty) {
      try {
        _currentUser = UserModel.fromJson(
          jsonDecode(storedUserJson) as Map<String, dynamic>,
        );
      } catch (_) {
        _currentUser = null;
      }
    }

    final isValid = await validateSessionToken();
    if (!isValid) {
      await _clearPersistedSession(prefs: prefs);
      _api.clearToken();
      _currentUser = null;
      _errorMessage = 'Session expired. Please login again.';
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _persistSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
    await prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearPersistedSession({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(_tokenStorageKey);
    await sp.remove(_userStorageKey);
  }

  bool _isTokenExpired(String? token) {
    if (token == null || token.isEmpty) return true;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)))
              as Map<String, dynamic>;

      final exp = payload['exp'];
      if (exp == null) return true;
      final expiration = DateTime.fromMillisecondsSinceEpoch(
        (exp as num).toInt() * 1000,
      );
      return DateTime.now().isAfter(expiration);
    } catch (_) {
      return true;
    }
  }

  Future<bool> validateSessionToken() async {
    if (!hasToken || hasExpiredToken) return false;

    try {
      final response = await _api.get(ApiConstants.authMe);
      _currentUser = UserModel.fromJson(
        response['user'] as Map<String, dynamic>,
      );
      await _persistSession(_api.getToken()!, _currentUser!);
      await _refreshDynamicOptions();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) return false;
      return _currentUser != null;
    } catch (_) {
      return _currentUser != null;
    }
  }

  void expireSession() {
    _api.clearToken();
    _currentUser = null;
    _errorMessage = 'Session expired. Please login again.';
    unawaited(_clearPersistedSession());
    notifyListeners();
  }

  Future<void> _refreshDynamicOptions() async {
    try {
      final response = await _api.get(ApiConstants.authOptions);
      AppConstants.applyDynamicOptions(response);
    } catch (_) {
      // Keep existing in-memory defaults if options fetch fails.
    }
  }

  void toggleRememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  // Login Method
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.login, {
        'email': email.trim().toLowerCase(),
        'password': password,
      });

      _api.setToken(response['token'] as String);
      _currentUser = UserModel.fromJson(
        response['user'] as Map<String, dynamic>,
      );
      await _persistSession(response['token'] as String, _currentUser!);
      await _refreshDynamicOptions();
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register / Sign Up Method
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String employeeId,
    required String department,
    required String role,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.register, {
        'fullName': fullName,
        'email': email.trim().toLowerCase(),
        'phone': phone,
        'employeeId': employeeId,
        'department': department,
        'role': role,
        'password': password,
      });

      _api.setToken(response['token'] as String);
      _currentUser = UserModel.fromJson(
        response['user'] as Map<String, dynamic>,
      );
      await _persistSession(response['token'] as String, _currentUser!);
      await _refreshDynamicOptions();
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, List<String>>> fetchRegistrationOptions() async {
    try {
      final response = await _api.get(ApiConstants.authOptions);
      AppConstants.applyDynamicOptions(response);

      return {
        'roles': List<String>.from(AppConstants.userRoles),
        'departments': List<String>.from(AppConstants.departments),
      };
    } catch (_) {
      return {
        'roles': List<String>.from(AppConstants.userRoles),
        'departments': List<String>.from(AppConstants.departments),
      };
    }
  }

  // Logout Method
  Future<void> logout() async {
    try {
      await _api.post(ApiConstants.logout, {});
    } catch (_) {
      // Ignore logout errors — clear session regardless
    } finally {
      _api.clearToken();
      await _clearPersistedSession();
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    }
  }

  // Update Profile data dynamically in session
  void updateSessionUser(UserModel updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }
}
