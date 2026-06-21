import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
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

  // void _navigateToDepartment(String department) {
  //   Navigator.of(
  //     context,
  //   ).pushNamed('/tasks', arguments: {'department': department});
  // }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final cards = <Widget>[
          _AnimatedEntry(
            order: 0,
            child: _buildPickoutsCard(controller, isDark),
          ),
          _AnimatedEntry(
            order: 1,
            child: _buildPieSection(
              title: 'Reports Mandays (Current Month)',
              data: controller.reportMandaysByDepartment,
              isLoading: controller.isInsightsLoading,
            ),
          ),
          _AnimatedEntry(
            order: 2,
            child: _buildPieSection(
              title: 'Reviews Mandays (Current Month)',
              data: controller.reviewMandaysByDepartment,
              isLoading: controller.isInsightsLoading,
            ),
          ),

          // _AnimatedEntry(order: 1, child: _CalendarCard()),
        ];

        return RefreshIndicator(
          onRefresh: controller.fetchTodaysPickouts,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1280
                      ? 3
                      : (width >= 760 ? 2 : 1);

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
              const SizedBox(height: 16),
              _AnimatedEntry(
                order: 3,
                child: SizedBox(
                  height: 460,
                  width: double.infinity,
                  child: _ArtistPerformanceCard(
                    isLoading: controller.isInsightsLoading,
                    rows: controller.artistPerformance,
                  ),
                ),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          if (isLoading)
            const SizedBox(height: 220, child: Center(child: LoadingWidget()))
          else
            _DepartmentPieChart(data: data),
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

// class _CalendarCard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final now = DateTime.now();
//     final firstDay = DateTime(now.year, now.month, 1);
//     final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
//     final startWeekday = firstDay.weekday; // 1=Mon .. 7=Sun

//     final weekDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

//     return GlassContainer(
//       padding: const EdgeInsets.all(16),

//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Calendar • ${AppConstants.months[now.month - 1]} ${now.year}',
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: weekDays
//                 .map(
//                   (d) => Expanded(
//                     child: Text(
//                       d,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 )
//                 .toList(growable: false),
//           ),
//           const SizedBox(height: 8),
//           ...List.generate(6, (weekIndex) {
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 6),
//               child: Row(
//                 children: List.generate(7, (dayIndex) {
//                   final cellIndex = weekIndex * 7 + dayIndex;
//                   final dayNumber = cellIndex - (startWeekday - 1) + 1;
//                   final inMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
//                   final isToday = inMonth && dayNumber == now.day;

//                   return Expanded(
//                     child: Container(
//                       height: 30,
//                       width: 20,
//                       margin: const EdgeInsets.symmetric(horizontal: 2),
//                       decoration: BoxDecoration(
//                         color: isToday
//                             ? AppColors.brandGreen
//                             : (inMonth
//                                   ? Colors.transparent
//                                   : Colors.white.withValues(alpha: 0.03)),
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(
//                           color: isToday
//                               ? AppColors.brandGreen
//                               : Colors.white.withValues(alpha: 0.12),
//                         ),
//                       ),
//                       alignment: Alignment.center,
//                       child: Text(
//                         inMonth ? '$dayNumber' : '',
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: isToday
//                               ? FontWeight.w700
//                               : FontWeight.w500,
//                           color: isToday ? Colors.white : null,
//                         ),
//                       ),
//                     ),
//                   );
//                 }),
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
// }

class _DepartmentPieChart extends StatelessWidget {
  final Map<String, double> data;
  const _DepartmentPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data.entries
        .where((e) => e.value > 0)
        .toList(growable: false);
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pie_chart_outline,
        title: 'No chart data',
        description: 'No mandays available for the selected period.',
      );
    }

    final total = items.fold<double>(0, (sum, e) => sum + e.value);
    const palette = [
      Color(0xFF3EBA02),
      Color(0xFF00B7C2),
      Color(0xFFFFB020),
      Color(0xFF5B8DEF),
      Color(0xFFEF476F),
    ];

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: List.generate(items.length, (i) {
                final part = items[i];
                final percent = (part.value / total) * 100;
                return PieChartSectionData(
                  color: palette[i % palette.length],
                  value: part.value,
                  radius: 74,
                  title: '${percent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(items.length, (i) {
            final part = items[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${part.key}: ${part.value.toStringAsFixed(1)}'),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _ArtistPerformanceCard extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> rows;

  const _ArtistPerformanceCard({required this.isLoading, required this.rows});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Artist Performance (All Users)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            Center(child: const LoadingWidget())
          else if (rows.isEmpty)
            const EmptyStateWidget(
              icon: Icons.bar_chart,
              title: 'No performance data',
              description: 'No artist performance records available.',
            )
          else
            Expanded(
              child: Builder(
                builder: (_) {
                  final maxMandays = _maxMandays(rows);
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barTouchData: BarTouchData(enabled: true),
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: _leftAxisTitle,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= rows.length) {
                                return const SizedBox.shrink();
                              }
                              final name = (rows[index]['name'] ?? '')
                                  .toString();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: -math.pi / 5,
                                  child: Text(
                                    name.length > 8
                                        ? name.substring(0, 8)
                                        : name,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(rows.length, (i) {
                        final raw = (rows[i]['totalMandays'] as num? ?? 0)
                            .toDouble();
                        final y = _toPercent(raw, maxMandays);
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: y,
                              width: 20,
                              borderRadius: BorderRadius.circular(0),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3EBA02), Color(0xFF00B7C2)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static Widget _leftAxisTitle(double value, TitleMeta meta) {
    if (value % 20 != 0) {
      return const SizedBox.shrink();
    }
    return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
  }

  double _maxMandays(List<Map<String, dynamic>> rows) {
    double maxValue = 0;
    for (final row in rows) {
      final val = (row['totalMandays'] as num? ?? 0).toDouble();
      if (val > maxValue) maxValue = val;
    }
    return maxValue <= 0 ? 1 : maxValue;
  }

  double _toPercent(double value, double total) {
    if (total <= 0) return 0;
    final percent = (value / total) * 100;
    return percent.clamp(0, 100);
  }
}
