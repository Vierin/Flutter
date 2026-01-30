import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

enum CalendarViewMode { list, calendar }

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

  CalendarViewMode _viewMode = CalendarViewMode.calendar;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStaffId;

  String _statusFilter = 'all';
  String _dateFilter = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _monthNamesShort = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
  ];
  static const _weekDaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Booking> get _filteredBookings {
    var list = List<Booking>.from(_bookings);
    if (_statusFilter != 'all') {
      final status = _statusFilter.toUpperCase().replaceAll(' ', '_');
      list = list.where((b) => b.status.toString() == status).toList();
    }
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (_dateFilter == 'today') {
      list = list.where((b) {
        final d = DateTime(b.dateTime.year, b.dateTime.month, b.dateTime.day);
        return d == todayStart;
      }).toList();
    } else if (_dateFilter == 'upcoming') {
      list = list.where((b) => b.dateTime.isAfter(now)).toList();
    } else if (_dateFilter == 'past') {
      list = list.where((b) => b.dateTime.isBefore(now)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) {
        final name = b.user?.name?.toLowerCase() ?? '';
        final phone = b.user?.phone?.toLowerCase() ?? '';
        final email = b.user?.email?.toLowerCase() ?? '';
        return name.contains(q) || phone.contains(q) || email.contains(q);
      }).toList();
    }
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
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
  static const _dayKeys = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
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
    if (open == null || close == null || open.isEmpty || close.isEmpty) return null;
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
      final bStart = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final bEnd = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      return !dayStart.isAfter(bEnd) && !dayEnd.isBefore(bStart);
    }).toList();
  }

  TimeBlock? _getTimeBlockAtTime(String? staffId, int hour) {
    final dayBlocks = _getTimeBlocksForDate(_selectedDate);
    final slotStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    for (final block in dayBlocks) {
      if (staffId != null && block.staffId != null && block.staffId != staffId) continue;
      if (slotStart.isBefore(block.endDate) && slotEnd.isAfter(block.startDate)) return block;
    }
    return null;
  }

  String _dayLabel(DateTime d) {
    final w = _weekDaysShort[d.weekday % 7];
    return '$w ${d.day} ${_monthNamesShort[d.month - 1]}';
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
          const SnackBar(content: Text('Бронирование подтверждено'), backgroundColor: Colors.green),
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
          const SnackBar(content: Text('Бронирование отклонено'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onNewAppointment() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || _salon == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Нет доступа'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_staffMembers.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Добавьте сотрудников'), backgroundColor: Colors.orange),
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
        const SnackBar(content: Text('Добавьте услуги в салон'), backgroundColor: Colors.orange),
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
    );
  }

  void _onBlockTime() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Блокировка времени доступна в веб-версии')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_salon == null && !_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: const Text('Календарь'),
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Сначала настройте салон',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Календарь'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary500,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _viewChip(
                      'Список',
                      Icons.view_list,
                      _viewMode == CalendarViewMode.list,
                      () => setState(() => _viewMode = CalendarViewMode.list),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _viewChip(
                      'Календарь',
                      Icons.calendar_month,
                      _viewMode == CalendarViewMode.calendar,
                      () => setState(() => _viewMode = CalendarViewMode.calendar),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onBlockTime,
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Блок'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderPrimary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _onNewAppointment(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Новая'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_viewMode == CalendarViewMode.list) ...[
                _buildListFilters(),
                const SizedBox(height: 12),
                _buildBookingList(),
              ] else ...[
                _buildDayStrip(),
                const SizedBox(height: 12),
                _buildStaffPills(),
                const SizedBox(height: 12),
                _buildTimeGrid(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    final isCalendar = label == 'Календарь';
    final bgColor = selected
        ? (isCalendar ? AppColors.primary500 : AppColors.primary100)
        : AppColors.backgroundPrimary;
    final fgColor = selected && isCalendar ? Colors.white : AppColors.textPrimary;
    final borderColor = selected
        ? (isCalendar ? AppColors.primary500 : AppColors.primary500)
        : AppColors.borderPrimary;
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListFilters() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderPrimary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск по имени, телефону...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Ожидает')),
                      DropdownMenuItem(value: 'CONFIRMED', child: Text('Подтверждено')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Выполнено')),
                      DropdownMenuItem(value: 'CANCELED', child: Text('Отменено')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _dateFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Все даты')),
                      DropdownMenuItem(value: 'today', child: Text('Сегодня')),
                      DropdownMenuItem(value: 'upcoming', child: Text('Предстоящие')),
                      DropdownMenuItem(value: 'past', child: Text('Прошедшие')),
                    ],
                    onChanged: (v) => setState(() => _dateFilter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }
    final list = _filteredBookings;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Нет записей',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: list.map((booking) => _BookingListTile(
        booking: booking,
        onTap: () => BookingDetailModal.show(
          context,
          booking: booking,
          onConfirm: _handleConfirmBooking,
          onReject: _handleRejectBooking,
        ),
      )).toList(),
    );
  }

  Widget _buildDayStrip() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final days = List<DateTime>.generate(90, (i) => today.add(Duration(days: i)));
    return SizedBox(
      height: 52,
      child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (context, index) {
              final d = days[index];
              final isSelected = _selectedDate.year == d.year &&
                  _selectedDate.month == d.month && _selectedDate.day == d.day;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: isSelected ? AppColors.primary500 : AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDate = d),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary500 : AppColors.borderPrimary,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _dayLabel(d),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildStaffPills() {
    final staffList = _staffMembers;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: staffList
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _staffPill(s.name, _selectedStaffId == s.id, s.id),
                ))
            .toList(),
      ),
    );
  }

  Widget _staffPill(String label, bool selected, String staffId) {
    return Material(
      color: selected ? AppColors.primary500 : AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _selectedStaffId = staffId),
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeGrid() {
    final range = _getGlobalTimeRange();
    final startHour = range.startHour;
    final endHour = range.endHour;
    const rowHeight = 96.0;
    final dayBookings = _bookingsForDateAndStaff(_selectedDate, _selectedStaffId);
    final matched = _selectedStaffId == null
        ? null
        : _staffMembers.where((s) => s.id == _selectedStaffId).toList();
    final selectedStaffName = matched == null || matched.isEmpty ? '—' : matched.first.name;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderPrimary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    child: Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      selectedStaffName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(endHour - startHour + 1, (i) {
              final hour = startHour + i;
              final booking = _bookingAtHour(dayBookings, hour);
              final timeBlock = _getTimeBlockAtTime(_selectedStaffId, hour);
              final outsideHours = _isTimeSlotOutsideWorkingHours(hour);
              final bgColor = i.isEven ? AppColors.backgroundPrimary : AppColors.backgroundTertiary;
              return SizedBox(
                height: rowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 40,
                      color: bgColor,
                      alignment: Alignment.center,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            color: bgColor,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          ),
                          if (outsideHours)
                            Positioned.fill(
                              child: Container(
                                color: Colors.grey.withValues(alpha: 0.35),
                              ),
                            ),
                          if (timeBlock != null)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                  border: Border.all(color: AppColors.borderPrimary),
                                ),
                                child: CustomPaint(
                                  painter: _DiagonalStripesPainter(),
                                  child: Center(
                                    child: Text(
                                      _timeBlockLabel(timeBlock.type),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (booking != null && timeBlock == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: InkWell(
                                onTap: () => BookingDetailModal.show(
                                  context,
                                  booking: booking,
                                  onConfirm: _handleConfirmBooking,
                                  onReject: _handleRejectBooking,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: booking.status == BookingStatus.pending
                                        ? AppColors.warning100
                                        : AppColors.success100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderPrimary),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        booking.user?.name ?? booking.user?.email ?? '—',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (booking.service != null)
                                        Text(
                                          booking.service!.name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BookingListTile extends StatelessWidget {
  const _BookingListTile({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(booking.dateTime);
    final clientName = booking.user?.name ?? booking.user?.email ?? '—';
    final serviceName = booking.service?.name ?? '—';
    final status = booking.status.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderPrimary),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      serviceName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.statusPending;
      case 'CONFIRMED':
        return AppColors.statusConfirmed;
      case 'COMPLETED':
        return AppColors.statusCompleted;
      case 'CANCELED':
        return AppColors.statusCanceled;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Ожидает';
      case 'CONFIRMED':
        return 'Подтверждено';
      case 'COMPLETED':
        return 'Выполнено';
      case 'CANCELED':
        return 'Отменено';
      case 'NO_SHOW':
        return 'Не пришёл';
      default:
        return status;
    }
  }
}
