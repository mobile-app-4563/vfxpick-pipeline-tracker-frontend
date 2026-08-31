import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_controller.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../controller/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  static const String _addRoleOption = '__add_new_role__';
  static const String _addDepartmentOption = '__add_new_department__';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = AppConstants.roleEmployee;
  String _selectedDept = AppConstants.departments[0];
  final List<String> _roleOptions = List<String>.from(AppConstants.userRoles);
  final List<String> _departmentOptions = List<String>.from(
    AppConstants.departments,
  );
  bool _acceptTerms = false;
  double _passwordStrength = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDynamicOptions());
  }

  Future<void> _loadDynamicOptions() async {
    final authController = context.read<AuthController>();
    final options = await authController.fetchRegistrationOptions();
    if (!mounted) return;

    final roles = options['roles'] ?? const <String>[];
    final departments = options['departments'] ?? const <String>[];

    setState(() {
      if (roles.isNotEmpty) {
        _roleOptions
          ..clear()
          ..addAll(roles);
      }
      if (departments.isNotEmpty) {
        _departmentOptions
          ..clear()
          ..addAll(departments);
      }

      if (!_roleOptions.contains(_selectedRole) && _roleOptions.isNotEmpty) {
        _selectedRole = _roleOptions.first;
      }
      if (!_departmentOptions.contains(_selectedDept) &&
          _departmentOptions.isNotEmpty) {
        _selectedDept = _departmentOptions.first;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _calculatePasswordStrength(String password) {
    double strength = 0.0;
    if (password.length >= 6) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;

    setState(() {
      _passwordStrength = strength;
    });
  }

  Future<void> _onRoleChanged(String? role) async {
    if (role == null) return;
    if (role == _addRoleOption) {
      final newRole = await _showAddRoleDialog();
      if (!mounted || newRole == null) return;

      // Sync the new role to the backend so it appears in the registration
      // options and the Access Provider matrix.  Requires a broad-access
      // session; when not logged in (fresh registration) the role is still
      // selected locally and gets persisted by the backend on register.
      var synced = false;
      try {
        await ApiController.instance.post(ApiConstants.authAddRole, {
          'role': newRole,
        });
        synced = true;
        // Cache was busted server-side — refresh global options so all
        // screens (dropdowns, access matrix) see the new role immediately.
        final options = await ApiController.instance.get(
          ApiConstants.authOptions,
        );
        AppConstants.applyDynamicOptions(options);
      } catch (_) {
        // 401/403 when not signed in — still allow local selection.
        synced = false;
      }
      if (!mounted) return;

      setState(() {
        if (!_roleOptions.contains(newRole)) {
          _roleOptions.add(newRole);
        }
        _selectedRole = newRole;
      });

      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Role added locally. It will sync to the server after registration.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _selectedRole = role);
  }

  Future<void> _onDepartmentChanged(String? department) async {
    if (department == null) return;
    if (department == _addDepartmentOption) {
      final newDepartment = await _showAddDepartmentDialog();
      if (!mounted || newDepartment == null) return;

      // Sync the new department to the backend so it appears in every
      // import section (shots + production grid) and registration options.
      // Requires a broad-access session; when not logged in (fresh
      // registration) the department is still selected locally and gets
      // persisted by the backend on register.
      var synced = false;
      try {
        await ApiController.instance.post(ApiConstants.authAddDepartment, {
          'department': newDepartment,
        });
        synced = true;
        // Cache was busted server-side — refresh global options so all
        // screens (imports, dialogs) see the new department immediately.
        final options = await ApiController.instance.get(
          ApiConstants.authOptions,
        );
        AppConstants.applyDynamicOptions(options);
      } catch (_) {
        // 401/403 when not signed in — still allow local selection.
        synced = false;
      }
      if (!mounted) return;

      setState(() {
        if (!_departmentOptions.contains(newDepartment)) {
          _departmentOptions.add(newDepartment);
        }
        _selectedDept = newDepartment;
      });

      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Department added locally. It will sync to the server after registration.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _selectedDept = department);
  }

  Future<String?> _showAddRoleDialog() async {
    var draftRole = '';
    final newRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Role'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Role Name',
              hintText: 'e.g. Coordinator',
            ),
            onChanged: (value) => draftRole = value,
            onSubmitted: (value) {
              final role = value.trim();
              if (role.isNotEmpty) {
                Navigator.of(dialogContext).pop(role);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final role = draftRole.trim();
                if (role.isEmpty) return;
                Navigator.of(dialogContext).pop(role);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (newRole == null) return null;
    final normalized = newRole.trim();
    if (normalized.isEmpty) return null;

    final duplicate = _roleOptions.any(
      (role) => role.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      return _roleOptions.firstWhere(
        (role) => role.toLowerCase() == normalized.toLowerCase(),
      );
    }
    return normalized;
  }

  Future<String?> _showAddDepartmentDialog() async {
    var draftDepartment = '';
    final newDepartment = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add New Department'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Department Name',
              hintText: 'e.g. FX',
            ),
            onChanged: (value) => draftDepartment = value,
            onSubmitted: (value) {
              final department = value.trim();
              if (department.isNotEmpty) {
                Navigator.of(dialogContext).pop(department);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final department = draftDepartment.trim();
                if (department.isEmpty) return;
                Navigator.of(dialogContext).pop(department);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (newDepartment == null) return null;
    final normalized = newDepartment.trim();
    if (normalized.isEmpty) return null;

    final duplicate = _departmentOptions.any(
      (department) => department.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicate) {
      return _departmentOptions.firstWhere(
        (department) => department.toLowerCase() == normalized.toLowerCase(),
      );
    }
    return normalized;
  }

  void _handleRegister() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms of Service & Privacy Policy'),
          backgroundColor: AppColors.priorityHigh,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
        return;
      }

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final success = await authController.register(
        fullName: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        employeeId: _employeeIdController.text,
        department: _selectedDept,
        role: _selectedRole,
        password: _passwordController.text,
      );

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authController.errorMessage ?? 'Registration failed'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 16),
            ),
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SizeConfig.scaleWidth(context, 10),
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.statusCompleted,
                size: SizeConfig.iconSize(context, 28),
              ),
              Text('Registration Successful'),
            ],
          ),
          content: const Text(
            'Your account has been created successfully. Welcome to VfxPick! You are being redirected to the home screen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss Dialog
                context.go('/home');
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.brandGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final horizontalPadding = SizeConfig.scaleWidth(
      context,
      screenWidth >= 900 ? 40 : 16,
    );

    final spacing = SizeConfig.scaleWidth(context, 12);

    // Centered glass card that contains the form.
    final containerWidth = screenWidth >= 900
        ? 580.0
        : (screenWidth - 32).clamp(300.0, 760.0);
    final containerPadding = SizeConfig.scaleWidth(
      context,
      screenWidth >= 900 ? 36 : 20,
    );

    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: SizeConfig.scaleHeight(context, 24),
            ),
            child: GlassContainer(
              width: containerWidth,
              borderRadius: 20,
              padding: EdgeInsets.all(containerPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form fields - responsive: 2 columns when the card has
                    // room, 1 column on narrow screens ("gradual" alignment).
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 420 ? 2 : 1;
                        final fieldWidth =
                            (constraints.maxWidth - (spacing * (columns - 1))) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: SizeConfig.scaleHeight(context, 14),
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: CustomTextField(
                                controller: _nameController,
                                labelText: 'FULL NAME',
                                hintText: 'John',
                                prefixIcon: Icons.person_outline,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter your full name'
                                    : null,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomTextField(
                                controller: _emailController,
                                labelText: 'STUDIO EMAIL',
                                hintText: 'john.doe@example.com',
                                prefixIcon: Icons.email_outlined,
                                validator: (value) =>
                                    value == null || !value.contains('@')
                                    ? 'Enter a valid email'
                                    : null,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomTextField(
                                controller: _phoneController,
                                labelText: 'PHONE NUMBER',
                                hintText: '+1 555-0199',
                                prefixIcon: Icons.phone_android_outlined,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter phone number'
                                    : null,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomTextField(
                                controller: _employeeIdController,
                                labelText: 'EMPLOYEE ID',
                                hintText: 'EMP-980',
                                prefixIcon: Icons.badge_outlined,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter Employee ID'
                                    : null,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomDropdown<String>(
                                labelText: 'DEPARTMENT',
                                items: [
                                  ..._departmentOptions,
                                  _addDepartmentOption,
                                ],
                                value: _selectedDept,
                                onChanged: _onDepartmentChanged,
                                itemToString: (item) =>
                                    item == _addDepartmentOption
                                    ? 'Add New Department...'
                                    : item,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomDropdown<String>(
                                labelText: 'ROLE ACCESS LEVEL',
                                items: [..._roleOptions, _addRoleOption],
                                value: _selectedRole,
                                onChanged: _onRoleChanged,
                                itemToString: (item) => item == _addRoleOption
                                    ? 'Add New Role...'
                                    : item,
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTextField(
                                    controller: _passwordController,
                                    labelText: 'PASSWORD',
                                    hintText: 'Minimum 6 characters',
                                    prefixIcon: Icons.lock_outline,
                                    isPassword: true,
                                    onChanged: _calculatePasswordStrength,
                                    validator: (value) =>
                                        value == null || value.length < 6
                                        ? 'Password must be >= 6 chars'
                                        : null,
                                  ),

                                  SizedBox(
                                    height: SizeConfig.scaleHeight(context, 8),
                                  ),

                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _passwordStrength,
                                      backgroundColor: Colors.grey.withValues(
                                        alpha: 0.2,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _passwordStrength <= 0.25
                                            ? Colors.red
                                            : _passwordStrength <= 0.50
                                            ? Colors.orange
                                            : _passwordStrength <= 0.75
                                            ? Colors.amber
                                            : Colors.green,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              width: fieldWidth,
                              child: CustomTextField(
                                controller: _confirmPasswordController,
                                labelText: 'CONFIRM PASSWORD',
                                hintText: 'Re-enter password',
                                prefixIcon: Icons.lock_clock_outlined,
                                isPassword: true,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Re-enter password'
                                    : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: SizeConfig.scaleHeight(context, 18)),

                    // Terms
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value ?? false;
                            });
                          },
                          activeColor: AppColors.brandGreen,
                        ),
                        Expanded(
                          child: Text(
                            'I accept the VFXPICK Production Terms of Service & Privacy Policy',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 13),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: SizeConfig.scaleHeight(context, 14)),

                    // Create account
                    GradientButton(
                      text: 'CREATE ACCOUNT',
                      width: double.infinity,
                      isLoading: authController.isLoading,
                      onPressed: _handleRegister,
                    ),

                    SizedBox(height: SizeConfig.scaleHeight(context, 12)),

                    // Sign in
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have a user account?',
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 13),
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
