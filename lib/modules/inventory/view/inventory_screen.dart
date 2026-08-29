import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/access_provider.dart';
import '../../../core/services/inventory_service.dart';
import '../../../core/utils/size_config.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _service = InventoryService();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedStatusFilter = 'All';

  final List<String> _categories = [
    'Workstation',
    'Monitor',
    'Tablet',
    'Software License',
    'Server/Network',
    'Other',
  ];

  final List<String> _statuses = [
    'Available',
    'Assigned',
    'Maintenance',
    'Retired',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final itemsResp = await _service.getInventoryItems();
      final usersResp = await _service.getAssignableUsers();

      final rawItems = itemsResp['inventory'] as List<dynamic>? ?? const [];
      final rawUsers = usersResp['users'] as List<dynamic>? ?? const [];

      if (mounted) {
        setState(() {
          _items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
          _users = rawUsers.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete(int itemId) async {
    final user = Provider.of<AuthController>(
      context,
      listen: false,
    ).currentUser;
    if (!Provider.of<AccessProvider>(
      context,
      listen: false,
    ).deleteEnabledForDepartment(user?.department)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Are you sure you want to delete this inventory item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteInventoryItem(itemId);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.priorityHigh,
            ),
          );
        }
      }
    }
  }

  Future<void> _addOrEdit([Map<String, dynamic>? item]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _InventoryDialog(
        service: _service,
        item: item,
        users: _users,
        categories: _categories,
        statuses: _statuses,
      ),
    );
    if (result == true) _load();
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      final name = (item['itemName'] ?? '').toString().toLowerCase();
      final serial = (item['serialNumber'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString();
      final status = (item['status'] ?? '').toString();

      final matchesSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          serial.contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategoryFilter == 'All' ||
          category == _selectedCategoryFilter;
      final matchesStatus =
          _selectedStatusFilter == 'All' || status == _selectedStatusFilter;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Available':
        return AppColors.statusApproved;
      case 'Assigned':
        return AppColors.statusAssigned;
      case 'Maintenance':
        return AppColors.statusInProgress;
      case 'Retired':
        return AppColors.priorityHigh;
      default:
        return AppColors.statusPending;
    }
  }

  InputDecoration _filterInputDecoration(
    BuildContext context, {
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
    );

    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        vertical: SizeConfig.scaleHeight(context, 14),
        horizontal: SizeConfig.scaleWidth(context, 14),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
      enabledBorder: baseBorder,
      border: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: AppColors.brandGreen.withValues(alpha: 0.7),
          width: SizeConfig.scaleWidth(context, 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final user = authController.currentUser;
    final canEdit =
        user != null &&
        (user.role == 'Admin' ||
            user.role == 'Production' ||
            user.role == 'Management');
    final canDelete = Provider.of<AccessProvider>(
      context,
    ).deleteEnabledForDepartment(user?.department);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Studio Hardware, Workstations, Wacom Tablets & Software Licenses',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: SizeConfig.fontSize(context, 14),
              ),
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 16)),
            if (!_loading && _error == null) ...[
              _buildStatsDashboard(isMobile),
              SizedBox(height: SizeConfig.scaleHeight(context, 16)),
            ],
            _buildFilters(isMobile),
            SizedBox(height: SizeConfig.scaleHeight(context, 16)),
            Expanded(child: _buildBody(canEdit, canDelete)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(bool isMobile) {
    final total = _items.length;
    final available = _items.where((i) => i['status'] == 'Available').length;
    final assigned = _items.where((i) => i['status'] == 'Assigned').length;
    final maintenance = _items
        .where((i) => i['status'] == 'Maintenance')
        .length;

    final stats = [
      _StatItem(
        'Total Items',
        total.toString(),
        Icons.inventory_2_outlined,
        AppColors.statusPending,
      ),
      _StatItem(
        'Available',
        available.toString(),
        Icons.check_circle_outline,
        AppColors.statusApproved,
      ),
      _StatItem(
        'Assigned',
        assigned.toString(),
        Icons.assignment_ind_outlined,
        AppColors.statusAssigned,
      ),
      _StatItem(
        'Maintenance',
        maintenance.toString(),
        Icons.build_outlined,
        AppColors.statusInProgress,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: SizeConfig.scaleHeight(context, 85),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: stats.length,
          separatorBuilder: (ctx, index) =>
              SizedBox(width: SizeConfig.scaleWidth(context, 8)),
          itemBuilder: (ctx, idx) => SizedBox(
            width: SizeConfig.scaleWidth(context, 140),
            child: _buildStatCard(stats[idx]),
          ),
        ),
      );
    }

    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.scaleWidth(context, 4),
                ),
                child: _buildStatCard(s),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(_StatItem s) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 12),
        vertical: SizeConfig.scaleHeight(context, 8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: SizeConfig.scaleWidth(context, 18),
            backgroundColor: s.color.withValues(alpha: 0.15),
            child: Icon(
              s.icon,
              color: s.color,
              size: SizeConfig.iconSize(context, 18),
            ),
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.title,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 10),
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  s.value,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    final List<String> catOptions = ['All', ..._categories];
    final List<String> statusOptions = ['All', ..._statuses];

    final searchField = Expanded(
      flex: isMobile ? 0 : 2,
      child: TextField(
        decoration: _filterInputDecoration(
          context,
          hintText: 'Search items or serial...',
          prefixIcon: Icon(
            Icons.search,
            size: SizeConfig.iconSize(context, 20),
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );

    final catDropdown = DropdownButtonFormField<String>(
      value: _selectedCategoryFilter,
      decoration: _filterInputDecoration(context, labelText: 'Category'),
      dropdownColor: const Color(0xFF0B1224),
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      items: catOptions
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(
                c,
                style: TextStyle(fontSize: SizeConfig.fontSize(context, 13)),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedCategoryFilter = val;
          });
        }
      },
    );

    final statusDropdown = DropdownButtonFormField<String>(
      value: _selectedStatusFilter,
      decoration: _filterInputDecoration(context, labelText: 'Status'),
      dropdownColor: const Color(0xFF0B1224),
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      items: statusOptions
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(
                s,
                style: TextStyle(fontSize: SizeConfig.fontSize(context, 13)),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedStatusFilter = val;
          });
        }
      },
    );

    if (isMobile) {
      return Column(
        spacing: SizeConfig.scaleHeight(context, 10),
        children: [
          Row(children: [searchField]),
          Row(
            spacing: SizeConfig.scaleWidth(context, 8),
            children: [
              Expanded(child: catDropdown),
              Expanded(child: statusDropdown),
            ],
          ),
        ],
      );
    }

    return Row(
      spacing: SizeConfig.scaleWidth(context, 12),
      children: [
        searchField,
        SizedBox(
          width: SizeConfig.scaleWidth(context, 180),
          child: catDropdown,
        ),
        SizedBox(
          width: SizeConfig.scaleWidth(context, 150),
          child: statusDropdown,
        ),
      ],
    );
  }

  Widget _buildBody(bool canEdit, bool canDelete) {
    if (_loading) return const LoadingWidget();
    if (_error != null && _items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Could not load inventory',
        description: _error!,
        actionLabel: 'Retry',
        onActionPressed: _load,
      );
    }

    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.inventory_2_outlined,
        title: 'No items match filters',
        description: 'Try modifying your search or filters, or add a new item.',
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (ctx, index) =>
          SizedBox(height: SizeConfig.scaleHeight(context, 8)),
      itemBuilder: (ctx, idx) {
        final item = filtered[idx];
        final id = item['id'] as int;
        final name = (item['itemName'] ?? '').toString();
        final category = (item['category'] ?? '').toString();
        final serial = (item['serialNumber'] ?? 'N/A').toString();
        final status = (item['status'] ?? 'Available').toString();
        final assignedName = (item['assignedToName'] ?? 'Unassigned')
            .toString();
        final notes = (item['notes'] ?? '').toString();

        return GlassContainer(
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.scaleWidth(context, 16),
            vertical: SizeConfig.scaleHeight(context, 8),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              category == 'Software License'
                  ? Icons.key_outlined
                  : Icons.computer_outlined,
              color: AppColors.brandGreen,
              size: SizeConfig.iconSize(context, 24),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.fontSize(context, 14),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.scaleWidth(context, 8),
                    vertical: SizeConfig.scaleHeight(context, 3),
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      SizeConfig.scaleWidth(context, 6),
                    ),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.3),
                      width: SizeConfig.scaleWidth(context, 1),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: SizeConfig.fontSize(context, 10),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                Text(
                  'Category: $category  \u2022  Serial: $serial',
                  style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
                ),
                Text(
                  'Assigned to: $assignedName',
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: assignedName == 'Unassigned'
                        ? Colors.grey
                        : AppColors.brandGreen,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                  Text(
                    'Notes: $notes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SizeConfig.fontSize(context, 11),
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            trailing: canEdit
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: SizeConfig.iconSize(context, 18),
                        ),
                        onPressed: () => _addOrEdit(item),
                        tooltip: 'Edit item',
                      ),
                      if (canDelete)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: SizeConfig.iconSize(context, 18),
                            color: AppColors.priorityHigh,
                          ),
                          onPressed: () => _delete(id),
                          tooltip: 'Delete item',
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.title, this.value, this.icon, this.color);
}

