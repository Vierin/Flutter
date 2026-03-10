import 'package:flutter/material.dart';

import '../../constants/colors.dart';

/// Modal: Work schedule time range with wheel pickers.
/// Returns (startHour, startMinute, endHour, endMinute) on Confirm, null on Cancel.
class WorkScheduleTimeModal extends StatefulWidget {
  const WorkScheduleTimeModal({
    super.key,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.title = 'Work schedule',
    this.subtitle = 'Укажите временной диапазон работы',
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String title;
  final String subtitle;

  static Future<(int, int, int, int)?> show({
    required BuildContext context,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String title = 'Work schedule',
    String subtitle = 'Укажите временной диапазон работы',
  }) {
    return showModalBottomSheet<(int, int, int, int)?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkScheduleTimeModal(
        startHour: startHour.clamp(0, 23),
        startMinute: startMinute.clamp(0, 59),
        endHour: endHour.clamp(0, 23),
        endMinute: endMinute.clamp(0, 59),
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<WorkScheduleTimeModal> createState() => _WorkScheduleTimeModalState();
}

class _WorkScheduleTimeModalState extends State<WorkScheduleTimeModal> {
  late FixedExtentScrollController _startHourCtrl;
  late FixedExtentScrollController _startMinCtrl;
  late FixedExtentScrollController _endHourCtrl;
  late FixedExtentScrollController _endMinCtrl;

  late int _startHour;
  late int _startMin;
  late int _endHour;
  late int _endMin;

  @override
  void initState() {
    super.initState();
    _startHourCtrl = FixedExtentScrollController(initialItem: widget.startHour);
    _startMinCtrl = FixedExtentScrollController(initialItem: widget.startMinute);
    _endHourCtrl = FixedExtentScrollController(initialItem: widget.endHour);
    _endMinCtrl = FixedExtentScrollController(initialItem: widget.endMinute);
    _startHour = widget.startHour;
    _startMin = widget.startMinute;
    _endHour = widget.endHour;
    _endMin = widget.endMinute;
  }

  @override
  void dispose() {
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _endHourCtrl.dispose();
    _endMinCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop((_startHour, _startMin, _endHour, _endMin));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: AppColors.primary500,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _TimeWheelRow(
            label: 'Start',
            hourController: _startHourCtrl,
            minuteController: _startMinCtrl,
            selectedHour: _startHour,
            selectedMinute: _startMin,
            onHourChanged: (v) => setState(() => _startHour = v),
            onMinuteChanged: (v) => setState(() => _startMin = v),
          ),
          const SizedBox(height: 20),
          _TimeWheelRow(
            label: 'End',
            hourController: _endHourCtrl,
            minuteController: _endMinCtrl,
            selectedHour: _endHour,
            selectedMinute: _endMin,
            onHourChanged: (v) => setState(() => _endHour = v),
            onMinuteChanged: (v) => setState(() => _endMin = v),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                    side: const BorderSide(color: AppColors.primary500),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Готово'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _wheelItemExtent = 44.0;

class _TimeWheelRow extends StatelessWidget {
  const _TimeWheelRow({
    required this.label,
    required this.hourController,
    required this.minuteController,
    required this.selectedHour,
    required this.selectedMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final String label;
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final int selectedHour;
  final int selectedMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WheelWithStaticHighlight(
                  controller: hourController,
                  itemCount: 24,
                  onSelectedItemChanged: onHourChanged,
                  itemBuilder: (index) => index.toString().padLeft(2, '0'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _WheelWithStaticHighlight(
                  controller: minuteController,
                  itemCount: 60,
                  onSelectedItemChanged: onMinuteChanged,
                  itemBuilder: (index) => index.toString().padLeft(2, '0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelWithStaticHighlight extends StatelessWidget {
  const _WheelWithStaticHighlight({
    required this.controller,
    required this.itemCount,
    required this.onSelectedItemChanged,
    required this.itemBuilder,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _wheelItemExtent,
            diameterRatio: 1.2,
            perspective: 0.003,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelectedItemChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) => Center(
                child: Text(
                  itemBuilder(index),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                height: 36,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.neutral200.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
