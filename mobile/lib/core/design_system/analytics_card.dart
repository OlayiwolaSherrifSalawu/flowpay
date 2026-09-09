import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/radii.dart';

/// Single bar data point for FlowPayAnalyticsCard
class AnalyticsBarData {
  final String label;
  final double value;
  final bool isPeak;

  const AnalyticsBarData({
    required this.label,
    required this.value,
    this.isPeak = false,
  });
}

/// Dribbble-inspired Dark Analytics Bar Chart Container
/// Features rounded vertical bar indicators, highlighted peak bar in vibrant emerald,
/// and a time period selector pill (e.g. "Month ˅").
class FlowPayAnalyticsCard extends StatefulWidget {
  final String title;
  final String? totalAmount;
  final List<AnalyticsBarData> data;
  final String selectedPeriod;
  final List<String> availablePeriods;
  final ValueChanged<String>? onPeriodChanged;
  final ValueChanged<int>? onBarSelected;

  const FlowPayAnalyticsCard({
    super.key,
    this.title = 'Activity Breakdown',
    this.totalAmount,
    required this.data,
    this.selectedPeriod = 'Month',
    this.availablePeriods = const ['Week', 'Month', 'Year'],
    this.onPeriodChanged,
    this.onBarSelected,
  });

  @override
  State<FlowPayAnalyticsCard> createState() => _FlowPayAnalyticsCardState();
}

class _FlowPayAnalyticsCardState extends State<FlowPayAnalyticsCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final maxValue = widget.data.fold<double>(
      0.0,
      (prev, item) => math.max(prev, item.value),
    );
    final effectiveMax = maxValue == 0 ? 1.0 : maxValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1210), // Dark ink container
        borderRadius: FlowPayRadii.cardLarge,
        border: Border.all(
          color: const Color(0xFF1E3328),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title/Total & Period Pill Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFA3B8AD),
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.totalAmount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.totalAmount!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
              // Period Dropdown Selector Pill
              PopupMenuButton<String>(
                initialValue: widget.selectedPeriod,
                onSelected: widget.onPeriodChanged,
                color: const Color(0xFF16241D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF243A2E)),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FlowPayColors.emerald400.withAlpha(220),
                    borderRadius: FlowPayRadii.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.selectedPeriod,
                        style: const TextStyle(
                          color: Color(0xFF0C1210),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF0C1210),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => widget.availablePeriods
                    .map((p) => PopupMenuItem(
                          value: p,
                          child: Text(
                            p,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Chart Area: Vertical Bars
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.data.length, (index) {
                final item = widget.data[index];
                final ratio = (item.value / effectiveMax).clamp(0.12, 1.0);
                final isSelected = _hoveredIndex == index;
                final isHighlight = item.isPeak || isSelected;

                final barColor = isHighlight
                    ? FlowPayColors.emerald400
                    : const Color(0xFF223A2C);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _hoveredIndex = index);
                      widget.onBarSelected?.call(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: 100 * ratio,
                            width: 14,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isHighlight
                                  ? [
                                      BoxShadow(
                                        color: FlowPayColors.emerald400
                                            .withAlpha(80),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isHighlight
                                  ? Colors.white
                                  : const Color(0xFF71887D),
                              fontSize: 11,
                              fontWeight: isHighlight
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
