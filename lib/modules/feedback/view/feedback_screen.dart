import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/size_config.dart';
import '../../../core/models/shot_model.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/filter_icon.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../controller/feedback_controller.dart';
import '../../../core/models/domain_models.dart';
import '../../tasks/controller/tasks_controller.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _departmentFilter = '';
  final String _clientFilter = '';
  final String _showFilter = '';
  String _statusFilter = '';
  final String _artistFilter = '';
  final String _artistEtaFilter = '';
  String _supervisorStatusFilter = '';
  String _artistStatusFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackController>().init();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
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
    final controller = context.watch<FeedbackController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: controller.loadFeedbacks,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client feedback linked to project shot status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: SizeConfig.fontSize(context, 14),
              ),
            ),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            _buildFilters(context, controller),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            _buildLegend(context),
            SizedBox(height: SizeConfig.scaleHeight(context, 12)),
            Expanded(child: _buildBody(context, controller)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFeedbackDialog(context, controller),
        tooltip: 'Create new feedback',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, FeedbackController controller) {
    final departmentItems = <String?>[null, ...controller.departments];
    final clientItems = <String?>[
      null,
      ...controller.clients.map((c) => c.clientId),
    ];
    final showItems = <String?>[null, ...controller.shows.map((s) => s.showId)];
    final statusItems = <String?>[null, ...AppConstants.shotStatuses];

    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
      child: Column(
        children: [
          Wrap(
            spacing: SizeConfig.scaleWidth(context, 10),
            runSpacing: SizeConfig.scaleHeight(context, 10),
            children: [
              SizedBox(
                width: SizeConfig.scaleWidth(context, 180),
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedDepartment,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Department',
                  ),
                  items: departmentItems
                      .map(
                        (d) => DropdownMenuItem<String?>(
                          value: d,
                          child: Text(d ?? 'All Departments'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    controller.selectDepartment(value);
                    await controller.loadFeedbacks();
                  },
                ),
              ),
              SizedBox(
                width: SizeConfig.scaleWidth(context, 180),
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedClientId,
                  decoration: _inputDecoration(context, labelText: 'Client'),
                  items: clientItems
                      .map(
                        (id) => DropdownMenuItem<String?>(
                          value: id,
                          child: Text(
                            id == null
                                ? 'All Clients'
                                : controller.clients
                                      .firstWhere((c) => c.clientId == id)
                                      .clientName,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    await controller.selectClient(value);
                    await controller.loadFeedbacks();
                  },
                ),
              ),
              SizedBox(
                width: SizeConfig.scaleWidth(context, 180),
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedShowId,
                  decoration: _inputDecoration(context, labelText: 'Show'),
                  items: showItems
                      .map(
                        (id) => DropdownMenuItem<String?>(
                          value: id,
                          child: Text(
                            id == null
                                ? 'All Shows'
                                : controller.shows
                                      .firstWhere((s) => s.showId == id)
                                      .showName,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    controller.selectShow(value);
                    await controller.loadFeedbacks();
                  },
                ),
              ),
              SizedBox(
                width: SizeConfig.scaleWidth(context, 190),
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedStatus,
                  decoration: _inputDecoration(
                    context,
                    labelText: 'Shot Status',
                  ),
                  items: statusItems
                      .map(
                        (status) => DropdownMenuItem<String?>(
                          value: status,
                          child: Text(status ?? 'All Status'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    controller.selectStatus(value);
                    await controller.loadFeedbacks();
                  },
                ),
              ),
              SizedBox(
                width: SizeConfig.scaleWidth(context, 250),
                child: TextField(
                  controller: _searchController,
                  decoration: _inputDecoration(
                    context,
                    hintText: 'Search shot / show / client / feedback',
                    prefixIcon: Icon(
                      Icons.search,
                      size: SizeConfig.iconSize(context, 18),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.scaleWidth(context, 12),
        vertical: SizeConfig.scaleHeight(context, 10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: SizeConfig.iconSize(context, 16),
            color: AppColors.statusInProgress.withValues(alpha: 0.9),
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 8)),
          Expanded(
            child: Text(
              'Updating shot status from this module notifies the concerned team automatically.',
              style: TextStyle(fontSize: SizeConfig.fontSize(context, 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedbackController controller) {
    if (controller.isLoading && controller.feedbackShots.isEmpty) {
      return const LoadingWidget(message: 'Loading client feedback...');
    }

    if (controller.error != null && controller.feedbackShots.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Unable to load feedback',
        description: controller.error!,
      );
    }

    final rows = _buildTableRows(controller.feedbackShots);
    if (rows.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: 'No client feedback found',
        description: 'Try changing filters to find feedback entries.',
      );
    }

    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 8)),
      child: DynamicDataTable(
        headingRowHeight: MediaQuery.of(context).size.height * 42 / 768,
        dataRowMinHeight: MediaQuery.of(context).size.height * 44 / 768,
        dataRowMaxHeight: MediaQuery.of(context).size.height * 56 / 768,
        fields: [
          DynamicTableField(
            key: 'sno',
            label: 'S.No',
            width: SizeConfig.scaleWidth(context, 55),
            numeric: true,
            filterRequired: false,
          ),
          DynamicTableField(
            key: 'shotId',
            label: 'Shot ID',
            width: SizeConfig.scaleWidth(context, 120),
            filterRequired: false,
          ),
          // ── Actions column positioned early so it is always visible ──
          DynamicTableField(
            key: 'actions',
            label: 'Actions',
            width: SizeConfig.scaleWidth(context, 90),
            filterRequired: false,
            builder: (context, value, row, rowIndex) {
              final shot = row['shot'] as ShotModel;
              return IconButton(
                tooltip: 'Update feedback',
                constraints: BoxConstraints(
                  minWidth: SizeConfig.scaleWidth(context, 36),
                  minHeight: SizeConfig.scaleHeight(context, 36),
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.edit_outlined,
                  size: SizeConfig.iconSize(context, 18),
                ),
                onPressed: controller.isSaving
                    ? null
                    : () => _openUpdateDialog(shot, controller),
              );
            },
          ),
          DynamicTableField(
            key: 'department',
            label: 'Department',
            width: SizeConfig.scaleWidth(context, 120),
            filterOptions: _buildOptions(
              controller.departments,
              _departmentFilter,
            ),
          ),
          DynamicTableField(
            key: 'status',
            label: 'Status',
            width: SizeConfig.scaleWidth(context, 130),
            filterOptions: _buildOptions(
              AppConstants.shotStatuses,
              _statusFilter,
            ),
            builder: (context, value, row, rowIndex) {
              final status = (value ?? '—').toString();
              final color = _statusColor(status);
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.scaleWidth(context, 8),
                  vertical: SizeConfig.scaleHeight(context, 4),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 100),
                  ),
                  color: color.withValues(alpha: 0.15),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: SizeConfig.fontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              );
            },
          ),
          DynamicTableField(
            key: 'artist',
            label: 'Artist',
            width: SizeConfig.scaleWidth(context, 140),
            filterRequired: false,
          ),
          DynamicTableField(
            key: 'artistBid',
            label: 'Artist Bid',
            width: SizeConfig.scaleWidth(context, 90),
            numeric: true,
            filterRequired: false,
          ),
          DynamicTableField(
            key: 'artistEta',
            label: 'Artist ETA',
            width: SizeConfig.scaleWidth(context, 110),
            filterRequired: false,
          ),
          DynamicTableField(
            key: 'supervisorStatus',
            label: 'Supervisor Status',
            width: SizeConfig.scaleWidth(context, 145),
            filterOptions: _buildOptions(
              AppConstants.supervisorStatuses,
              _supervisorStatusFilter,
            ),
          ),
          DynamicTableField(
            key: 'artistStatus',
            label: 'Artist Status',
            width: SizeConfig.scaleWidth(context, 130),
            filterOptions: _buildOptions(
              AppConstants.artistStatuses,
              _artistStatusFilter,
            ),
          ),
          DynamicTableField(
            key: 'feedback',
            label: 'Client Feedback',
            width: SizeConfig.scaleWidth(context, 230),
            filterRequired: false,
            builder: (context, value, row, rowIndex) {
              final feedback = (value ?? '—').toString();
              return Tooltip(
                message: feedback,
                child: SizedBox(
                  width: SizeConfig.scaleWidth(context, 220),
                  child: Text(
                    feedback,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ],
        rows: rows,
        onFilterChanged: (fieldKey, value) {
          setState(() {
            final query = value is String ? value : value.toString();
            switch (fieldKey) {
              case 'department':
                _departmentFilter = query;
                break;
              case 'status':
                _statusFilter = query;
                break;
              case 'supervisorStatus':
                _supervisorStatusFilter = query;
                break;
              case 'artistStatus':
                _artistStatusFilter = query;
                break;
            }
          });
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildTableRows(List<ShotModel> shots) {
    final filtered = shots.where((shot) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final client = (shot.clientName ?? '').toLowerCase();
        final show = (shot.showName ?? '').toLowerCase();
        final shotCode = shot.shotCode.toLowerCase();
        final feedback = (shot.clientFeedback ?? '').toLowerCase();
        if (!client.contains(query) &&
            !show.contains(query) &&
            !shotCode.contains(query) &&
            !feedback.contains(query)) {
          return false;
        }
      }

      if (_departmentFilter.isNotEmpty &&
          shot.department != _departmentFilter) {
        return false;
      }
      if (_clientFilter.isNotEmpty &&
          (shot.clientName ?? '').toLowerCase() !=
              _clientFilter.toLowerCase()) {
        return false;
      }
      if (_showFilter.isNotEmpty &&
          (shot.showName ?? '').toLowerCase() != _showFilter.toLowerCase()) {
        return false;
      }
      if (_statusFilter.isNotEmpty && shot.status != _statusFilter) {
        return false;
      }
      if (_artistFilter.isNotEmpty &&
          !(shot.artistName ?? 'Unassigned').toLowerCase().contains(
            _artistFilter.toLowerCase(),
          )) {
        return false;
      }
      if (_artistEtaFilter.isNotEmpty &&
          !_fmtDate(
            shot.artistEta,
          ).toLowerCase().contains(_artistEtaFilter.toLowerCase())) {
        return false;
      }
      if (_supervisorStatusFilter.isNotEmpty &&
          shot.supervisorStatus != _supervisorStatusFilter) {
        return false;
      }
      if (_artistStatusFilter.isNotEmpty &&
          shot.artistStatus != _artistStatusFilter) {
        return false;
      }

      return true;
    }).toList();

    return filtered
        .asMap()
        .entries
        .map((entry) {
          final shot = entry.value;
          final index = entry.key;
          return {
            'sno': index + 1,
            'shotId': shot.shotCode,
            'department': shot.department,
            'status': shot.status,
            'feedback': shot.clientFeedback ?? '—',
            'artist': shot.artistName ?? 'Unassigned',
            'artistBid': shot.artistBid.toStringAsFixed(1),
            'artistEta': _fmtDate(shot.artistEta),
            'supervisorStatus': shot.supervisorStatus ?? '—',
            'artistStatus': shot.artistStatus,
            'shot': shot,
          };
        })
        .toList(growable: false);
  }

  String _fmtDate(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<FilterOption> _buildOptions(List<String> items, String currentValue) {
    final options = <String>{
      if (currentValue.isNotEmpty) currentValue,
      ...items.where((item) => item.isNotEmpty),
    };
    return options
        .map(
          (item) => FilterOption(
            label: item,
            value: item,
            isSelected: item == currentValue,
          ),
        )
        .toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Approved Internal':
        return AppColors.statusApproved;
      case 'Awaiting Approval':
        return AppColors.statusInProgress;
      case 'Hold':
        return AppColors.priorityHigh;
      default:
        return AppColors.statusPending;
    }
  }

  Future<void> _openUpdateDialog(
    ShotModel shot,
    FeedbackController controller,
  ) async {
    final status = ValueNotifier<String>(shot.status);
    final feedbackText = TextEditingController(text: shot.clientFeedback ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Client Feedback'),
          content: SizedBox(
            width: SizeConfig.scaleWidth(context, 420),
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (context, currentStatus, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: SizeConfig.scaleHeight(context, 12),
                  children: [
                    CustomDropdown<String>(
                      labelText: 'Shot Status',
                      value: currentStatus,
                      items: AppConstants.shotStatuses,
                      onChanged: (value) {
                        if (value != null) status.value = value;
                      },
                      itemToString: (item) => item,
                    ),
                    CustomTextField(
                      controller: feedbackText,
                      labelText: 'Client Feedback',
                      hintText: 'Enter latest client feedback',
                      maxLines: 4,
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      feedbackText.dispose();
      status.dispose();
      return;
    }

    final error = await controller.updateFeedbackEntry(
      shot.shotId,
      status: status.value,
      clientFeedback: feedbackText.text.trim(),
    );

    feedbackText.dispose();
    status.dispose();

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.priorityHigh),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback updated. Concerned team has been notified.'),
      ),
    );
  }

  Future<void> _showCreateFeedbackDialog(
    BuildContext context,
    FeedbackController controller,
  ) async {
    String? selectedClientId;
    String? selectedShowId;
    String? selectedDepartment;
    String? selectedStatus = 'Awaiting Approval';
    List<ShowModel> showsList = [];
    bool isShowsLoading = false;

    final shotIdController = TextEditingController();
    final feedbackController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext2, setState) {
          return AlertDialog(
            title: const Text('Create Client Feedback'),
            content: SizedBox(
              width: SizeConfig.scaleWidth(context, 500),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedClientId,
                      hint: const Text('Select Client'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: controller.clients
                          .map(
                            (client) => DropdownMenuItem<String>(
                              value: client.clientId,
                              child: Text(client.clientName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          selectedClientId = value;
                          selectedShowId = null;
                          showsList = [];
                          isShowsLoading = true;
                        });
                        final shows = await controller.getShowsForClient(value);
                        setState(() {
                          showsList = shows;
                          isShowsLoading = false;
                        });
                      },
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(dialogContext2, 12),
                    ),

                    Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedShowId,
                      hint: isShowsLoading
                          ? const Text('Loading shows...')
                          : const Text('Select Show'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: showsList
                          .map(
                            (show) => DropdownMenuItem<String>(
                              value: show.showId,
                              child: Text(show.showName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedShowId = value;
                        });
                      },
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(dialogContext2, 12),
                    ),

                    Text(
                      'Department',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedDepartment,
                      hint: const Text('Select Department'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: controller.departments
                          .map(
                            (dept) => DropdownMenuItem<String>(
                              value: dept,
                              child: Text(dept),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDepartment = value;
                        });
                      },
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(dialogContext2, 12),
                    ),

                    Text(
                      'Shot ID',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    TextField(
                      controller: shotIdController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter Shot ID (e.g. S01_shot10)',
                      ),
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(dialogContext2, 12),
                    ),

                    Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedStatus,
                      hint: const Text('Select Status'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: AppConstants.shotStatuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    SizedBox(
                      height: SizeConfig.scaleHeight(dialogContext2, 12),
                    ),

                    Text(
                      'Client Feedback',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(dialogContext2, 6)),
                    TextField(
                      controller: feedbackController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(
                              SizeConfig.scaleWidth(dialogContext2, 2),
                            ),
                          ),
                        ),
                        hintText: 'Enter client feedback...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedClientId == null ||
                      selectedShowId == null ||
                      selectedDepartment == null ||
                      shotIdController.text.trim().isEmpty ||
                      selectedStatus == null ||
                      feedbackController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true ||
        selectedShowId == null ||
        selectedDepartment == null ||
        shotIdController.text.trim().isEmpty ||
        selectedStatus == null ||
        feedbackController.text.trim().isEmpty) {
      shotIdController.dispose();
      feedbackController.dispose();
      return;
    }

    try {
      final error = await controller.createFeedbackShot(
        showId: selectedShowId!,
        department: selectedDepartment!,
        shotCode: shotIdController.text.trim(),
        status: selectedStatus!,
        clientFeedback: feedbackController.text.trim(),
      );

      if (error != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback saved successfully')),
          );
          try {
            Provider.of<TaskController>(context, listen: false).loadShots();
          } catch (e) {
            debugPrint('Failed to refresh TaskController: $e');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving feedback: $e')));
      }
    } finally {
      shotIdController.dispose();
      feedbackController.dispose();
    }
  }
}
