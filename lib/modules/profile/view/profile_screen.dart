import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_box_border.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../../users/model/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedLevel = '';
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _seniors = const [];
  Map<String, dynamic>? _manager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    if (user != null) {
      _populateFromUser(user);
    }
    setState(() => _isLoading = true);

    final profile = await authController.fetchProfile();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (profile != null) {
        final userJson = profile['user'];
        if (userJson is Map<String, dynamic>) {
          _populateFromUser(UserModel.fromJson(userJson));
        }
        _seniors = (profile['seniors'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        final manager = profile['manager'];
        _manager = manager is Map<String, dynamic>
            ? Map<String, dynamic>.from(manager)
            : null;
      }
    });
  }

  void _populateFromUser(UserModel user) {
    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _employeeIdController.text = user.employeeId;
    _selectedLevel = user.level;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _newPasswordController.text;
    if (newPassword.isNotEmpty &&
        newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: AppColors.priorityHigh,
        ),
      );
      return;
    }

    final authController = context.read<AuthController>();
    setState(() => _isSaving = true);

    final updated = await authController.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      employeeId: _employeeIdController.text,
      avatar: null,
      level: _selectedLevel,
      currentPassword: _currentPasswordController.text,
      newPassword: newPassword,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (updated != null) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _populateFromUser(updated);
      await _loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authController.errorMessage ?? 'Failed to update profile',
          ),
          backgroundColor: AppColors.priorityHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    if (_isLoading) {
      return const LoadingWidget(message: 'Loading profile...');
    }

    final isMobile = SizeConfig.isMobile(context);
    final formWidth = isMobile ? double.infinity : 620.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header card: avatar + read-only role/dept ──
                _buildHeaderCard(context, user, isDark),
                SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                if (isMobile)
                  _buildMobileLayout(context, user, isDark, formWidth)
                else
                  _buildDesktopLayout(context, user, isDark, formWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Layout builders
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    UserModel? user,
    bool isDark,
    double formWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditableFormCard(context, isDark, formWidth),
        SizedBox(height: SizeConfig.scaleHeight(context, 16)),
        _buildTeamVisibilityCard(context, isDark, formWidth),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    UserModel? user,
    bool isDark,
    double formWidth,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: _buildEditableFormCard(context, isDark, formWidth),
        ),
        SizedBox(width: SizeConfig.scaleWidth(context, 16)),
        Expanded(
          flex: 4,
          child: _buildTeamVisibilityCard(context, isDark, formWidth),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Header card (avatar + role/department read-only)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeaderCard(BuildContext context, UserModel? user, bool isDark) {
    final avatarText = (user?.avatar.isNotEmpty ?? false)
        ? user!.avatar
        : ((user?.name.isNotEmpty ?? false)
              ? user!.name.characters.first.toUpperCase()
              : 'U');

    return GlassContainer(
      borderRadius: SizeConfig.scaleWidth(context, 16),
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Row(
        children: [
          Container(
            width: SizeConfig.scaleWidth(context, 72),
            height: SizeConfig.scaleWidth(context, 72),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              avatarText,
              style: TextStyle(
                color: Colors.white,
                fontSize: SizeConfig.fontSize(context, 24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: SizeConfig.scaleHeight(context, 6)),
                Wrap(
                  spacing: SizeConfig.scaleWidth(context, 8),
                  runSpacing: SizeConfig.scaleHeight(context, 6),
                  children: [
                    _infoChip(context, Icons.badge_outlined, user?.role ?? ''),
                    _infoChip(
                      context,
                      Icons.business_outlined,
                      user?.department ?? '',
                    ),
                    if ((user?.level.isNotEmpty ?? false))
                      _infoChip(context, Icons.stars_outlined, user!.level),
                  ],
                ),
                SizedBox(height: SizeConfig.scaleHeight(context, 6)),
                Text(
                  'Role & department cannot be changed from here.',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 12),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 10),
        vertical: SizeConfig.scaleHeight(context, 4),
      ),
      decoration: BoxDecoration(
        color: AppColors.brandGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 20)),
        border: Border.all(color: AppColors.brandGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: SizeConfig.iconSize(context, 14),
            color: AppColors.brandGreen,
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 4)),
          Text(
            label,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 12),
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Editable form card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEditableFormCard(
    BuildContext context,
    bool isDark,
    double formWidth,
  ) {
    return GlassContainer(
      borderRadius: SizeConfig.scaleWidth(context, 16),
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Personal Details',
              style: TextStyle(
                fontSize: SizeConfig.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 14)),
            _buildFieldCard(
              context,
              title: 'ACCOUNT',
              child: Column(
                children: [
                  CustomTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = (value ?? '').trim();
                      if (email.isEmpty) return 'Email is required';
                      if (!email.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomTextField(
                    controller: _phoneController,
                    labelText: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomTextField(
                    controller: _employeeIdController,
                    labelText: 'Employee ID',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomDropdown<String>(
                    labelText: 'Level (Senior List)',
                    hintText: 'Select your level',
                    prefixIcon: Icons.stars_outlined,
                    value: _selectedLevel.isEmpty ? null : _selectedLevel,
                    items: AppConstants.artistLevels,
                    itemToString: (level) => level,
                    onChanged: (level) {
                      if (level == null) return;
                      setState(() => _selectedLevel = level);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 14)),
            _buildFieldCard(
              context,
              title: 'CHANGE PASSWORD',
              child: Column(
                children: [
                  CustomTextField(
                    controller: _currentPasswordController,
                    labelText: 'Current Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomTextField(
                    controller: _newPasswordController,
                    labelText: 'New Password',
                    prefixIcon: Icons.lock_reset_outlined,
                    isPassword: true,
                    validator: (value) {
                      if ((value ?? '').isNotEmpty && value!.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm New Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (value) {
                      if ((value ?? '').isNotEmpty &&
                          value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 18)),
            GradientButton(
              text: _isSaving ? 'Saving...' : 'Save Changes',
              icon: Icons.save_outlined,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _handleSave,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 14)),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 14)),
        border: GradientBoxBorder(gradient: AppColors.brandGradient, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 11),
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 10)),
          child,
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Team visibility card (Senior List + Manager — read only)
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTeamVisibilityCard(
    BuildContext context,
    bool isDark,
    double formWidth,
  ) {
    return GlassContainer(
      borderRadius: SizeConfig.scaleWidth(context, 16),
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Team Visibility',
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 14)),
          _buildFieldCard(
            context,
            title: 'YOUR MANAGER',
            child: _manager == null
                ? _emptyMessage(context, 'No manager assigned yet.')
                : _managerTile(context, _manager!),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 14)),
          _buildFieldCard(
            context,
            title: 'SENIOR LIST',
            child: _seniors.isEmpty
                ? _emptyMessage(context, 'No seniors found in your department.')
                : Column(
                    children: [
                      for (var i = 0; i < _seniors.length; i++) ...[
                        _seniorTile(context, _seniors[i]),
                        if (i < _seniors.length - 1)
                          Divider(
                            height: SizeConfig.scaleHeight(context, 16),
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyMessage(BuildContext context, String message) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: SizeConfig.scaleHeight(context, 8),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 13),
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _managerTile(BuildContext context, Map<String, dynamic> manager) {
    return _personTile(
      context,
      name: manager['name'] ?? 'Manager',
      subtitle: manager['role'] ?? '',
      avatar: manager['avatar'] ?? '',
      icon: Icons.supervisor_account_outlined,
    );
  }

  Widget _seniorTile(BuildContext context, Map<String, dynamic> senior) {
    return _personTile(
      context,
      name: senior['name'] ?? '',
      subtitle: [
        if (senior['level'] != null && senior['level'].toString().isNotEmpty)
          senior['level'].toString(),
        if (senior['role'] != null && senior['role'].toString().isNotEmpty)
          senior['role'].toString(),
      ].join(' • '),
      avatar: senior['avatar'] ?? '',
      icon: Icons.stars_outlined,
    );
  }

  Widget _personTile(
    BuildContext context, {
    required String name,
    required String subtitle,
    required String avatar,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarText = avatar.isNotEmpty ? avatar : 'U';
    return Row(
      children: [
        CircleAvatar(
          radius: SizeConfig.scaleWidth(context, 18),
          backgroundColor: AppColors.brandGreen.withValues(alpha: 0.15),
          child: Text(
            avatarText,
            style: TextStyle(
              color: AppColors.brandGreen,
              fontSize: SizeConfig.fontSize(context, 13),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: SizeConfig.scaleWidth(context, 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: SizeConfig.scaleHeight(context, 2)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 12),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          icon,
          size: SizeConfig.iconSize(context, 18),
          color: AppColors.brandGreen,
        ),
      ],
    );
  }
}
