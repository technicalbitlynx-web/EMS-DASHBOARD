import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/fmt.dart';

class TrendSeries {
  const TrendSeries({required this.label, required this.color, required this.spots});
  final String label;
  final Color color;
  final List<FlSpot> spots; // x = epoch ms, y = value
}

/// A multi-series time-series line chart with a simple legend.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.series, this.height = 220});

  final List<TrendSeries> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nonEmpty = series.where((s) => s.spots.isNotEmpty).toList();
    if (nonEmpty.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data in range',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final s in nonEmpty) {
      for (final p in s.spots) {
        minX = p.x < minX ? p.x : minX;
        maxX = p.x > maxX ? p.x : maxX;
        minY = p.y < minY ? p.y : minY;
        maxY = p.y > maxY ? p.y : maxY;
      }
    }
    final pad = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY) * 0.12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          children: nonEmpty
              .map((s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 4, color: s.color),
                      const SizedBox(width: 4),
                      Text(s.label, style: const TextStyle(fontSize: 12)),
                    ],
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY - pad,
              maxY: maxY + pad,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, meta) => Text(
                      v.toStringAsFixed(0),
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: ((maxX - minX) / 3).clamp(1, double.infinity),
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        Fmt.timeOnly(
                            DateTime.fromMillisecondsSinceEpoch(v.toInt())),
                        style: TextStyle(
                            fontSize: 9, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: nonEmpty
                  .map((s) => LineChartBarData(
                        spots: s.spots,
                        isCurved: true,
                        color: s.color,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: s.color.withValues(alpha: 0.10),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
