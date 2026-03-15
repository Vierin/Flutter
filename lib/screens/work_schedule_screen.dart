import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/schedule.dart';
import '../services/auth_service.dart';
import '../services/cache/salon_cache.dart';
import '../services/dashboard_api_service.dart';
import '../utils/show_api_error.dart';
import '../widgets/work_schedule/work_schedule_time_modal.dart';

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
      final salon = await context.read<SalonCache>().getSalon(token);
      if (!mounted) return;
      final wh = salon?.workingHours;
      if (wh is Map<String, dynamic>) {
        for (var i = 0; i < 7 && i < scheduleDayKeys.length; i++) {
          final dayMap = wh[scheduleDayKeys[i]];
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

    final result = await WorkScheduleTimeModal.show(
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

    final result = await WorkScheduleTimeModal.show(
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
    for (var i = 0; i < 7 && i < scheduleDayKeys.length; i++) {
      final s = _schedules[i];
      final closed = s.workFrom.isEmpty || s.workTo.isEmpty;
      workingHours[scheduleDayKeys[i]] = {
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
      context.read<SalonCache>().invalidate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Расписание сохранено')),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
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
                  dayShortName: scheduleDayShortNames[index],
                  dayName: scheduleDayNames[index],
                  schedule: _schedules[index],
                  onDayPillTap: () {
                    if (_schedules[index].hasWorkingHours) {
                      setState(() {
                        _schedules[index].workFrom = '';
                        _schedules[index].workTo = '';
                      });
                    } else {
                      _openWorkingHoursModal(context, index);
                    }
                  },
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
  final VoidCallback onDayPillTap;
  final VoidCallback onWorkingHoursTap;
  final VoidCallback onLunchTap;
  final ValueChanged<bool> onLunchChanged;

  const _DayRow({
    required this.dayShortName,
    required this.dayName,
    required this.schedule,
    required this.onDayPillTap,
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onDayPillTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary500
                        : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: isActive
                        ? 'Тап: выключить день из графика'
                        : 'Тап: включить день и задать часы',
                    child: Text(
                      dayShortName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppColors.textTertiary,
                      ),
                    ),
                  ),
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

