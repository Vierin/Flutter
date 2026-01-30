import 'package:flutter/material.dart';
import '../../constants/colors.dart';

enum Period { sevenDays, thirtyDays, oneYear }

class PeriodSelector extends StatelessWidget {
  final Period value;
  final ValueChanged<Period> onValueChange;

  const PeriodSelector({
    super.key,
    required this.value,
    required this.onValueChange,
  });

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

  Future<void> _showPeriodMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    final selected = await showMenu<Period>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy + size.height + 200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: AppColors.backgroundPrimary,
      elevation: 8,
      items: [
        _buildMenuItem(Period.sevenDays),
        _buildMenuItem(Period.thirtyDays),
        _buildMenuItem(Period.oneYear),
      ],
    );

    if (selected != null) {
      onValueChange(selected);
    }
  }

  PopupMenuItem<Period> _buildMenuItem(Period period) {
    final isSelected = value == period;
    return PopupMenuItem<Period>(
      value: period,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getPeriodLabel(period),
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? AppColors.primary500 : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 20, color: AppColors.primary500),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPeriodMenu(context),
        borderRadius: BorderRadius.circular(8),
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
                _getPeriodLabel(value),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
