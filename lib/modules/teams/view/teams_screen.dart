import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_dropdown.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_text_field.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/size_config.dart';
import '../../../core/models/domain_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_box_border.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/teams_controller.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeamController>().loadTeams();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TeamController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        onPressed: () => _addMember(context, controller),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
      body: _body(context, controller),
    );
  }

  Widget _body(BuildContext context, TeamController controller) {
    if (controller.isLoading && controller.teams.isEmpty) {
      return const LoadingWidget(message: 'Loading teams...');
    }
    if (controller.teams.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'No teams',
        description: 'No artists found for your accessible departments.',
      );
    }

    final departments = controller.teams;

    return DefaultTabController(
      length: departments.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Scrollable top area: header card + import preview ──

          // ── Department tab bar ──
          _departmentTabBar(departments),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          // ── Tab content (swipe disabled, switch via tabs only) ──
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: departments
                  .map((d) => _membersTab(context, controller, d))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentTabBar(List<DepartmentTeam> departments) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.fromLTRB(
        SizeConfig.scaleWidth(context, 12),
        SizeConfig.scaleHeight(context, 12),
        SizeConfig.scaleWidth(context, 12),
        0,
      ),
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 4)),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        // borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 12)),
        border: GradientBoxBorder(
          gradient: AppColors.brandGradient,
          width: SizeConfig.scaleWidth(context, 1),
        ),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : AppColors.darkBg,
        unselectedLabelColor: Colors.grey,
        labelStyle: TextStyle(
          fontSize: SizeConfig.fontSize(context, 13),
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(
            SizeConfig.scaleWidth(context, 8),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: departments.map((d) => Tab(text: d.department)).toList(),
      ),
    );
  }

  Widget _membersTab(
    BuildContext context,
    TeamController controller,
    DepartmentTeam scope,
  ) {
    return RefreshIndicator(
      onRefresh: () => controller.loadTeams(),
      child: ListView(
        padding: EdgeInsets.only(
          left: SizeConfig.scaleWidth(context, 12),
          right: SizeConfig.scaleWidth(context, 12),
          top: SizeConfig.scaleHeight(context, 4),
        ),
        children: [
          // Section heading
          _membersTable(controller, scope),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Stunning helpers
  // ──────────────────────────────────────────────

  Widget _membersTable(TeamController controller, DepartmentTeam scope) {
    // Collect all members of the given department into flat rows grouped by role.
    final roleGroups = <String, List<Map<String, dynamic>>>{};
    for (final member in scope.members) {
      final role = member.role;
      roleGroups.putIfAbsent(role, () => []);
      roleGroups[role]!.add({'department': scope.department, 'member': member});
    }

    // Sort: artist first, then alphabetically
    final sortedRoles = roleGroups.keys.toList()
      ..sort((a, b) {
        final aIsArtist = a == AppConstants.roleArtist;
        final bIsArtist = b == AppConstants.roleArtist;
        if (aIsArtist && !bIsArtist) return -1;
        if (!aIsArtist && bIsArtist) return 1;
        return a.compareTo(b);
      });

    if (roleGroups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: EmptyStateWidget(
            icon: Icons.groups_outlined,
            title: 'No team members',
            description: 'No artists found for your accessible departments.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final role in sortedRoles)
          Padding(
            padding: EdgeInsets.only(
              left: SizeConfig.scaleWidth(context, 8),
              right: SizeConfig.scaleWidth(context, 8),
            ),
            child: _buildRoleSection(
              context,
              controller,
              role,
              roleGroups[role]!,
            ),
          ),
      ],
    );
  }

  Widget _buildRoleSection(
    BuildContext context,
    TeamController controller,
    String role,
    List<Map<String, dynamic>> members,
  ) {
    final roleColor = _roleColor(role);

    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.scaleHeight(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role header (no expansion) ──
          Padding(
            padding: EdgeInsets.only(
              left: SizeConfig.scaleWidth(context, 4),
              bottom: SizeConfig.scaleHeight(context, 10),
            ),
            child: Row(
              children: [
                // Gradient icon container
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.scaleWidth(context, 10),
                    vertical: SizeConfig.scaleHeight(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(
                      SizeConfig.scaleWidth(context, 2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: SizeConfig.iconSize(context, 13),
                        color: roleColor,
                      ),
                      SizedBox(width: SizeConfig.scaleWidth(context, 4)),
                      Text(
                        '${members.first['department']} - ${members.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                          fontSize: SizeConfig.fontSize(context, 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Member cards: horizontal flow, wraps when exceeding width ──
          Wrap(
            spacing: SizeConfig.scaleWidth(context, 12),
            runSpacing: SizeConfig.scaleHeight(context, 12),
            children: [
              for (final row in members)
                _buildMemberCard(
                  context,
                  controller,
                  row['member'] as TeamMember,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'artist':
        return const Color(0xFF3B82F6); // blue
      case 'coordinator':
        return const Color(0xFF8B5CF6); // purple
      case 'supervisor':
        return const Color(0xFFF59E0B); // amber
      case 'lead':
        return const Color(0xFF06B6D4); // cyan
      case 'admin':
        return const Color(0xFFEF4444); // red
      case 'manager':
        return const Color(0xFF10B981); // emerald
      default:
        return AppColors.brandGreen;
    }
  }

  Widget _buildMemberCard(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) {
    final roleColor = _roleColor(member.role);
    return GlassContainer.responsive(
      context: context,
      borderRadius: SizeConfig.scaleWidth(context, 12),
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Avatar + Name + Actions (sizes to content) ──
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with gradient ring
              Container(
                width: SizeConfig.scaleWidth(context, 44),
                height: SizeConfig.scaleWidth(context, 44),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [roleColor, roleColor.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: SizeConfig.scaleWidth(context, 38),
                    height: SizeConfig.scaleWidth(context, 38),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0A0F1D),
                    ),
                    child: Center(
                      child: Text(
                        (member.name.isNotEmpty ? member.name[0] : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                          fontSize: SizeConfig.fontSize(context, 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 12)),
              // Name + role badge (capped so long names don't stretch the card)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: SizeConfig.scaleWidth(context, 170),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.fontSize(context, 15),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 10)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: SizeConfig.scaleWidth(context, 6),
                        vertical: SizeConfig.scaleHeight(context, 2),
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          SizeConfig.scaleWidth(context, 4),
                        ),
                      ),
                      child: Text(
                        member.role,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: SizeConfig.fontSize(context, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 12)),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    context,
                    Icons.edit_rounded,
                    'Edit',
                    roleColor,
                    () => _editMember(context, controller, member),
                  ),
                  SizedBox(width: SizeConfig.scaleWidth(context, 6)),
                  _actionButton(
                    context,
                    Icons.person_remove_rounded,
                    'Remove',
                    Colors.red.shade400,
                    () => _removeMember(context, controller, member),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          // ── Info chips: wrap to adapt to content ──
          Wrap(
            spacing: SizeConfig.scaleWidth(context, 8),
            runSpacing: SizeConfig.scaleHeight(context, 8),
            children: [
              _infoChip(
                context,
                Icons.business_rounded,
                member.department,
                roleColor,
              ),
              if (member.level != null && member.level!.isNotEmpty)
                _infoChip(
                  context,
                  Icons.trending_up_rounded,
                  member.level!,
                  roleColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 8),
        vertical: SizeConfig.scaleHeight(context, 4),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: SizeConfig.iconSize(context, 13), color: color),
          SizedBox(width: SizeConfig.scaleWidth(context, 4)),
          Text(
            text,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 12),
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 8),
            ),
          ),
          child: Icon(
            icon,
            size: SizeConfig.iconSize(context, 18),
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _editMember(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMemberDialog(
        member: member,
        controller: controller,
        roleOptions: controller.roleOptions,
        departmentOptions: controller.departmentOptions,
      ),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${member.name} updated')));
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Remove ${member.name} from the team? '
          'Their assigned shots will be unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await controller.removeMember(member.userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? '${member.name} removed' : 'Failed: $err'),
      ),
    );
  }

  Future<void> _addMember(
    BuildContext context,
    TeamController controller,
  ) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _MemberDialog(
        controller: controller,
        roleOptions: controller.roleOptions,
        departmentOptions: controller.departmentOptions,
      ),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team member added')));
    }
  }
}

// ─── Edit Member Dialog ───────────────────────────────────────────────────

class _EditMemberDialog extends StatefulWidget {
  final TeamMember member;
  final TeamController controller;
  final List<String> roleOptions;
  final List<String> departmentOptions;
  const _EditMemberDialog({
    required this.member,
    required this.controller,
    required this.roleOptions,
    required this.departmentOptions,
  });

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final TextEditingController _name;
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  String _role = AppConstants.roleArtist;
  String? _level;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member.name);
    final roleSource = widget.roleOptions.isNotEmpty
        ? widget.roleOptions
        : AppConstants.userRoles;
    _role = roleSource.contains(widget.member.role)
        ? widget.member.role
        : roleSource.first;
    _level = widget.member.level;

    final user = context.read<AuthController>().currentUser;
    final role = user?.role ?? '';
    final userDept = user?.department ?? '';
    final allDepartments = widget.departmentOptions.isNotEmpty
        ? widget.departmentOptions
        : AppConstants.pipelineDepartments;
    if (AppConstants.broadAccessRoles.contains(role)) {
      _accessibleDepartments = allDepartments;
    } else if (allDepartments.contains(userDept)) {
      _accessibleDepartments = [userDept];
    } else {
      _accessibleDepartments = allDepartments;
    }
    _department = _accessibleDepartments.contains(widget.member.department)
        ? widget.member.department
        : _accessibleDepartments.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isArtist => _role == AppConstants.roleArtist;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.editMember(widget.member.userId, {
      'name': name,
      'department': _department,
      'role': _role,
      if (_isArtist && _level != null) 'level': _level,
    });
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text('Edit Team Member')),
      shape: GradientBoxBorder(
        gradient: AppColors.brandGradient,
        width: 2,
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      ),
      titlePadding: EdgeInsets.fromLTRB(
        SizeConfig.scaleWidth(context, 20),
        SizeConfig.scaleHeight(context, 20),
        SizeConfig.scaleWidth(context, 20),
        SizeConfig.scaleHeight(context, 10),
      ),
      content: SizedBox(
        width: SizeConfig.scaleWidth(context, 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: SizeConfig.scaleHeight(context, 12),
            children: [
              CustomTextField(controller: _name, labelText: 'Full name'),
              CustomDropdown(
                labelText: 'Department',
                value: _department,
                items: _accessibleDepartments,
                onChanged: (v) =>
                    setState(() => _department = v ?? _department),
                itemToString: (v) => v,
              ),
              CustomDropdown(
                labelText: 'Role',
                value: _role,
                items: widget.roleOptions.isNotEmpty
                    ? widget.roleOptions
                    : AppConstants.userRoles,
                onChanged: (v) => setState(() => _role = v ?? _role),
                itemToString: (v) => v,
              ),
              if (_isArtist)
                CustomDropdown(
                  labelText: 'Level',
                  value: _level,
                  items: AppConstants.artistLevels,
                  onChanged: (v) => setState(() => _level = v),
                  itemToString: (v) => v,
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Add Member Dialog ────────────────────────────────────────────────────

class _MemberDialog extends StatefulWidget {
  final TeamController controller;
  final List<String> roleOptions;
  final List<String> departmentOptions;
  const _MemberDialog({
    required this.controller,
    required this.roleOptions,
    required this.departmentOptions,
  });

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String _department = AppConstants.pipelineDepartments.first;
  List<String> _accessibleDepartments = AppConstants.pipelineDepartments;
  String _role = AppConstants.roleArtist;
  String? _level = AppConstants.artistLevels.first;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    final role = user?.role ?? '';
    final userDept = user?.department ?? '';
    final allDepartments = widget.departmentOptions.isNotEmpty
        ? widget.departmentOptions
        : AppConstants.pipelineDepartments;
    if (AppConstants.broadAccessRoles.contains(role)) {
      _accessibleDepartments = allDepartments;
    } else if (allDepartments.contains(userDept)) {
      _accessibleDepartments = [userDept];
    } else {
      _accessibleDepartments = allDepartments;
    }
    _department = _accessibleDepartments.first;
    _role = widget.roleOptions.isNotEmpty
        ? widget.roleOptions.first
        : AppConstants.roleArtist;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _isArtist => _role == AppConstants.roleArtist;

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      setState(() => _error = 'Name and email are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.controller.addMember({
      'name': name,
      'email': email,
      'department': _department,
      'role': _role,
      if (_isArtist && _level != null) 'level': _level,
    });
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: const Text('Add Team Member')),
      shape: GradientBoxBorder(
        gradient: AppColors.brandGradient,
        width: 2,
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      ),
      titlePadding: EdgeInsets.fromLTRB(
        SizeConfig.scaleWidth(context, 20),
        SizeConfig.scaleHeight(context, 20),
        SizeConfig.scaleWidth(context, 20),
        SizeConfig.scaleHeight(context, 10),
      ),
      content: SizedBox(
        width: SizeConfig.scaleWidth(context, 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: SizeConfig.scaleHeight(context, 12),
            children: [
              // TextField(
              //   controller: _name,
              //   decoration: const InputDecoration(
              //     labelText: 'Full name',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              // TextField(
              //   controller: _email,
              //   keyboardType: TextInputType.emailAddress,
              //   decoration: const InputDecoration(
              //     labelText: 'Email',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              CustomTextField(controller: _name, labelText: 'Full name'),
              CustomTextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                labelText: 'Email',
              ),
              // DropdownButtonFormField<String>(
              //   initialValue: _department,
              //   decoration: const InputDecoration(
              //     labelText: 'Department',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: AppConstants.pipelineDepartments
              //       .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              //       .toList(),
              //   onChanged: (v) =>
              //       setState(() => _department = v ?? _department),
              // ),
              CustomDropdown(
                labelText: 'Department',
                value: _department,
                items: _accessibleDepartments,
                onChanged: (v) =>
                    setState(() => _department = v ?? _department),
                itemToString: (v) => v,
              ),
              // DropdownButtonFormField<String>(
              //   initialValue: _role,
              //   decoration: const InputDecoration(
              //     labelText: 'Role',
              //     border: OutlineInputBorder(),
              //   ),
              //   items: AppConstants.userRoles
              //       .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              //       .toList(),
              //   onChanged: (v) => setState(() => _role = v ?? _role),
              // ),
              CustomDropdown(
                labelText: 'Role',
                value: _role,
                items: widget.roleOptions.isNotEmpty
                    ? widget.roleOptions
                    : AppConstants.userRoles,
                onChanged: (v) => setState(() => _role = v ?? _role),
                itemToString: (v) => v,
              ),
              if (_isArtist)
                CustomDropdown(
                  labelText: 'Level',
                  items: AppConstants.artistLevels,
                  onChanged: (v) => setState(() => _level = v),
                  itemToString: (v) => v,
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