class _InventoryDialog extends StatefulWidget {
  final InventoryService service;
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> users;
  final List<String> categories;
  final List<String> statuses;

  const _InventoryDialog({
    required this.service,
    this.item,
    required this.users,
    required this.categories,
    required this.statuses,
  });

  @override
  State<_InventoryDialog> createState() => _InventoryDialogState();
}

class _InventoryDialogState extends State<_InventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedUserId;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!['itemName'] ?? '';
      _serialCtrl.text = widget.item!['serialNumber'] ?? '';
      _notesCtrl.text = widget.item!['notes'] ?? '';
      _selectedCategory = widget.item!['category'];
      _selectedStatus = widget.item!['status'];
      _selectedUserId = widget.item!['assignedToUserId'];
    } else {
      _selectedCategory = widget.categories.first;
      _selectedStatus = widget.statuses.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Inventory Item' : 'Add Inventory Item'),
      content: SizedBox(
        width: SizeConfig.scaleWidth(context, 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: SizeConfig.scaleHeight(context, 12),
              children: [
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: SizeConfig.fontSize(context, 12),
                    ),
                  ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _dialogInputDecoration(
                    context,
                    labelText: 'Item Name*',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _dialogInputDecoration(
                    context,
                    labelText: 'Category*',
                  ),
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 6),
                  ),
                  items: widget.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                  validator: (v) => (v == null) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _serialCtrl,
                  decoration: _dialogInputDecoration(
                    context,
                    labelText: 'Serial Number / License Key',
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _dialogInputDecoration(
                    context,
                    labelText: 'Status*',
                  ),
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 6),
                  ),
                  items: widget.statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStatus = val;
                      if (val != 'Assigned') {
                        _selectedUserId = null;
                      }
                    });
                  },
                  validator: (v) => (v == null) ? 'Required' : null,
                ),
                if (_selectedStatus == 'Assigned')
                  DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: _dialogInputDecoration(
                      context,
                      labelText: 'Assign To User',
                    ),
                    borderRadius: BorderRadius.circular(
                      SizeConfig.scaleWidth(context, 6),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...widget.users.map(
                        (u) => DropdownMenuItem<String>(
                          value: u['userId'],
                          child: Text('${u['name']} (${u['department']})'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedUserId = val),
                  ),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: _dialogInputDecoration(
                    context,
                    labelText: 'Notes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
          ),
          child: _saving
              ? SizedBox(
                  height: SizeConfig.scaleHeight(context, 18),
                  width: SizeConfig.scaleWidth(context, 18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _dialogInputDecoration(
    BuildContext context, {
    required String labelText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 6)),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
    );

    return InputDecoration(
      labelText: labelText,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        vertical: SizeConfig.scaleHeight(context, 12),
        horizontal: SizeConfig.scaleWidth(context, 12),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: AppColors.brandGreen.withValues(alpha: 0.7),
          width: SizeConfig.scaleWidth(context, 1.2),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'itemName': _nameCtrl.text.trim(),
      'category': _selectedCategory,
      'serialNumber': _serialCtrl.text.trim(),
      'status': _selectedStatus,
      'assignedToUserId': _selectedUserId,
      'notes': _notesCtrl.text.trim(),
    };

    try {
      if (widget.item != null) {
        final id = widget.item!['id'] as int;
        await widget.service.updateInventoryItem(id, payload);
      } else {
        await widget.service.addInventoryItem(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }
}
