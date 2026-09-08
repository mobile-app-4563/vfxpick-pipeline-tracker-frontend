import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_box_border.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/home_controller.dart';
import '../controller/home_pickout_item.dart';

/// Home page with pickouts, department quick filter and analytics cards.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().currentUser;
      context.read<HomeController>().fetchTodaysPickouts(
        role: user?.role,
        department: user?.department,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authController = context.read<AuthController>();
    final userDepartment = authController.currentUser?.department ?? '';
    final userRole = authController.currentUser?.role ?? '';

    return Consumer<HomeController>(
      builder: (context, controller, child) {
        // Every user gets the same home layout: pickouts shown as two
        // separate lists (Production Pickouts + Project Pickouts) plus the
        // InventActive shows card. The mandays chart has been removed.
        final pickoutsCard = _AnimatedEntry(
          order: 0,
          child: _buildPickoutsCard(controller, isDark),
        );

        final inventCard = _AnimatedEntry(
          order: 1,
          child: _InventActiveShowsCard(
            isLoading: controller.isInventActiveLoading,
            data: controller.inventActiveShowsByStatus,
            errorMessage:
                controller.inventActiveError ?? controller.errorMessage,
          ),
        );

        return RefreshIndicator(
          onRefresh: () => controller.fetchTodaysPickouts(
            role: userRole,
            department: userDepartment,
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isWide = width >= 1180;

                  if (isWide) {
                    return SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: pickoutsCard),
                          SizedBox(width: SizeConfig.scaleWidth(context, 16)),
                          Expanded(child: inventCard),
                        ],
                      ),
                    );
                  }

                  final cards = <Widget>[pickoutsCard, inventCard];
                  final crossAxisCount = width >= 760 ? 2 : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: SizeConfig.scaleWidth(context, 16),
                      mainAxisSpacing: SizeConfig.scaleHeight(context, 16),
                      mainAxisExtent: SizeConfig.scaleHeight(context, 390),
                    ),
                    itemBuilder: (context, index) => cards[index],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickoutsCard(HomeController controller, bool isDark) {
    final isLoading = controller.isLoading || controller.isProductionLoading;
    final error = controller.errorMessage ?? controller.productionError;

    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Pickouts",
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 14)),
          Expanded(
            child: isLoading
                ? const Center(child: LoadingWidget())
                : error != null
                ? EmptyStateWidget(
                    title: "Error Loading Pickouts",
                    description: error,
                    icon: Icons.error_outline,
                  )
                : _buildCombinedPickouts(controller, isDark),
          ),
        ],
      ),
    );
  }

  /// Builds the single merged pickouts list inside the card. Project shots
  /// and production-grid rows are combined per shot (see
  /// [HomeController.combinedPickouts]) and bucketed into Due Today / Due
  /// Tomorrow. Each tile shows the data the API returned for that shot from
  /// whichever module(s) reported it.
  Widget _buildCombinedPickouts(HomeController controller, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final dueToday = <Widget>[];
    final dueTomorrow = <Widget>[];

    for (final item in controller.combinedPickouts) {
      final tile = _CombinedPickoutTile(
        item: item,
        onTap: () {
          final shotId = item.shot?.shot.shotId;
          if (shotId != null && shotId.isNotEmpty) {
            Navigator.of(
              context,
            ).pushNamed('/tasks', arguments: {'selectedShot': shotId});
          } else {
            Navigator.of(context).pushNamed('/production-management');
          }
        },
      );
      if (_isSameDay(item.dueDate, today)) {
        dueToday.add(tile);
      } else if (_isSameDay(item.dueDate, tomorrow)) {
        dueTomorrow.add(tile);
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _sectionHeader('Due Today', isDark),
        if (dueToday.isEmpty)
          _compactEmpty('Nothing due today.', Icons.today)
        else
          ...dueToday,
        _sectionHeader('Due Tomorrow', isDark),
        if (dueTomorrow.isEmpty)
          _compactEmpty('Nothing due tomorrow.', Icons.event)
        else
          ...dueTomorrow,
      ],
    );
  }

  /// True when [due] falls on the same MONTH+DAY as [day]. Imported Excel
  /// dates carry meaningless years, so the year is deliberately ignored
  /// (a 2022-09-09 ETA still counts as "Due Tomorrow" for 2026-09-09).
  bool _isSameDay(DateTime? due, DateTime day) {
    if (due == null) return false;
    return due.month == day.month && due.day == day.day;
  }

  /// Compact section header inside the pickouts card.
  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(
        top: SizeConfig.scaleHeight(context, 10),
        bottom: SizeConfig.scaleHeight(context, 4),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 13),
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  /// Compact inline empty message used inside the two pickout sections.
  Widget _compactEmpty(String message, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: SizeConfig.scaleHeight(context, 16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: SizeConfig.iconSize(context, 18),
            color: Colors.grey,
          ),
          SizedBox(width: SizeConfig.scaleWidth(context, 8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(context, 13),
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single merged pickout card. Displays all the data the API returned for
/// the shot — whichever module(s) it came from (project shots and/or the
/// production grid row).
class _CombinedPickoutTile extends StatelessWidget {
  final HomePickoutItem item;
  final VoidCallback? onTap;

  const _CombinedPickoutTile({required this.item, this.onTap});

  Color _priorityColor() {
    switch (item.priorityRank) {
      case 1:
        return AppColors.priorityCritical; // Red for critical
      case 2:
        return AppColors.priorityHigh; // Orange for high
      case 3:
        return AppColors.priorityMedium; // Amber for medium
      default:
        return AppColors.priorityLow; // Blue for low
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _priorityColor();
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final metaChips = <Widget>[
      if (item.hasProject) _chip(context, 'Project', AppColors.brandGreen),
      if (item.hasProduction)
        _chip(context, 'Production', AppColors.statusAssigned),
      if ((item.department ?? '').isNotEmpty)
        _chip(context, item.department!, AppColors.priorityLow),
      if ((item.task ?? '').isNotEmpty)
        _chip(context, item.task!, AppColors.statusReview),
      if ((item.status ?? '').isNotEmpty)
        _chip(context, item.status!, AppColors.statusApproved),
    ];

    return Card(
      margin: SizeConfig.paddingSymmetric(context, horizontal: 16, vertical: 8),
      elevation: 0,
      color: isDark ? AppColors.darkCardFill : AppColors.lightCardFill,
      shape: GradientBoxBorder(
        gradient: AppColors.brandGradient,
        width: SizeConfig.scaleWidth(context, 1),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 8)),
        child: Container(
          padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 12)),
          child: Row(
            children: [
              // Priority badge
              Container(
                width: SizeConfig.scaleWidth(context, 4),
                height: SizeConfig.scaleHeight(context, 76),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(
                    SizeConfig.scaleWidth(context, 2),
                  ),
                ),
              ),
              SizeConfig.sizedBoxW(context, 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Shot code + Priority label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.shotCode.isEmpty
                                ? (item.shot?.shot.shotCode ??
                                      item.concern?.shotId ??
                                      'Shot')
                                : item.shotCode,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 14),
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: SizeConfig.paddingSymmetric(
                            context,
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 4),
                            ),
                            border: Border.all(
                              color: priorityColor,
                              width: SizeConfig.scaleWidth(context, 0.5),
                            ),
                          ),
                          child: Text(
                            item.priorityLabel,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 10),
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 2: Show name + module/department/task/status chips
                    if (item.showName.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: SizeConfig.scaleHeight(context, 4),
                        ),
                        child: Text(
                          item.showName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 12),
                            color: textSecondary,
                          ),
                        ),
                      ),
                    if (metaChips.isNotEmpty)
                      Wrap(
                        spacing: SizeConfig.scaleWidth(context, 6),
                        runSpacing: SizeConfig.scaleHeight(context, 4),
                        children: metaChips,
                      ),
                    SizedBox(height: SizeConfig.scaleHeight(context, 4)),
                    // Row 3: Priority reason + Due date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.priorityReason,
                            style: TextStyle(
                              fontSize: SizeConfig.fontSize(context, 11),
                              color: priorityColor,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Due: ${_formatDate(item.dueDate)}',
                          style: TextStyle(
                            fontSize: SizeConfig.fontSize(context, 10),
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: SizeConfig.paddingSymmetric(context, horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(SizeConfig.scaleWidth(context, 3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SizeConfig.fontSize(context, 10),
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _AnimatedEntry extends StatefulWidget {
  final int order;
  final Widget child;
  const _AnimatedEntry({required this.order, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 * widget.order), () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        child: widget.child,
      ),
    );
  }
}

class _InventActiveShowsCard extends StatefulWidget {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, List<InventActiveShow>> data;

  const _InventActiveShowsCard({
    required this.isLoading,
    required this.errorMessage,
    required this.data,
  });

  @override
  State<_InventActiveShowsCard> createState() => _InventActiveShowsCardState();
}

class _InventActiveShowsCardState extends State<_InventActiveShowsCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _statuses = ['Approved', 'Approved Internal'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '-';
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '${value.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'InventActive Shows',
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          TabBar(
            controller: _tabController,
            tabs: _statuses.map((s) => Tab(text: s)).toList(growable: false),
            isScrollable: true,
            labelColor: AppColors.brandGreen,
            tabAlignment: TabAlignment.start,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.brandGreen,
            labelPadding: EdgeInsets.symmetric(
              horizontal: SizeConfig.scaleWidth(context, 15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 0),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 0),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          if (widget.isLoading)
            const Expanded(child: Center(child: LoadingWidget()))
          else if (widget.errorMessage != null)
            Expanded(
              child: EmptyStateWidget(
                icon: Icons.error_outline,
                title: 'Unable to load InventActive shows',
                description: widget.errorMessage!,
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _statuses
                    .map((status) {
                      final items =
                          widget.data[status] ?? const <InventActiveShow>[];
                      if (items.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.layers_clear,
                          title: 'No shows found',
                          description:
                              'No show data available for this project status.',
                        );
                      }

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => SizedBox(
                          height: SizeConfig.scaleHeight(context, 8),
                        ),
                        itemBuilder: (context, index) {
                          final show = items[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                SizeConfig.scaleWidth(context, 10),
                              ),
                              border: GradientBoxBorder(
                                gradient: AppColors.brandGradient,
                                width: 1,
                              ),
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.scaleWidth(context, 12),
                              ),
                              childrenPadding: EdgeInsets.fromLTRB(
                                SizeConfig.scaleWidth(context, 12),
                                0,
                                SizeConfig.scaleWidth(context, 12),
                                SizeConfig.scaleHeight(context, 12),
                              ),
                              title: Text(
                                show.showName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${show.clientName} • ${show.shotCount} shots • ${show.totalMandays.toStringAsFixed(1)} MD',
                              ),
                              children: [
                                _DetailRow(
                                  label: 'Client ID',
                                  value: show.clientId,
                                ),
                                _DetailRow(
                                  label: 'Show ID',
                                  value: show.showId,
                                ),
                                _DetailRow(label: 'Status', value: show.status),
                                _DetailRow(
                                  label: 'Departments',
                                  value: show.departments.join(', '),
                                ),
                                _DetailRow(
                                  label: 'Due Window',
                                  value:
                                      '${_dateLabel(show.minDueDate)} to ${_dateLabel(show.maxDueDate)}',
                                ),
                                _DetailRow(
                                  label: 'Last Updated',
                                  value: _dateLabel(show.lastUpdatedAt),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 10),
                                ),
                                const Divider(height: 1),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 10),
                                ),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Shots',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.scaleHeight(context, 6),
                                ),
                                if (show.shots.isEmpty)
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'No shot rows in this status.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  ...show.shots.map((shot) {
                                    return Padding(
                                      padding: EdgeInsets.all(
                                        SizeConfig.scaleWidth(context, 8),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(
                                            SizeConfig.scaleWidth(context, 10),
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              SizeConfig.scaleWidth(context, 8),
                                            ),
                                            color: Colors.white.withValues(
                                              alpha: 0.03,
                                            ),
                                            border: GradientBoxBorder(
                                              gradient: AppColors.brandGradient,
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shot.shotCode,
                                                textAlign: TextAlign.start,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(
                                                height: SizeConfig.scaleHeight(
                                                  context,
                                                  4,
                                                ),
                                              ),
                                              Text(
                                                '${shot.department} • ${shot.mandays.toStringAsFixed(1)} MD • Due ${_dateLabel(shot.dueDate)}',
                                                textAlign: TextAlign.start,
                                              ),
                                              SizedBox(
                                                height: SizeConfig.scaleHeight(
                                                  context,
                                                  2,
                                                ),
                                              ),
                                              Text(
                                                'Artist: ${shot.artistName?.isNotEmpty == true ? shot.artistName : '-'}',
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      );
                    })
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: SizeConfig.scaleHeight(context, 8)),
      child: Row(
        children: [
          SizedBox(
            width: SizeConfig.scaleWidth(context, 110),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
