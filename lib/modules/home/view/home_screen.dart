import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/gradient_box_border.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/todays_pickout_widget.dart';
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
      context.read<HomeController>().fetchTodaysPickouts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final pickoutsCard = _AnimatedEntry(
          order: 0,
          child: _buildPickoutsCard(controller, isDark),
        );
        final chartCard = _AnimatedEntry(
          order: 1,
          child: _buildPieSection(
            title: 'Reports Mandays (Current Month)',
            data: controller.reportMandaysByDepartment,
            isLoading: controller.isInsightsLoading,
          ),
        );
        final inventCard = _AnimatedEntry(
          order: 2,
          child: _InventActiveShowsCard(
            isLoading: controller.isInventActiveLoading,
            data: controller.inventActiveShowsByStatus,
            errorMessage:
                controller.inventActiveError ?? controller.errorMessage,
          ),
        );

        return RefreshIndicator(
          onRefresh: () => controller.fetchTodaysPickouts(),
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
                          SizedBox(width: width * 0.35, child: chartCard),
                          SizedBox(width: SizeConfig.scaleWidth(context, 16)),
                          Expanded(child: pickoutsCard),
                          SizedBox(width: SizeConfig.scaleWidth(context, 16)),
                          Expanded(child: inventCard),
                        ],
                      ),
                    );
                  }

                  final cards = <Widget>[pickoutsCard, chartCard, inventCard];
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
            child: Builder(
              builder: (_) {
                if (controller.isLoading) {
                  return const Center(child: LoadingWidget());
                }
                if (controller.errorMessage != null) {
                  return EmptyStateWidget(
                    title: "Error Loading Pickouts",
                    description: controller.errorMessage!,
                    icon: Icons.error_outline,
                  );
                }
                if (controller.todaysPickouts.isEmpty) {
                  return const EmptyStateWidget(
                    title: "No Pickouts Today",
                    description: "No shots allocated for today.",
                    icon: Icons.calendar_today,
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: controller.todaysPickouts.map((pickout) {
                      return TodaysPickoutWidget(
                        pickout: pickout,
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/tasks',
                            arguments: {'selectedShot': pickout.shot.shotId},
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieSection({
    required String title,
    required Map<String, double> data,
    required bool isLoading,
  }) {
    return GlassContainer(
      padding: EdgeInsets.all(SizeConfig.scaleWidth(context, 16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.scaleHeight(context, 4)),
          Text(
            title,
            style: TextStyle(
              fontSize: SizeConfig.fontSize(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 24)),
          Expanded(
            child: isLoading
                ? const Center(child: LoadingWidget())
                : _DepartmentRadialChart(data: data),
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

class _DepartmentRadialChart extends StatelessWidget {
  final Map<String, double> data;
  const _DepartmentRadialChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pie_chart_outline,
        title: 'No chart data',
        description: 'No mandays available for the selected period.',
      );
    }

    final topItems = items.take(4).toList(growable: false);
    final maxValue = topItems.first.value <= 0 ? 1.0 : topItems.first.value;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const palette = [
      _RingPalette(
        fill: Color(0xFF90E2E0),
        balanceDark: Color(0xFF2C3438),
        balanceLight: Color(0xFFD7DDDF),
      ),
      _RingPalette(
        fill: Color(0xFFAED8EC),
        balanceDark: Color(0xFF2D363D),
        balanceLight: Color(0xFFDCE1E5),
      ),
      _RingPalette(
        fill: Color(0xFFF3C2CF),
        balanceDark: Color(0xFF3A3135),
        balanceLight: Color(0xFFE5DCDF),
      ),
      _RingPalette(
        fill: Color(0xFFF2DBAF),
        balanceDark: Color(0xFF3E3930),
        balanceLight: Color(0xFFE7E0D3),
      ),
    ];

    final radialData = List.generate(topItems.length, (index) {
      final entry = topItems[index];
      final percent = (entry.value / maxValue) * 100;
      final colors = palette[index % palette.length];
      return _DepartmentRadialData(
        name: entry.key,
        value: percent.clamp(0, 100),
        color: colors.fill,
        balanceColor: isDark ? colors.balanceDark : colors.balanceLight,
      );
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: radialData
                .map((item) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: SizeConfig.scaleHeight(context, 8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: SizeConfig.scaleWidth(context, 8),
                          height: SizeConfig.scaleHeight(context, 8),
                          margin: EdgeInsets.only(
                            top: SizeConfig.scaleHeight(context, 3),
                          ),
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(
                              SizeConfig.scaleWidth(context, 2),
                            ),
                          ),
                        ),
                        SizedBox(width: SizeConfig.scaleWidth(context, 8)),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: textColor,
                                fontSize: SizeConfig.fontSize(context, 14),
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(text: '${item.name} '),
                                TextSpan(
                                  text: '${item.value.round()}%',
                                  style: TextStyle(
                                    color: item.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
          SizedBox(height: SizeConfig.scaleHeight(context, 12)),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: SizeConfig.scaleWidth(context, 455),
                height: SizeConfig.scaleHeight(context, 455),
                child: SfCircularChart(
                  margin: EdgeInsets.zero,
                  series: List.generate(radialData.length, (index) {
                    final item = radialData[index];
                    return DoughnutSeries<_ChartSlice, String>(
                      dataSource: [
                        _ChartSlice(item.name, item.value, item.color),
                        _ChartSlice(
                          '${item.name} Balance',
                          100 - item.value,
                          item.balanceColor,
                        ),
                      ],
                      xValueMapper: (_ChartSlice point, _) => point.label,
                      yValueMapper: (_ChartSlice point, _) => point.value,
                      pointColorMapper: (_ChartSlice point, _) => point.color,
                      radius: '${100 - (index * 15)}%',
                      innerRadius: '${91 - (index * 15)}%',
                      startAngle: 0,
                      endAngle: 270,
                      explode: false,
                      animationDuration: 900,
                      strokeColor: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      strokeWidth: 1.5,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: false,
                      ),
                    );
                  }),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x\npoint.y%',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentRadialData {
  final String name;
  final double value;
  final Color color;
  final Color balanceColor;

  const _DepartmentRadialData({
    required this.name,
    required this.value,
    required this.color,
    required this.balanceColor,
  });
}

class _RingPalette {
  final Color fill;
  final Color balanceDark;
  final Color balanceLight;

  const _RingPalette({
    required this.fill,
    required this.balanceDark,
    required this.balanceLight,
  });
}

class _ChartSlice {
  final String label;
  final double value;
  final Color color;

  const _ChartSlice(this.label, this.value, this.color);
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
