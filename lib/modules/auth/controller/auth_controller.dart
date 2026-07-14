import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_controller.dart';
import '../../users/model/user_model.dart';

class AuthController extends ChangeNotifier {
  final ApiController _api = ApiController.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _currentUser != null;

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
