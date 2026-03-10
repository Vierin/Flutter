import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/dashboard_api_service.dart';

const _dayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const _dayNames = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const _dayShortNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

class _DaySchedule {
  String workFrom = '09:00';
  String workTo = '18:00';
  bool hasLunch = false;
  String lunchFrom = '12:00';
  String lunchTo = '13:00';
  bool get hasWorkingHours => workFrom.isNotEmpty && workTo.isNotEmpty;
}

class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key});

  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  late List<_DaySchedule> _schedules;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _schedules = List.generate(7, (_) => _DaySchedule());
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final salon = await DashboardApiService.getCurrentSalon(token);
      if (!mounted) return;
      final wh = salon?.workingHours;
      if (wh is Map<String, dynamic>) {
        for (var i = 0; i < 7 && i < _dayKeys.length; i++) {
          final dayMap = wh[_dayKeys[i]];
          if (dayMap is Map<String, dynamic>) {
            final closed = dayMap['closed'] == true;
            final open = dayMap['open']?.toString();
            final close = dayMap['close']?.toString();
            final lunchStart = dayMap['lunchStart']?.toString() ?? '12:00';
            final lunchEnd = dayMap['lunchEnd']?.toString() ?? '13:00';
            _schedules[i].workFrom = (closed || open == null || open.isEmpty) ? '' : open;
            _schedules[i].workTo = (closed || close == null || close.isEmpty) ? '' : close;
            _schedules[i].hasLunch = (dayMap['lunchStart'] != null && dayMap['lunchEnd'] != null) || dayMap['hasLunch'] == true;
            _schedules[i].lunchFrom = lunchStart;
            _schedules[i].lunchTo = lunchEnd;
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Не удалось загрузить расписание');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openWorkingHoursModal(BuildContext context, int dayIndex) async {
    final s = _schedules[dayIndex];
    final startParts = s.workFrom.split(':');
    final endParts = s.workTo.split(':');
    int startHour = int.tryParse(startParts[0]) ?? 9;
    int startMin = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
    int endHour = int.tryParse(endParts[0]) ?? 18;
    int endMin = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;

    final result = await _WorkScheduleTimeModal.show(
      context: context,
      startHour: startHour,
      startMinute: startMin,
      endHour: endHour,
      endMinute: endMin,
    );
    if (result != null && mounted) {
      setState(() {
        _schedules[dayIndex].workFrom =
            '${result.$1.toString().padLeft(2, '0')}:${result.$2.toString().padLeft(2, '0')}';
        _schedules[dayIndex].workTo =
            '${result.$3.toString().padLeft(2, '0')}:${result.$4.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _openLunchModal(BuildContext context, int dayIndex) async {
    final s = _schedules[dayIndex];
    final startParts = s.lunchFrom.split(':');
    final endParts = s.lunchTo.split(':');
    int startHour = int.tryParse(startParts[0]) ?? 12;
    int startMin = startParts.length > 1 ? (int.tryParse(startParts[1]) ?? 0) : 0;
    int endHour = int.tryParse(endParts[0]) ?? 13;
    int endMin = endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0;

    final result = await _WorkScheduleTimeModal.show(
      context: context,
      startHour: startHour,
      startMinute: startMin,
      endHour: endHour,
      endMinute: endMin,
      title: 'Lunch',
      subtitle: 'Укажите время перерыва',
    );
    if (result != null && mounted) {
      setState(() {
        _schedules[dayIndex].lunchFrom =
            '${result.$1.toString().padLeft(2, '0')}:${result.$2.toString().padLeft(2, '0')}';
        _schedules[dayIndex].lunchTo =
            '${result.$3.toString().padLeft(2, '0')}:${result.$4.toString().padLeft(2, '0')}';
        _schedules[dayIndex].hasLunch = true;
      });
    }
  }

  Future<void> _save() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт')),
      );
      return;
    }
    final Map<String, dynamic> workingHours = {};
    for (var i = 0; i < 7 && i < _dayKeys.length; i++) {
      final s = _schedules[i];
      final closed = s.workFrom.isEmpty || s.workTo.isEmpty;
      workingHours[_dayKeys[i]] = {
        'closed': closed,
        if (!closed) 'open': s.workFrom,
        if (!closed) 'close': s.workTo,
        if (s.hasLunch) 'lunchStart': s.lunchFrom,
        if (s.hasLunch) 'lunchEnd': s.lunchTo,
      };
    }
    setState(() => _saving = true);
    try {
      await DashboardApiService.updateCurrentSalon(token, {'workingHours': workingHours});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание сохранено')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text(
          'Work schedule',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _loadError!,
                style: const TextStyle(color: AppColors.error500, fontSize: 14),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: 7,
              itemBuilder: (context, index) {
                return _DayRow(
                  dayShortName: _dayShortNames[index],
                  dayName: _dayNames[index],
                  schedule: _schedules[index],
                  onWorkingHoursTap: () => _openWorkingHoursModal(context, index),
                  onLunchTap: () => _openLunchModal(context, index),
                  onLunchChanged: (v) =>
                      setState(() => _schedules[index].hasLunch = v),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                  child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

class _DayRow extends StatelessWidget {
  final String dayShortName;
  final String dayName;
  final _DaySchedule schedule;
  final VoidCallback onWorkingHoursTap;
  final VoidCallback onLunchTap;
  final ValueChanged<bool> onLunchChanged;

  const _DayRow({
    required this.dayShortName,
    required this.dayName,
    required this.schedule,
    required this.onWorkingHoursTap,
    required this.onLunchTap,
    required this.onLunchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = schedule.hasWorkingHours;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 48,
              margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary500
                  : AppColors.neutral200,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              dayShortName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderPrimary),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: onWorkingHoursTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Working hours',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        schedule.hasWorkingHours
                            ? Text(
                                '${schedule.workFrom} – ${schedule.workTo}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : Text(
                                'Working hours missing',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: schedule.hasLunch,
                          onChanged: (v) => onLunchChanged(v ?? false),
                          activeColor: AppColors.primary500,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lunch',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: schedule.hasLunch
                            ? InkWell(
                                onTap: onLunchTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Text(
                                  '${schedule.lunchFrom} – ${schedule.lunchTo}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : InkWell(
                                onTap: onLunchTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Text(
                                  'Lunch missing',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Modal: Work schedule time range with wheel pickers.
/// Returns (startHour, startMinute, endHour, endMinute) on Confirm, null on Cancel.
class _WorkScheduleTimeModal extends StatefulWidget {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String title;
  final String subtitle;

  const _WorkScheduleTimeModal({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.title = 'Work schedule',
    this.subtitle = 'Укажите временной диапазон работы',
  });

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
      builder: (ctx) => _WorkScheduleTimeModal(
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
  State<_WorkScheduleTimeModal> createState() => _WorkScheduleTimeModalState();
}

class _WorkScheduleTimeModalState extends State<_WorkScheduleTimeModal> {
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
  final String label;
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final int selectedHour;
  final int selectedMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _TimeWheelRow({
    required this.label,
    required this.hourController,
    required this.minuteController,
    required this.selectedHour,
    required this.selectedMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

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

/// Wheel with fixed center highlight (no jumping background).
class _WheelWithStaticHighlight extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(int index) itemBuilder;

  const _WheelWithStaticHighlight({
    required this.controller,
    required this.itemCount,
    required this.onSelectedItemChanged,
    required this.itemBuilder,
  });

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
