import 'package:flutter/material.dart';
import '../../constants/colors.dart';

enum Period { sevenDays, thirtyDays, oneYear }

class PeriodSelector extends StatefulWidget {
  final Period value;
  final ValueChanged<Period> onValueChange;

  const PeriodSelector({
    super.key,
    required this.value,
    required this.onValueChange,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  bool _isOpen = false;

  String _getPeriodLabel(Period period) {
    switch (period) {
      case Period.sevenDays:
        return 'Last 7 Days';
      case Period.thirtyDays:
        return 'Last 30 Days';
      case Period.oneYear:
        return 'Last 1 Year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isOpen = !_isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSecondary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getPeriodLabel(widget.value),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: _isOpen ? 3.14159 : 0,
                  child: const Text(
                    '▼',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isOpen)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderPrimary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPeriodItem(Period.sevenDays),
                  _buildPeriodItem(Period.thirtyDays),
                  _buildPeriodItem(Period.oneYear),
                ],
              ),
            ),
          ),
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isOpen = false),
              child: Container(color: Colors.transparent),
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodItem(Period period) {
    final isSelected = widget.value == period;
    return GestureDetector(
      onTap: () {
        widget.onValueChange(period);
        setState(() => _isOpen = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getPeriodLabel(period),
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? AppColors.primary500
                      : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


