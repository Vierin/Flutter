import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../models/salon.dart';
import '../../models/staff_member.dart';
import '../../models/time_block.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import '../../services/staff_api_service.dart';
import '../../models/service_item.dart';
import '../../services/services_api_service.dart';
import '../../widgets/dashboard/booking_detail_modal.dart';
import '../../widgets/dashboard/new_booking_modal.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Salon? _salon;
  List<Booking> _bookings = [];
  List<StaffMember> _staffMembers = [];
  List<TimeBlock> _timeBlocks = [];
  bool _isLoading = false;

  DateTime _selectedDate = DateTime.now();
  String? _selectedStaffId;
  bool _expandedView = false;
  late PageController _dayStripPageController;

  static const _monthNamesFull = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  static const _weekDaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
  static const _dayStripTotalWeeks = 208;

  @override
  void initState() {
    super.initState();
    _dayStripPageController = PageController(
      initialPage: _weekIndexForDate(_selectedDate),
      viewportFraction: 0.92,
    );
    _loadData();
  }

  @override
  void dispose() {
    _dayStripPageController.dispose();
    super.dispose();
  }

  static DateTime _mondayOfWeek(DateTime d) {
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static final _epochMonday = DateTime(2024, 1, 1);

  int _weekIndexForDate(DateTime d) {
    final monday = _mondayOfWeek(d);
    return monday.difference(_mondayOfWeek(_epochMonday)).inDays ~/ 7;
  }

  DateTime _dateForWeekIndex(int index) {
    return _epochMonday.add(Duration(days: index * 7));
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final salon = await DashboardApiService.getCurrentSalon(token);
      List<Booking> bookings = [];
      List<StaffMember> staff = [];
      List<TimeBlock> timeBlocks = [];
      if (salon != null) {
        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 30));
        final end = now.add(const Duration(days: 60));
        bookings = await DashboardApiService.getOwnerBookings(token);
        staff = await StaffApiService.getBySalon(token, salon.id);
        timeBlocks = await DashboardApiService.getTimeBlocks(
          token,
          startDate: start.toIso8601String(),
          endDate: end.toIso8601String(),
        );
      }
      if (mounted) {
        setState(() {
          _salon = salon;
          _bookings = bookings;
          _staffMembers = staff;
          _timeBlocks = timeBlocks;
          _isLoading = false;
          if (_selectedStaffId == null && staff.isNotEmpty) {
            _selectedStaffId = staff.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Booking> _bookingsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _bookings
        .where((b) => !b.dateTime.isBefore(start) && b.dateTime.isBefore(end))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<Booking> _bookingsForDateAndStaff(DateTime date, String? staffId) {
    var list = _bookingsForDate(date);
    if (staffId != null && staffId.isNotEmpty) {
      list = list.where((b) => b.effectiveStaffId == staffId).toList();
    }
    return list;
  }

  Booking? _bookingAtHour(List<Booking> dayBookings, int hour) {
    for (final b in dayBookings) {
      if (b.dateTime.hour == hour) return b;
    }
    return null;
  }

  /// День недели для workingHours: monday..sunday (DateTime.weekday 1=Mon, 7=Sun).
  static const _dayKeys = [
    '',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  String _dayKey(DateTime d) => _dayKeys[d.weekday];

  /// Рабочие часы выбранного дня: openHour, closeHour. null если день закрыт или нет данных.
  ({int openHour, int closeHour})? _getSelectedDayWorkingHours() {
    final wh = _salon?.workingHours;
    if (wh == null) return null;
    final dayHours = wh[_dayKey(_selectedDate)];
    if (dayHours == null || dayHours is! Map) return null;
    final dayMap = dayHours as Map<String, dynamic>;
    final closed = dayMap['closed'] == true;
    if (closed) return null;
    final open = dayMap['open']?.toString();
    final close = dayMap['close']?.toString();
    if (open == null || close == null || open.isEmpty || close.isEmpty)
      return null;
    final openParts = open.split(':');
    final closeParts = close.split(':');
    final openHour = int.tryParse(openParts.first) ?? 9;
    final closeHour = int.tryParse(closeParts.first) ?? 18;
    return (openHour: openHour, closeHour: closeHour);
  }

  /// Глобальный диапазон часов по всем дням (для отображения сетки). По умолчанию 6–23.
  ({int startHour, int endHour}) _getGlobalTimeRange() {
    final wh = _salon?.workingHours;
    if (wh == null) return (startHour: 6, endHour: 23);
    int minStart = 23;
    int maxEnd = 0;
    for (final dayKey in _dayKeys) {
      if (dayKey.isEmpty) continue;
      final dayHours = wh[dayKey];
      if (dayHours == null || dayHours is! Map) continue;
      final dayMap = dayHours as Map<String, dynamic>;
      if (dayMap['closed'] == true) continue;
      final open = dayMap['open']?.toString();
      final close = dayMap['close']?.toString();
      if (open == null || close == null) continue;
      final openHour = int.tryParse(open.split(':').first) ?? 9;
      final closeHour = int.tryParse(close.split(':').first) ?? 18;
      if (openHour < minStart) minStart = openHour;
      if (closeHour > maxEnd) maxEnd = closeHour;
    }
    if (minStart == 23 || maxEnd == 0) return (startHour: 6, endHour: 23);
    return (startHour: minStart, endHour: maxEnd);
  }

  bool _isTimeSlotOutsideWorkingHours(int hour) {
    final dayHours = _getSelectedDayWorkingHours();
    if (dayHours == null) return false;
    return hour < dayHours.openHour || hour >= dayHours.closeHour;
  }

  List<TimeBlock> _getTimeBlocksForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _timeBlocks.where((b) {
      final bStart = DateTime(
        b.startDate.year,
        b.startDate.month,
        b.startDate.day,
      );
      final bEnd = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      return !dayStart.isAfter(bEnd) && !dayEnd.isBefore(bStart);
    }).toList();
  }

  TimeBlock? _getTimeBlockAtTime(String? staffId, int hour) {
    final dayBlocks = _getTimeBlocksForDate(_selectedDate);
    final slotStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
    );
    final slotEnd = slotStart.add(const Duration(hours: 1));
    for (final block in dayBlocks) {
      if (staffId != null && block.staffId != null && block.staffId != staffId)
        continue;
      if (slotStart.isBefore(block.endDate) && slotEnd.isAfter(block.startDate))
        return block;
    }
    return null;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _headerPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primary500 : AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary500 : AppColors.borderPrimary,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.textInverse : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    try {
      final ok = await DashboardApiService.confirmBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Бронирование подтверждено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRejectBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    try {
      final ok = await DashboardApiService.rejectBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Бронирование отклонено'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCancelBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    try {
      final ok = await DashboardApiService.cancelBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Запись отменена'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleEditBooking(Booking booking) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || _salon == null) return;
    try {
      final services = await ServicesApiService.getBySalon(token, _salon!.id);
      if (!mounted) return;
      if (services.isEmpty || _staffMembers.isEmpty) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Нужны услуги и сотрудники для редактирования'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await NewBookingModal.show(
        context,
        salonId: _salon!.id,
        services: services,
        staffMembers: _staffMembers,
        accessToken: token,
        onSaved: _loadData,
        getAccessToken: () async {
          await context.read<AuthService>().refreshSession();
          return context.read<AuthService>().accessToken;
        },
        existingBooking: booking,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onNewAppointment() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || _salon == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Нет доступа'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_staffMembers.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Добавьте сотрудников'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    List<ServiceItem> services = [];
    try {
      services = await ServicesApiService.getBySalon(token, _salon!.id);
    } catch (_) {}
    if (!mounted) return;
    if (services.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Добавьте услуги в салон'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await NewBookingModal.show(
      context,
      salonId: _salon!.id,
      services: services,
      staffMembers: _staffMembers,
      accessToken: token,
      onSaved: _loadData,
      getAccessToken: () async {
        await context.read<AuthService>().refreshSession();
        return context.read<AuthService>().accessToken;
      },
    );
  }

  void _showCalendarActionsModal() {
    final staffName = _selectedStaffId != null
        ? (_staffMembers
                  .where((s) => s.id == _selectedStaffId)
                  .firstOrNull
                  ?.name ??
              'сотрудника')
        : 'сотрудника';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _calendarActionOption(
                  label: 'Изменить расписание',
                  icon: Icons.calendar_month_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Редактирование расписания в разработке'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _calendarActionOption(
                  label: 'Добавить нерабочие часы для $staffName',
                  icon: Icons.schedule_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Нерабочие часы для $staffName в разработке',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _calendarActionOption(
                  label: 'Сделать весь день нерабочим',
                  icon: Icons.event_busy_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Блокировка дня в разработке'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _calendarActionOption(
                  label: 'Новая запись',
                  icon: Icons.add_circle_outline,
                  onTap: () {
                    Navigator.pop(context);
                    _onNewAppointment();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarActionOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.primary100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(icon, size: 22, color: AppColors.primary500),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_salon == null && !_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Сначала настройте салон',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    final monthYear =
        '${_monthNamesFull[_selectedDate.month - 1]} ${_selectedDate.year}';
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary500,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Month/Year + Today, Expand
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              monthYear,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _headerPill(
                                  label: 'Сегодня',
                                  selected: _isToday(_selectedDate),
                                  onTap: () {
                                    setState(
                                      () => _selectedDate = DateTime.now(),
                                    );
                                    final page = _weekIndexForDate(
                                      DateTime.now(),
                                    );
                                    if (page >= 0 &&
                                        page < _dayStripTotalWeeks) {
                                      _dayStripPageController.animateToPage(
                                        page,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                _headerPill(
                                  label: _expandedView
                                      ? 'Свернуть'
                                      : 'Развернуть',
                                  selected: _expandedView,
                                  onTap: () => setState(
                                    () => _expandedView = !_expandedView,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Date strip (7 days) or full month grid
                      _expandedView ? _buildMonthGrid() : _buildDayStrip(),
                      const SizedBox(height: 16),
                      // Filter pills (staff) — без внешнего отступа, паддинг внутри списка
                      _buildStaffPills(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  child: _buildTimeGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCalendarActionsModal,
        backgroundColor: AppColors.primary500,
        child: const Icon(
          CupertinoIcons.calendar_badge_plus,
          color: AppColors.textInverse,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final leadingEmpty = firstWeekday - 1;
    final totalCells = leadingEmpty + lastDay;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day headers: Пн, Вт, Ср, Чт, Пт, Сб, Вс
        Row(
          children: List.generate(7, (i) {
            final idx = (i + 1) % 7;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text(
                  _weekDaysShort[idx],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
        // Grid of days
        ...List.generate(rows, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                if (cellIndex < leadingEmpty) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                final dayNum = cellIndex - leadingEmpty + 1;
                if (dayNum > lastDay) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                final d = DateTime(year, month, dayNum);
                final isSelected =
                    _selectedDate.year == d.year &&
                    _selectedDate.month == d.month &&
                    _selectedDate.day == d.day;
                final count = _bookingsForDateAndStaff(
                  d,
                  _selectedStaffId,
                ).length;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _dayPill(
                      d.day,
                      count,
                      isSelected,
                      () => setState(() => _selectedDate = d),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _dayPill(int dayNum, int count, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary100
              : AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary500 : AppColors.borderPrimary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primary500
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? AppColors.primary500
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayStrip() {
    return SizedBox(
      height: 84,
      child: PageView.builder(
        controller: _dayStripPageController,
        itemCount: _dayStripTotalWeeks,
        padEnds: true,
        physics: const PageScrollPhysics(),
        // Не меняем активную дату при прокрутке — только по клику на ячейку
        itemBuilder: (context, index) {
          final monday = _dateForWeekIndex(index);
          final days = List<DateTime>.generate(
            7,
            (i) => monday.add(Duration(days: i)),
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isSelected =
                  _selectedDate.year == d.year &&
                  _selectedDate.month == d.month &&
                  _selectedDate.day == d.day;
              final count = _bookingsForDateAndStaff(
                d,
                _selectedStaffId,
              ).length;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: isSelected
                        ? AppColors.primary100
                        : AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDate = d),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary500
                                : AppColors.borderPrimary,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekDaysShort[d.weekday % 7],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary500
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.primary500
                                    : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? AppColors.primary500
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildStaffPills() {
    final staffList = _staffMembers;
    if (staffList.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: staffList
            .map(
              (s) => InkWell(
                onTap: () => setState(() => _selectedStaffId = s.id),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _staffPill(s.name, _selectedStaffId == s.id),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _staffPill(String label, bool selected) {
    return Material(
      color: selected ? AppColors.primary100 : AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary500 : AppColors.borderPrimary,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary500 : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeGrid() {
    final range = _getGlobalTimeRange();
    final startHour = range.startHour;
    final endHour = range.endHour;
    const rowHeight = 72.0;
    final dayBookings = _bookingsForDateAndStaff(
      _selectedDate,
      _selectedStaffId,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(endHour - startHour + 1, (i) {
            final hour = startHour + i;
            final booking = _bookingAtHour(dayBookings, hour);
            final timeBlock = _getTimeBlockAtTime(_selectedStaffId, hour);
            final outsideHours = _isTimeSlotOutsideWorkingHours(hour);
            return SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    height: rowHeight,
                    child: Center(
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.borderPrimary.withValues(
                              alpha: 0.5,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (outsideHours)
                            Positioned.fill(
                              child: Container(
                                color: AppColors.neutral100.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          if (timeBlock != null)
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  top: 4,
                                  bottom: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.borderPrimary,
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: _DiagonalStripesPainter(),
                                  child: Center(
                                    child: Text(
                                      _timeBlockLabel(timeBlock.type),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (booking != null && timeBlock == null)
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: InkWell(
                                  onTap: () => BookingDetailModal.show(
                                    context,
                                    booking: booking,
                                    onEdit: _handleEditBooking,
                                    onCancel: _handleCancelBooking,
                                    onConfirm: _handleConfirmBooking,
                                    onReject: _handleRejectBooking,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            () {
                                              final duration =
                                                  booking.service?.duration ??
                                                  60;
                                              final end = booking.dateTime.add(
                                                Duration(minutes: duration),
                                              );
                                              return '${booking.dateTime.hour.toString().padLeft(2, '0')}:${booking.dateTime.minute.toString().padLeft(2, '0')}-'
                                                  '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
                                            }(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.primary600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            booking.service?.name ??
                                                booking.user?.name ??
                                                booking.user?.email ??
                                                '—',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _timeBlockLabel(TimeBlockType type) {
    switch (type) {
      case TimeBlockType.timeOff:
        return 'Выходной';
      case TimeBlockType.busy:
        return 'Занят';
      case TimeBlockType.closure:
        return 'Закрыто';
    }
  }
}

/// Рисует диагональные полоски для заблокированного времени.
class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 8.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
