import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_box_border.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/production_pickout_widget.dart';
import '../../../shared/widgets/todays_pickout_widget.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/home_controller.dart';

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
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Left column: production pickouts ──
                      Expanded(
                        child: _typeColumn(
                          controller,
                          isDark,
                          title: 'Production Pickouts',
                          isProduction: true,
                        ),
                      ),
                      SizedBox(width: SizeConfig.scaleWidth(context, 16)),
                      // ── Right column: project (shot) pickouts ──
                      Expanded(
                        child: _typeColumn(
                          controller,
                          isDark,
                          title: 'Project Pickouts',
                          isProduction: false,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds one column of the split pickouts card for a single pickout type
  /// (production concerns or project shots). Inside the column the items are
  /// grouped into "Due Today" and "Due Tomorrow" sections so the card shows
  /// today's and tomorrow's pickouts for both project and production.
  Widget _typeColumn(
    HomeController controller,
    bool isDark, {
    required String title,
    required bool isProduction,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final dueToday = <Widget>[];
    final dueTomorrow = <Widget>[];

    if (isProduction) {
      for (final concern in controller.productionPickouts) {
        final widget = ProductionPickoutWidget(
          concern: concern,
          onTap: () {
            Navigator.of(context).pushNamed('/production-management');
          },
        );
        if (_isSameDay(concern.dueDate, today)) {
          dueToday.add(widget);
        } else if (_isSameDay(concern.dueDate, tomorrow)) {
          dueTomorrow.add(widget);
        }
      }
    } else {
      for (final pickout in controller.todaysPickouts) {
        final widget = TodaysPickoutWidget(
          pickout: pickout,
          onTap: () {
            Navigator.of(context).pushNamed(
              '/tasks',
              arguments: {'selectedShot': pickout.shot.shotId},
            );
          },
        );
        if (_isSameDay(pickout.shot.dueDate, today)) {
          dueToday.add(widget);
        } else if (_isSameDay(pickout.shot.dueDate, tomorrow)) {
          dueTomorrow.add(widget);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, isDark),
        Expanded(
          child: ListView(
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
          ),
        ),
      ],
    );
  }

  /// True when [due] is on the same calendar day as [day].
  bool _isSameDay(DateTime? due, DateTime day) {
    if (due == null) return false;
    return due.year == day.year && due.month == day.month && due.day == day.day;
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
