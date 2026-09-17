import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/premium_card.dart';

/// Engine RPM & Fuel Analysis Analytics Workspace Chart
class RpmFuelChartCard extends StatefulWidget {
  final Map<String, dynamic> chartData;
  final ValueChanged<String>? onFilterChanged;

  const RpmFuelChartCard({
    super.key,
    required this.chartData,
    this.onFilterChanged,
  });

  @override
  State<RpmFuelChartCard> createState() => _RpmFuelChartCardState();
}

class _RpmFuelChartCardState extends State<RpmFuelChartCard> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.chartData['filter'] as String? ?? 'Day';
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = (widget.chartData['points'] as List<dynamic>?) ??
        [
          {'time': '06:00', 'rpm': 1200, 'fuel': 10},
          {'time': '08:00', 'rpm': 1650, 'fuel': 22},
          {'time': '10:00', 'rpm': 1890, 'fuel': 35},
          {'time': '12:00', 'rpm': 1750, 'fuel': 28},
          {'time': '14:00', 'rpm': 1980, 'fuel': 42},
          {'time': '16:00', 'rpm': 1820, 'fuel': 31},
          {'time': '18:00', 'rpm': 1600, 'fuel': 18},
          {'time': '20:00', 'rpm': 1100, 'fuel': 8},
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 450;

        final filterBar = Container(
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['Day', 'Week', 'Month'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return InkWell(
                onTap: () => _updateFilter(filter),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.mutedTextGray,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        return PremiumCard(
          title: 'Engine RPM & Fuel Analysis',
          subtitle: 'Fleet totals · avg RPM + fuel burn · 22 machines',
          trailing: isCompact ? null : filterBar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: filterBar,
                ),
                const SizedBox(height: 12),
              ],

              // Subtitle Date Range
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: AppColors.mutedTextGray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '04 Sept, 12:00 am → 04 Sept, 05:00 pm',
                      style: AppTextStyles.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metric Summary Pills
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _ChartMetricPill(
                    label: 'Fuel Used',
                    value: '${widget.chartData['fuelUsed']} L',
                    color: AppColors.infoBlue,
                  ),
                  _ChartMetricPill(
                    label: 'Fuel Refilled',
                    value: '${widget.chartData['fuelRefilled']} L',
                    color: AppColors.primaryGreen,
                  ),
                  _ChartMetricPill(
                    label: 'Avg RPM',
                    value: '${widget.chartData['avgRpm']}',
                    color: AppColors.primaryGreen,
                  ),
                  _ChartMetricPill(
                    label: 'Max RPM',
                    value: '${widget.chartData['maxRpm']}',
                    color: AppColors.warningAmber,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Interactive Line Chart
              SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.borderGray,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < points.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  points[index]['time'].toString(),
                                  style: AppTextStyles.caption,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // Avg RPM Line
                      LineChartBarData(
                        spots: points.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(),
                              (entry.value['rpm'] as num).toDouble());
                        }).toList(),
                        isCurved: true,
                        color: AppColors.primaryGreen,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                      // Fuel Line
                      LineChartBarData(
                        spots: points.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(),
                              (entry.value['fuel'] as num).toDouble() * 40);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.infoBlue,
                        barWidth: 2,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            if (idx >= 0 && idx < points.length) {
                              final point = points[idx];
                              if (spot.barIndex == 0) {
                                return LineTooltipItem(
                                  '${point['time']}\nAvg RPM: ${point['rpm']}',
                                  const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              } else {
                                return LineTooltipItem(
                                  'Fuel: ${point['fuel']} L',
                                  const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }
                            }
                            return null;
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Legend
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChartLegend(
                      label: 'Avg RPM', color: AppColors.primaryGreen, isDashed: false),
                  SizedBox(width: 24),
                  _ChartLegend(
                      label: 'Fuel Used (L)', color: AppColors.infoBlue, isDashed: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChartMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDashed;

  const _ChartLegend({
    required this.label,
    required this.color,
    required this.isDashed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
