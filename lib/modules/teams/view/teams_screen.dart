import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_dropdown.dart';
import 'package:vfxpick_pipeline/shared/widgets/custom_text_field.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/access_provider.dart';
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
  int _selectedIndex = 0;

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
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.brandGreen,
          foregroundColor: Colors.white,
          onPressed: () => _addMember(context, controller),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Member'),
        ),
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
    final memberCount = departments.fold<int>(
      0,
      (sum, d) => sum + d.members.length,
    );
    final selectedIndex = _selectedIndex < departments.length
        ? _selectedIndex
        : 0;

    return Padding(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: GlassContainer(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: ListView(
          // direction: Axis.horizontal,
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: title row + department selector buttons ──
            _teamsHeader(
              context,
              memberCount,
              departments.length,
              departments,
              selectedIndex,
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            // ── Selected department fills the view; scrolls internally ──
            SizedBox(
              child: _membersTab(
                context,
                controller,
                departments[selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamsHeader(
    BuildContext context,
    int memberCount,
    int departmentCount,
    List<DepartmentTeam> departments,
    int selectedIndex,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 9)),
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.groups_outlined,
            color: AppColors.brandGreen,
            size: SizeConfig.iconSize(context, 22),
          ),
        ),
        SizedBox(width: SizeConfig.scaleWidth(context, 10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teams',
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(context, 18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$memberCount members across $departmentCount departments',
                style: TextStyle(
                  fontSize: SizeConfig.fontSize(context, 12),
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: SizeConfig.scaleWidth(context, 12)),
        // ── Department selector buttons (horizontally aligned) ──
        Expanded(
          child: _departmentButtons(context, departments, selectedIndex),
        ),
      ],
    );
  }

  Widget _departmentButtons(
    BuildContext context,
    List<DepartmentTeam> departments,
    int selectedIndex,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < departments.length; i++) ...[
              _departmentButton(
                context,
                departments[i],
                isDark,
                selected: i == selectedIndex,
                onTap: () => setState(() => _selectedIndex = i),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 8)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _departmentButton(
    BuildContext context,
    DepartmentTeam department,
    bool isDark, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.brandGreen
          : isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 14),
            vertical: SizeConfig.scaleHeight(context, 8),
          ),
          child: Text(
            department.department,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : isDark
                  ? Colors.white
                  : AppColors.darkBg,
              fontSize: SizeConfig.fontSize(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _membersTab(
    BuildContext context,
    TeamController controller,
    DepartmentTeam scope,
  ) {
    if (scope.members.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          icon: Icons.groups_outlined,
          title: 'No team members',
          description: 'No artists found for this department.',
        ),
      );
    }

    final groups = _groupMembersByRole(scope.members);

    // Fills the available viewport; scrolling happens inside the table area.
    return RefreshIndicator(
      onRefresh: () => controller.loadTeams(),
      child: Wrap(
        direction: Axis.horizontal,
        // mainAxisSize: MainAxisSize.min,
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _roleSectionHeader(
                      context,
                      group.role,
                      group.members.length,
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 8)),
                    _roleTable(context, controller, group.members),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Role grouping ────────────────────────────

  List<({String role, List<TeamMember> members})> _groupMembersByRole(
    List<TeamMember> members,
  ) {
    const rank = [
      'supervisor',
      'lead',
      'coordinator',
      'artist',
      'manager',
      'admin',
    ];
    final buckets = <String, List<TeamMember>>{};
    for (final member in members) {
      final role = member.role.trim().isEmpty ? 'Other' : member.role.trim();
      buckets.putIfAbsent(role, () => []).add(member);
    }
    final keys = buckets.keys.toList()
      ..sort((a, b) {
        final ra = rank.indexOf(a.toLowerCase());
        final rb = rank.indexOf(b.toLowerCase());
        if (ra == -1 && rb == -1) {
          return a.toLowerCase().compareTo(b.toLowerCase());
        }
        if (ra == -1) return 1;
        if (rb == -1) return -1;
        return ra.compareTo(rb);
      });
    return [for (final key in keys) (role: key, members: buckets[key]!)];
  }

  String _pluralRole(String role) {
    final t = role.trim();
    if (t.isEmpty) return 'Members';
    final display = t[0].toUpperCase() + t.substring(1);
    return display.toLowerCase().endsWith('s') ? display : '${display}s';
  }

  Widget _roleSectionHeader(BuildContext context, String role, int count) {
    final roleColor = _roleColor(role);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 12),
            vertical: SizeConfig.scaleHeight(context, 6),
          ),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(
              SizeConfig.scaleWidth(context, 8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                size: SizeConfig.iconSize(context, 16),
                color: roleColor,
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 6)),
              Text(
                _pluralRole(role),
                style: TextStyle(
                  color: roleColor,
                  fontSize: SizeConfig.fontSize(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: SizeConfig.scaleWidth(context, 6)),
              Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: SizeConfig.fontSize(context, 12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleTable(
    BuildContext context,
    TeamController controller,
    List<TeamMember> members,
  ) {
    // Fixed height: the table scrolls vertically inside this area and
    // horizontally when columns exceed the available width.
    final maxHeight = SizeConfig.scaleHeight(context, 480);
    final contentHeight = (members.length + 1) * 56.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(0),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: contentHeight > maxHeight ? maxHeight : contentHeight,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                AppColors.brandGreen.withValues(alpha: 0.12),
              ),
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              columnSpacing: SizeConfig.scaleWidth(context, 28),
              border: TableBorder(
                borderRadius: BorderRadius.all(Radius.circular(0)),
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              columns: const [
                DataColumn(label: Text('Member')),
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Level')),
                DataColumn(label: Text('Actions')),
              ],
              rows: members
                  .map((member) {
                    final roleColor = _roleColor(member.role);
                    final deleteEnabled = context
                        .watch<AccessProvider>()
                        .deleteEnabled;
                    return DataRow(
                      cells: [
                        DataCell(Text(member.name)),
                        DataCell(Text(member.department)),
                        DataCell(
                          Text(
                            member.level?.isNotEmpty == true
                                ? member.level!
                                : '-',
                          ),
                        ),
                        DataCell(
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
                              if (deleteEnabled) ...[
                                SizedBox(
                                  width: SizeConfig.scaleWidth(context, 6),
                                ),
                                _actionButton(
                                  context,
                                  Icons.person_remove_rounded,
                                  'Remove',
                                  Colors.red.shade400,
                                  () => _removeMember(
                                    context,
                                    controller,
                                    member,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Stunning helpers
  // ──────────────────────────────────────────────

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

  // Retained for compatibility with existing private screen helpers.
  // ignore: unused_element
  Widget _buildMemberCard(
    BuildContext context,
    TeamController controller,
    TeamMember member,
  ) {
    final roleColor = _roleColor(member.role);
    final deleteEnabled = context.watch<AccessProvider>().deleteEnabled;
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
                  if (deleteEnabled) ...[
                    SizedBox(width: SizeConfig.scaleWidth(context, 6)),
                    _actionButton(
                      context,
                      Icons.person_remove_rounded,
                      'Remove',
                      Colors.red.shade400,
                      () => _removeMember(context, controller, member),
                    ),
                  ],
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
    if (!context.read<AccessProvider>().deleteEnabled) return;
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
