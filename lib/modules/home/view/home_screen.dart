import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/domain_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/glass_container.dart';
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
            padding: const EdgeInsets.all(16),
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
                          SizedBox(width: width * 0.7, child: chartCard),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Expanded(child: pickoutsCard),
                                const SizedBox(height: 16),
                                Expanded(child: inventCard),
                              ],
                            ),
                          ),
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
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 390,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Pickouts",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
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

    final total = items.fold<double>(0, (sum, e) => sum + e.value);
    final highest = items.first;
    final maxValue = items.first.value <= 0 ? 1.0 : items.first.value;

    const lightPalette = [
      AppColors.brandGreen,
      Color(0xFF00C2B2),
      Color(0xFF6EC5FF),
      Color(0xFFFFC86A),
      Color(0xFFFF9FAE),
      Color(0xFFAFC8FF),
    ];

    final textColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final ringTrack = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);

    final radialData = List.generate(items.length, (i) {
      final e = items[i];
      return _DepartmentRadialData(
        name: e.key,
        value: e.value,
        color: lightPalette[i % lightPalette.length],
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandGreen.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: AppColors.brandGreen.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ${total.toStringAsFixed(1)} MD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Highest: ${highest.key} (${highest.value.toStringAsFixed(1)} MD)',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.brandGreen.withValues(alpha: 0.18),
                ),
                child: Text(
                  '${items.length} Depts',
                  style: const TextStyle(
                    color: AppColors.brandGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.4,
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            tooltipBehavior: TooltipBehavior(
              enable: true,
              format: 'point.x\npoint.y MD',
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.85)
                  : Colors.white,
              textStyle: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            annotations: <CircularChartAnnotation>[
              CircularChartAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Mandays',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            series: <RadialBarSeries<_DepartmentRadialData, String>>[
              RadialBarSeries<_DepartmentRadialData, String>(
                dataSource: radialData,
                xValueMapper: (_DepartmentRadialData d, _) => d.name,
                yValueMapper: (_DepartmentRadialData d, _) => d.value,
                pointColorMapper: (_DepartmentRadialData d, _) => d.color,
                maximumValue: maxValue,
                cornerStyle: CornerStyle.bothCurve,
                radius: '96%',
                gap: '10%',
                innerRadius: '28%',
                trackOpacity: 1,
                trackColor: ringTrack,
                useSeriesColor: true,
                animationDuration: 900,
                dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelPosition: ChartDataLabelPosition.outside,
                  textStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(items.length, (i) {
                final part = items[i];
                final percent = total > 0 ? (part.value / total) * 100 : 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: lightPalette[i % lightPalette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 170),
                        child: Text(
                          '${part.key}: ${part.value.toStringAsFixed(1)} MD (${percent.toStringAsFixed(0)}%)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _DepartmentRadialData {
  final String name;
  final double value;
  final Color color;

  const _DepartmentRadialData({
    required this.name,
    required this.value,
    required this.color,
  });
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'InventActive Shows',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            tabs: _statuses.map((s) => Tab(text: s)).toList(growable: false),
            isScrollable: true,
            labelColor: AppColors.brandGreen,
            tabAlignment: TabAlignment.start,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.brandGreen,
            labelPadding: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.symmetric(horizontal: 0),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 0),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          const SizedBox(height: 12),
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
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final show = items[index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                12,
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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
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
