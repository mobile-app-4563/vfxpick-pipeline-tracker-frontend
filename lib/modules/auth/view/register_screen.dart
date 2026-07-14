import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
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
      setState(() {
        if (!_roleOptions.contains(newRole)) {
          _roleOptions.add(newRole);
        }
        _selectedRole = newRole;
      });
      return;
    }

    setState(() => _selectedRole = role);
  }

  Future<void> _onDepartmentChanged(String? department) async {
    if (department == null) return;
    if (department == _addDepartmentOption) {
      final newDepartment = await _showAddDepartmentDialog();
      if (!mounted || newDepartment == null) return;
      setState(() {
        if (!_departmentOptions.contains(newDepartment)) {
          _departmentOptions.add(newDepartment);
        }
        _selectedDept = newDepartment;
      });
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
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Icon(
                Icons.check_circle,
                color: AppColors.statusCompleted,
                size: 28,
              ),
              Text('Registration Successful'),
            ],
          ),
          content: const Text(
            'Your account has been created successfully. Welcome to VfxPick! You are being redirected to your dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss Dialog
                context.go('/dashboard');
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

  Widget _buildFieldCard({
    required BuildContext context,
    required String title,
    required Widget child,
    Widget? footer,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.black.withValues(alpha: 0.09),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 10),
          child,
          if (footer != null) ...[const SizedBox(height: 10), footer],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final cardWidth = isDesktop
        ? 1040.0
        : (screenWidth - 32).clamp(300.0, 760.0);
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF040814), Color(0xFF07142A), Color(0xFF0A1F3D)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassContainer(
                width: cardWidth,
                borderRadius: 20,
                padding: EdgeInsets.all(isDesktop ? 40.0 : 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      isDesktop
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => context.go('/login'),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create Studio Account',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Text(
                                      'Join the production tracking matrix',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => context.go('/login'),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Create Studio Account',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Join the production tracking matrix',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                      const SizedBox(height: 30),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final hasTwoColumns = constraints.maxWidth >= 760;
                          final tileWidth = hasTwoColumns
                              ? (constraints.maxWidth - 16) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'IDENTITY',
                                  child: CustomTextField(
                                    controller: _nameController,
                                    labelText: 'FULL NAME',
                                    hintText: 'Sarah Connor',
                                    prefixIcon: Icons.person_outline,
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                        ? 'Enter your full name'
                                        : null,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'EMAIL',
                                  child: CustomTextField(
                                    controller: _emailController,
                                    labelText: 'STUDIO EMAIL',
                                    hintText: 'email@vfxpick.com',
                                    prefixIcon: Icons.email_outlined,
                                    validator: (value) =>
                                        value == null || !value.contains('@')
                                        ? 'Enter a valid email'
                                        : null,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'CONTACT',
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
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'ORGANIZATION',
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
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'DEPARTMENT',
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
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'ROLE',
                                  child: CustomDropdown<String>(
                                    labelText: 'ROLE ACCESS LEVEL',
                                    items: [..._roleOptions, _addRoleOption],
                                    value: _selectedRole,
                                    onChanged: _onRoleChanged,
                                    itemToString: (item) =>
                                        item == _addRoleOption
                                        ? 'Add New Role...'
                                        : item,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'SECURITY',
                                  child: CustomTextField(
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
                                  footer: ClipRRect(
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
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _buildFieldCard(
                                  context: context,
                                  title: 'SECURITY',
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
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Terms Agreement
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (val) =>
                                setState(() => _acceptTerms = val ?? false),
                            activeColor: AppColors.brandGreen,
                          ),
                          const Expanded(
                            child: Text(
                              'I accept the VFXPICK Production Terms of Service & Privacy Policy',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sign Up Button
                      GradientButton(
                        text: 'CREATE ACCOUNT',
                        width: double.infinity,
                        isLoading: authController.isLoading,
                        onPressed: _handleRegister,
                      ),
                      const SizedBox(height: 16),

                      // Toggle Login
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Already have a user account?',
                            style: TextStyle(fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 13,
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
      ),
    );
  }
}
