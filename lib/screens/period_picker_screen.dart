import 'package:flutter/material.dart';
import '../constants/colors.dart';

const _monthNamesRu = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

/// Full-screen period picker in app style.
/// Returns [DateTimeRange] when Apply is pressed, null when back.
class PeriodPickerScreen extends StatefulWidget {
  final DateTimeRange initialRange;

  const PeriodPickerScreen({
    super.key,
    required this.initialRange,
  });

  static Future<DateTimeRange?> show(BuildContext context, DateTimeRange initial) {
    return Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        builder: (_) => PeriodPickerScreen(initialRange: initial),
      ),
    );
  }

  @override
  State<PeriodPickerScreen> createState() => _PeriodPickerScreenState();
}

class _PeriodPickerScreenState extends State<PeriodPickerScreen> {
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  late DateTime _displayMonth;
  DateTime? _tapStart;

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialRange.start;
    _rangeEnd = widget.initialRange.end;
    _displayMonth = DateTime(_rangeStart.year, _rangeStart.month);
  }

  void _applyQuick(DateTime start, DateTime end) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _displayMonth = DateTime(start.year, start.month);
      _tapStart = null;
    });
  }

  void _onDateTap(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    setState(() {
      if (_tapStart == null) {
        _tapStart = d;
        _rangeStart = d;
        _rangeEnd = d;
      } else {
        if (d.isBefore(_tapStart!)) {
          _rangeStart = d;
          _rangeEnd = _tapStart!;
        } else {
          _rangeStart = _tapStart!;
          _rangeEnd = d;
        }
        _tapStart = null;
      }
    });
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  void _apply() {
    Navigator.of(context).pop(DateTimeRange(start: _rangeStart, end: _rangeEnd));
  }

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(_displayMonth.year, _displayMonth.month);
    final lastOfMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final firstWeekday = firstOfMonth.weekday; // 1 = Mon
    final daysInMonth = lastOfMonth.day;
    final prevMonthDays = firstWeekday - 1;
    final prevMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    final prevMonthLength = DateTime(_displayMonth.year, _displayMonth.month, 0).day;
    const rows = 6;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.neutral200,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
        title: const Text(
          'Период',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _QuickButton(
                    label: 'Текущий месяц',
                    onTap: () {
                      final s = DateTime(now.year, now.month);
                      final e = DateTime(now.year, now.month + 1, 0);
                      _applyQuick(s, e);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickButton(
                    label: 'Прошлый месяц',
                    onTap: () {
                      final s = DateTime(now.year, now.month - 1);
                      final e = DateTime(now.year, now.month, 0);
                      _applyQuick(s, e);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickButton(
                    label: 'Текущая неделя',
                    onTap: () {
                      final wd = now.weekday;
                      final mon = now.subtract(Duration(days: wd - 1));
                      final sun = mon.add(const Duration(days: 6));
                      _applyQuick(mon, sun);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickButton(
                    label: 'Прошлая неделя',
                    onTap: () {
                      final wd = now.weekday;
                      final mon = now.subtract(Duration(days: wd - 1 + 7));
                      final sun = mon.add(const Duration(days: 6));
                      _applyQuick(mon, sun);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(12),
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
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_monthNamesRu[_displayMonth.month - 1]} ${_displayMonth.year}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _prevMonth,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: _weekdays
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(rows, (row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: List.generate(7, (col) {
                            final cellIndex = row * 7 + col;
                            if (cellIndex < prevMonthDays) {
                              final day = prevMonthLength - prevMonthDays + cellIndex + 1;
                              final date = DateTime(prevMonth.year, prevMonth.month, day);
                              return Expanded(
                                  child: _DayCell(
                                date: date,
                                isOtherMonth: true,
                                isInRange: _isInRange(date),
                                isStart: _isSameDay(date, _rangeStart),
                                isEnd: _isSameDay(date, _rangeEnd),
                                onTap: () => _onDateTap(date),
                              ));
                            }
                            if (cellIndex < prevMonthDays + daysInMonth) {
                              final day = cellIndex - prevMonthDays + 1;
                              final date = DateTime(firstOfMonth.year, firstOfMonth.month, day);
                              return Expanded(
                                  child: _DayCell(
                                date: date,
                                isOtherMonth: false,
                                isInRange: _isInRange(date),
                                isStart: _isSameDay(date, _rangeStart),
                                isEnd: _isSameDay(date, _rangeEnd),
                                onTap: () => _onDateTap(date),
                              ));
                            }
                            final nextMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
                            final day = cellIndex - prevMonthDays - daysInMonth + 1;
                            final date = DateTime(nextMonth.year, nextMonth.month, day);
                            return Expanded(
                                child: _DayCell(
                              date: date,
                              isOtherMonth: true,
                              isInRange: _isInRange(date),
                              isStart: _isSameDay(date, _rangeStart),
                              isEnd: _isSameDay(date, _rangeEnd),
                              onTap: () => _onDateTap(date),
                            ));
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.calendar_today, size: 20),
                  label: const Text('Применить'),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime d) {
    final t = DateTime(d.year, d.month, d.day);
    final s = DateTime(_rangeStart.year, _rangeStart.month, _rangeStart.day);
    final e = DateTime(_rangeEnd.year, _rangeEnd.month, _rangeEnd.day);
    return (t.isAfter(s) && t.isBefore(e)) || t == s || t == e;
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isOtherMonth;
  final bool isInRange;
  final bool isStart;
  final bool isEnd;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isOtherMonth,
    required this.isInRange,
    required this.isStart,
    required this.isEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    if (isStart || isEnd) {
      bg = AppColors.primary500.withValues(alpha: 0.2);
    } else if (isInRange) {
      bg = AppColors.primary100;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: isStart || isEnd
                  ? Border.all(color: AppColors.primary500, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: (isStart || isEnd) ? FontWeight.bold : FontWeight.w500,
                  color: isOtherMonth
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
