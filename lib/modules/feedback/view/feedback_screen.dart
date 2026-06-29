import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/shot_model.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../controller/feedback_controller.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  InputDecoration _inputDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
    );

    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
      enabledBorder: baseBorder,
      border: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(
          color: AppColors.brandGreen.withValues(alpha: 0.7),
          width: 1.2,
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
            const Text(
              'Client feedback linked to project shot status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildFilters(controller),
            const SizedBox(height: 12),
            _buildLegend(),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(FeedbackController controller) {
    final departmentItems = <String?>[null, ...controller.departments];
    final clientItems = <String?>[
      null,
      ...controller.clients.map((c) => c.clientId),
    ];
    final showItems = <String?>[null, ...controller.shows.map((s) => s.showId)];
    final statusItems = <String?>[null, ...AppConstants.shotStatuses];

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedDepartment,
                  decoration: _inputDecoration(labelText: 'Department'),
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
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedClientId,
                  decoration: _inputDecoration(labelText: 'Client'),
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
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedShowId,
                  decoration: _inputDecoration(labelText: 'Show'),
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
                width: 190,
                child: DropdownButtonFormField<String?>(
                  value: controller.selectedStatus,
                  decoration: _inputDecoration(labelText: 'Shot Status'),
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
                width: 250,
                child: TextField(
                  controller: _searchController,
                  decoration: _inputDecoration(
                    hintText: 'Search shot / show / client / feedback',
                    prefixIcon: const Icon(Icons.search),
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

  Widget _buildLegend() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.statusInProgress.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Updating shot status from this module notifies the concerned team automatically.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FeedbackController controller) {
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

    final rows = _filteredRows(controller.feedbackShots);
    if (rows.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: 'No client feedback found',
        description: 'Try changing filters to find feedback entries.',
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _feedbackCard(rows[index], controller),
    );
  }

  List<ShotModel> _filteredRows(List<ShotModel> shots) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return shots;

    return shots.where((shot) {
      final client = (shot.clientName ?? '').toLowerCase();
      final show = (shot.showName ?? '').toLowerCase();
      final shotCode = shot.shotCode.toLowerCase();
      final feedback = (shot.clientFeedback ?? '').toLowerCase();
      return client.contains(query) ||
          show.contains(query) ||
          shotCode.contains(query) ||
          feedback.contains(query);
    }).toList();
  }

  Widget _feedbackCard(ShotModel shot, FeedbackController controller) {
    final statusColor = _statusColor(shot.status);

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      shot.shotCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _pill(shot.department, AppColors.statusAssigned),
                    _pill(shot.status, statusColor),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.isSaving
                    ? null
                    : () => _openUpdateDialog(shot, controller),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Update'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${shot.clientName ?? 'Unknown Client'}  •  ${shot.showName ?? 'Unknown Show'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              shot.clientFeedback?.trim().isNotEmpty == true
                  ? shot.clientFeedback!
                  : 'No feedback text',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: color.withValues(alpha: 0.15),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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
            width: 420,
            child: ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (context, currentStatus, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
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
}
