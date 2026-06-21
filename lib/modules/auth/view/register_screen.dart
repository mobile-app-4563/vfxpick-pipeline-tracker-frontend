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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = AppConstants.roleEmployee;
  String _selectedDept = AppConstants.departments[0];
  late final List<String> _roleOptions;
  bool _acceptTerms = false;
  double _passwordStrength = 0.0;

  @override
  void initState() {
    super.initState();
    _roleOptions = List<String>.from(AppConstants.userRoles);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 850;
    final cardWidth = isDesktop
        ? 950.0
        : (screenWidth - 48).clamp(300.0, 450.0);
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkBg,
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?q=80&w=1000&auto=format&fit=crop',
            ),
            fit: BoxFit.cover,
            opacity: 0.1,
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

                      // Responsive Grid of inputs
                      if (isDesktop) ...[
                        Row(
                          children: [
                            Expanded(
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
                            const SizedBox(width: 20),
                            Expanded(
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
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
                            const SizedBox(width: 20),
                            Expanded(
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomDropdown<String>(
                                labelText: 'DEPARTMENT',
                                items: AppConstants.departments,
                                value: _selectedDept,
                                onChanged: (val) =>
                                    setState(() => _selectedDept = val!),
                                itemToString: (item) => item,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
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
                                  const SizedBox(height: 8),
                                  // Password strength bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _passwordStrength,
                                      backgroundColor: Colors.grey.withOpacity(
                                        0.2,
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
                            const SizedBox(width: 20),
                            Expanded(
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
                        ),
                      ] else ...[
                        // Mobile Layout: Column stack
                        CustomTextField(
                          controller: _nameController,
                          labelText: 'FULL NAME',
                          prefixIcon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _emailController,
                          labelText: 'STUDIO EMAIL',
                          prefixIcon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _phoneController,
                          labelText: 'PHONE NUMBER',
                          prefixIcon: Icons.phone_android_outlined,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _employeeIdController,
                          labelText: 'EMPLOYEE ID',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),
                        CustomDropdown<String>(
                          labelText: 'DEPARTMENT',
                          items: AppConstants.departments,
                          value: _selectedDept,
                          onChanged: (val) =>
                              setState(() => _selectedDept = val!),
                          itemToString: (item) => item,
                        ),
                        const SizedBox(height: 12),
                        CustomDropdown<String>(
                          labelText: 'ROLE ACCESS LEVEL',
                          items: [..._roleOptions, _addRoleOption],
                          value: _selectedRole,
                          onChanged: _onRoleChanged,
                          itemToString: (item) =>
                              item == _addRoleOption ? 'Add New Role...' : item,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _passwordController,
                          labelText: 'PASSWORD',
                          isPassword: true,
                          onChanged: _calculatePasswordStrength,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          labelText: 'CONFIRM PASSWORD',
                          isPassword: true,
                        ),
                      ],
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
