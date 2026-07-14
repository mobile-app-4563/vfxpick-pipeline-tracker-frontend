import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        return RefreshIndicator(
          onRefresh: controller.fetchTodaysPickouts,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  if (width >= 980) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 15.0),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.85,
                              width: MediaQuery.of(context).size.width * 0.35,
                              child: _AnimatedEntry(
                                order: 1,
                                child: _RadialBarCard(
                                  title: 'Mandays Radial View',
                                  data: controller.reportMandaysByDepartment,
                                  isLoading: controller.isInsightsLoading,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.85,
                          width: MediaQuery.of(context).size.width * 0.35,
                          child: _AnimatedEntry(
                            order: 0,
                            child: _buildPickoutsCard(controller, isDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.25,
                          height: MediaQuery.of(context).size.height * 0.85,
                          child: _AnimatedEntry(
                            order: 2,
                            child: _InventActiveShowsCard(
                              isLoading: controller.isInventActiveLoading,
                              errorMessage: controller.inventActiveError,
                              data: controller.inventActiveShowsByStatus,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _AnimatedEntry(
                        order: 0,
                        child: _buildPickoutsCard(controller, isDark),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedEntry(
                        order: 1,
                        child: _RadialBarCard(
                          title: 'Mandays Radial View',
                          data: controller.reportMandaysByDepartment,
                          isLoading: controller.isInsightsLoading,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AnimatedEntry(
                        order: 2,
                        child: _InventActiveShowsCard(
                          isLoading: controller.isInventActiveLoading,
                          errorMessage: controller.inventActiveError,
                          data: controller.inventActiveShowsByStatus,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // const SizedBox(height: 16),
              // _AnimatedEntry(
              //   order: 3,
              //   child: SizedBox(
              //     height: 460,
              //     width: double.infinity,
              //     child: _ArtistPerformanceCard(
              //       isLoading: controller.isInsightsLoading,
              //       rows: controller.artistPerformance,
              //     ),
              //   ),
              // ),
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
class _RadialBarCard extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final bool isLoading;

  const _RadialBarCard({
    required this.title,
    required this.data,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final ringItems = sorted.take(3).toList(growable: false);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Expanded(child: Center(child: LoadingWidget()))
            else if (sorted.isEmpty)
              const Expanded(
                child: EmptyStateWidget(
                  icon: Icons.donut_large,
                  title: 'No radial data',
                  description: 'No mandays available to build radial chart.',
                ),
              )
            else
              Expanded(
                child: _RadialProgressChart(
                  ringItems: ringItems,
                  allItems: sorted,
                  maxValue: sorted.first.value <= 0 ? 1.0 : sorted.first.value,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadialProgressChart extends StatelessWidget {
  final List<MapEntry<String, double>> ringItems;
  final List<MapEntry<String, double>> allItems;
  final double maxValue;

  const _RadialProgressChart({
    required this.ringItems,
    required this.allItems,
    required this.maxValue,
  });

  static const _palette = [
    Color(0xFF00C2D1),
    Color(0xFF0BBF9A),
    Color(0xFFEF476F),
    Color(0xFFFF9F68),
  ];

  static const double _progressStrokeWidth = 32;
  static const double _emptyStrokeWidth = 32;
  static const double _ringStep = 90;

  @override
  Widget build(BuildContext context) {
    final rings = ringItems.take(3).toList(growable: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth / 1.3;
        final innerRingSize = size - ((rings.length - 1) * _ringStep);
        final centerHoleSize = (innerRingSize - (_emptyStrokeWidth * 6) - 6)
            .clamp(34.0, 110.0);

        final chart = SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(rings.length, (i) {
                final item = rings[i];
                final progress = (item.value / maxValue).clamp(0.0, 1.0);
                final ringSize = size - (i * _ringStep);
                final color = _palette[i % _palette.length];

                return SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: Duration(milliseconds: 520 + (i * 120)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: 1,
                            strokeWidth: _emptyStrokeWidth,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.withValues(alpha: 0.22),
                            ),
                          ),
                          CircularProgressIndicator(
                            value: value,
                            strokeWidth: _progressStrokeWidth,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }),
              Container(
                width: centerHoleSize,
                height: centerHoleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.darkBg.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        );

        final legend = Padding(
          padding: EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                children: [
                  Text(
                    'Department',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      'Share',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  itemCount: allItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = allItems[i];
                    final isRingMember = i < rings.length;
                    final color = isRingMember
                        ? _palette[i % _palette.length]
                        : Colors.grey.withValues(alpha: 0.55);
                    final nameColor = isRingMember
                        ? null
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.black.withValues(alpha: 0.64));
                    final valueColor = isRingMember
                        ? null
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.78)
                              : Colors.black.withValues(alpha: 0.68));
                    final pct = ((item.value / maxValue) * 100)
                        .clamp(0, 100)
                        .toStringAsFixed(0);
                    return Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: nameColor,
                          ),
                        ),
                        SizedBox(
                          width: 85,
                          child: Text(
                            '$pct%',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: valueColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(child: legend),
            chart,
          ],
        );
      },
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
            const SizedBox(height: 220, child: Center(child: LoadingWidget()))
          else if (widget.errorMessage != null)
            EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Unable to load InventActive shows',
              description: widget.errorMessage!,
            )
          else
            SizedBox(
              height: 220,
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
