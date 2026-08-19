import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/dynamic_data_table.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../controller/bidding_controller.dart';

/// Bidding page showing production-grid shots flagged as 'Bidding'
/// (JAN-DEC status column on the Production Management screen).
class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BiddingController>().fetchGridBids();
      if (mounted) setState(() {});
    });
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      child: Padding(
        padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
        child: Consumer<BiddingController>(
          builder: (context, controller, child) {
            if (controller.gridBidsLoading) {
              return const Center(child: LoadingWidget());
            }
            if (controller.gridBidsError != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: SizeConfig.iconSize(context, 48),
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 12)),
                    Text(
                      controller.gridBidsError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SizeConfig.fontSize(context, 14),
                      ),
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    FilledButton.icon(
                      onPressed: controller.fetchGridBids,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final rows = controller.gridBids
                .map(
                  (b) => <String, dynamic>{
                    'sno': (b['sNo'] ?? 0).toString(),
                    'client': b['client'] ?? '—',
                    'show': b['show'] ?? '—',
                    'shot': b['shotCode'] ?? b['shotId'] ?? '—',
                    'month': b['month'] ?? '—',
                    'frames': b['frames'] ?? '—',
                    'tasks': b['tasks'] ?? '—',
                    'eta': _fmt(b['eta']),
                    'workStation': b['workStation'] ?? '—',
                    'reviewNotes': b['reviewNotes'] ?? '—',
                  },
                )
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: controller.fetchGridBids,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gavel,
                          color: AppColors.brandGreen,
                          size: SizeConfig.iconSize(context, 20),
                        ),
                        SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                        Text(
                          'Bidding — Shots flagged for bidding (JAN-DEC)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: SizeConfig.fontSize(context, 15),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${rows.length} shot(s)',
                          style: TextStyle(
                            color: AppColors.brandGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: SizeConfig.fontSize(context, 13),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 16)),
                    if (rows.isEmpty)
                      const EmptyStateWidget(
                        icon: Icons.gavel,
                        title: 'No bidding shots',
                        description:
                            'Shots marked as "Bidding" in the Production '
                            'Management grid will appear here.',
                      )
                    else
                      GlassContainer(
                        padding: EdgeInsets.all(
                          SizeConfig.scaleWidth(context, 8),
                        ),
                        child: DynamicDataTable(
                          fields: [
                            DynamicTableField(
                              key: 'sno',
                              label: 'S.No',
                              width: SizeConfig.scaleWidth(context, 60),
                            ),
                            DynamicTableField(
                              key: 'client',
                              label: 'Client',
                              width: SizeConfig.scaleWidth(context, 130),
                            ),
                            DynamicTableField(
                              key: 'show',
                              label: 'Show',
                              width: SizeConfig.scaleWidth(context, 150),
                            ),
                            DynamicTableField(
                              key: 'shot',
                              label: 'Shot',
                              width: SizeConfig.scaleWidth(context, 130),
                            ),
                            DynamicTableField(
                              key: 'month',
                              label: 'Month',
                              width: SizeConfig.scaleWidth(context, 90),
                            ),
                            DynamicTableField(
                              key: 'frames',
                              label: 'Frames',
                              width: SizeConfig.scaleWidth(context, 80),
                            ),
                            DynamicTableField(
                              key: 'tasks',
                              label: 'Tasks',
                              width: SizeConfig.scaleWidth(context, 140),
                            ),
                            DynamicTableField(
                              key: 'eta',
                              label: 'ETA',
                              width: SizeConfig.scaleWidth(context, 110),
                            ),
                            DynamicTableField(
                              key: 'workStation',
                              label: 'Work Station',
                              width: SizeConfig.scaleWidth(context, 130),
                            ),
                            DynamicTableField(
                              key: 'reviewNotes',
                              label: 'Review Notes',
                              width: SizeConfig.scaleWidth(context, 180),
                            ),
                          ],
                          rows: rows,
                          showCellBorders: true,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
