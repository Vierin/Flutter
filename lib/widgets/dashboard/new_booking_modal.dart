import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../l10n/locale_provider.dart';
import '../../models/booking.dart';
import '../../utils/currency_format.dart';
import '../../models/service_item.dart';
import '../../models/staff_member.dart';
import '../../services/cache/bookings_cache.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/dashboard_api_service.dart';
import '../../services/services_api_service.dart';
import '../../services/staff_api_service.dart';
import '../../utils/show_api_error.dart';

/// Модалка добавления или редактирования резервации (2 шага).
/// Может открываться с предзагруженными данными или загружать их сама (быстрое открытие).
class NewBookingModal extends StatefulWidget {
  const NewBookingModal({
    super.key,
    this.salonId,
    this.services,
    this.staffMembers,
    required this.accessToken,
    required this.onSaved,
    this.getAccessToken,
    this.existingBooking,
  });

  final String? salonId;
  final List<ServiceItem>? services;
  final List<StaffMember>? staffMembers;
  final String accessToken;
  final VoidCallback onSaved;
  final Future<String?> Function()? getAccessToken;
  final Booking? existingBooking;

  bool get isEditMode => existingBooking != null;

  /// Открыть модалку сразу; данные подгрузятся внутри (быстрое открытие).
  static Future<void> show(
    BuildContext context, {
    required String accessToken,
    required VoidCallback onSaved,
    Future<String?> Function()? getAccessToken,
    Booking? existingBooking,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => NewBookingModal(
          accessToken: accessToken,
          onSaved: onSaved,
          getAccessToken: getAccessToken,
          existingBooking: existingBooking,
        ),
      ),
    );
  }

  /// Открыть с уже загруженными данными (например, для редактирования).
  static Future<void> showWithData(
    BuildContext context, {
    required String salonId,
    required List<ServiceItem> services,
    required List<StaffMember> staffMembers,
    required String accessToken,
    required VoidCallback onSaved,
    Future<String?> Function()? getAccessToken,
    Booking? existingBooking,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => NewBookingModal(
          salonId: salonId,
          services: services,
          staffMembers: staffMembers,
          accessToken: accessToken,
          onSaved: onSaved,
          getAccessToken: getAccessToken,
          existingBooking: existingBooking,
        ),
      ),
    );
  }

  @override
  State<NewBookingModal> createState() => _NewBookingModalState();
}

class _NewBookingModalState extends State<NewBookingModal> {
  int _step = 1;
  ServiceItem? _selectedService;
  StaffMember? _selectedStaff;
  DateTime _selectedDate = DateTime.now();
  int _timeSegment = 0; // 0 Утро, 1 День, 2 Вечер
  int _selectedHour = 8;
  int _selectedMinute = 0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  bool _loading = false;
  String? _loadError;
  String? _salonId;
  List<ServiceItem>? _services;
  List<StaffMember>? _staffMembers;

  static const _monthNamesShort = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
  ];
  static const _weekDaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  List<ServiceItem> get _effectiveServices => _services ?? widget.services ?? [];
  List<StaffMember> get _effectiveStaff => _staffMembers ?? widget.staffMembers ?? [];
  String? get _effectiveSalonId => _salonId ?? widget.salonId;

  @override
  void initState() {
    super.initState();
    if (widget.salonId != null && widget.services != null && widget.staffMembers != null) {
      _salonId = widget.salonId;
      _services = widget.services;
      _staffMembers = widget.staffMembers;
      _applyExistingBooking();
      return;
    }
    _loading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    String? token = widget.accessToken.isEmpty && widget.getAccessToken != null
        ? await widget.getAccessToken!()
        : widget.accessToken;
    if (token == null || token.isEmpty || !mounted) {
      if (mounted) setState(() { _loading = false; _loadError = 'Нет доступа'; });
      return;
    }
    try {
      String? sid = widget.salonId;
      if (sid == null) {
        final salon = await context.read<SalonCache>().getSalon(token);
        if (!mounted) return;
        sid = salon?.id;
        if (sid == null) {
          setState(() { _loading = false; _loadError = 'Салон не найден'; });
          return;
        }
      }
      final futures = <Future>[];
      List<ServiceItem>? services = widget.services;
      List<StaffMember>? staffMembers = widget.staffMembers;
      if (services == null) futures.add(ServicesApiService.getBySalon(token, sid).then((v) => services = v));
      if (staffMembers == null) futures.add(StaffApiService.getBySalon(token, sid).then((v) => staffMembers = v));
      await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _salonId = sid;
        _services = services ?? [];
        _staffMembers = staffMembers ?? [];
        _loading = false;
        _loadError = null;
      });
      _applyExistingBooking();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = 'Ошибка загрузки: $e'; });
    }
  }

  void _applyExistingBooking() {
    final existing = widget.existingBooking;
    if (existing == null) {
      _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      return;
    }
    _selectedDate = DateTime(existing.dateTime.year, existing.dateTime.month, existing.dateTime.day);
    _selectedHour = existing.dateTime.hour;
    _selectedMinute = existing.dateTime.minute;
    final svc = _effectiveServices;
    final staff = _effectiveStaff;
    if (existing.serviceId != null) {
      final match = svc.where((s) => s.id == existing.serviceId).toList();
      if (match.isNotEmpty) _selectedService = match.first;
    }
    if (_selectedService == null && existing.service != null) {
      final byName = svc.where((s) => s.name == existing.service!.name).toList();
      if (byName.isNotEmpty) _selectedService = byName.first;
    }
    if (existing.effectiveStaffId != null) {
      final sm = staff.where((s) => s.id == existing.effectiveStaffId).toList();
      if (sm.isNotEmpty) _selectedStaff = sm.first;
    }
    if (existing.user != null) {
      _nameController.text = existing.user!.name ?? '';
      _emailController.text = existing.user!.email ?? '';
      _phoneController.text = existing.user!.phone ?? '';
    }
    _notesController.text = existing.notes ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _dayLabel(DateTime d) {
    final w = _weekDaysShort[d.weekday % 7];
    return '$w ${d.day} ${_monthNamesShort[d.month - 1]}';
  }

  List<({int h, int m})> get _timeSlots {
    int startH, endH;
    switch (_timeSegment) {
      case 0:
        startH = 7;
        endH = 12;
        break;
      case 1:
        startH = 12;
        endH = 17;
        break;
      default:
        startH = 17;
        endH = 21;
    }
    final list = <({int h, int m})>[];
    for (var h = startH; h < endH; h++) {
      list.add((h: h, m: 0));
      list.add((h: h, m: 15));
      list.add((h: h, m: 30));
      list.add((h: h, m: 45));
    }
    return list;
  }

  void _goNext() {
    if (_selectedService == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Выберите услугу'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    setState(() => _isSubmitting = true);
    try {
      final token = widget.getAccessToken != null
          ? await widget.getAccessToken!()
          : widget.accessToken;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Сессия истекла. Войдите снова'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );
      final timeIso = dateTime.toUtc().toIso8601String();
      if (widget.existingBooking != null) {
        await DashboardApiService.updateBooking(
          token,
          widget.existingBooking!.id,
          serviceId: _selectedService!.id,
          staffId: _selectedStaff?.id,
          timeIso: timeIso,
          notes: notes,
        );
      } else {
        await DashboardApiService.createBooking(
          token,
          salonId: _effectiveSalonId!,
          serviceId: _selectedService!.id,
          timeIso: timeIso,
          staffId: _selectedStaff?.id,
          clientName: name.isEmpty ? null : name,
          clientPhone: phone.isEmpty ? null : phone,
          clientEmail: email.isEmpty ? null : email,
          notes: notes,
        );
      }
      if (!mounted) return;
      context.read<BookingsCache>().invalidate();
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(widget.isEditMode ? 'Запись изменена' : 'Резервация создана'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: _loadError != null
                  ? _buildLoadError()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      child: _step == 1
                          ? (_loading ? _buildStep1WithSkeleton() : _buildStep1())
                          : _buildStep2(),
                    ),
            ),
            if (_loadError == null) ...[
              if (_step == 1) _buildNextButton() else _buildStep2Buttons(),
            ],
          ],
        ),
      ),
    );
  }

  /// Шаг 1 при загрузке: статичные элементы как есть, скелетон только для полос дат и слотов времени.
  Widget _buildStep1WithSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ServiceSearchField(
            services: const [],
            selected: null,
            onSelected: (_) {},
            hintText: 'Выберите услугу',
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: List.generate(7, (_) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 72,
                decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _timeSegmentChip(0, 'Утро')),
              const SizedBox(width: 4),
              Expanded(child: _timeSegmentChip(1, 'День')),
              const SizedBox(width: 4),
              Expanded(child: _timeSegmentChip(2, 'Вечер')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: List.generate(8, (_) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 52,
                decoration: BoxDecoration(color: AppColors.backgroundSecondary, borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите мастера', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderPrimary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Любой мастер',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () { setState(() { _loading = true; _loadError = null; }); _loadInitialData(); }, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            widget.isEditMode ? 'Изменить запись' : 'Новая запись',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final services = _effectiveServices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ServiceSearchField(
            services: services,
            selected: _selectedService,
            onSelected: (s) => setState(() => _selectedService = s),
            hintText: 'Выберите услугу',
          ),
        ),
        if (_selectedService != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('${_selectedService!.duration ?? 0} мин', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                Text(formatVnd(_selectedService!.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary500)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: List.generate(14, (i) {
              final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
              final d = today.add(Duration(days: i));
              final isSelected = _selectedDate.year == d.year && _selectedDate.month == d.month && _selectedDate.day == d.day;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? AppColors.primary500 : AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDate = d),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppColors.primary500 : AppColors.borderPrimary),
                      ),
                      alignment: Alignment.center,
                      child: Text(_dayLabel(d), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _timeSegmentChip(0, 'Утро')),
              const SizedBox(width: 4),
              Expanded(child: _timeSegmentChip(1, 'День')),
              const SizedBox(width: 4),
              Expanded(child: _timeSegmentChip(2, 'Вечер')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: _timeSlots.map((slot) {
              final isSelected = _selectedHour == slot.h && _selectedMinute == slot.m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected ? AppColors.primary500 : AppColors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedHour = slot.h;
                      _selectedMinute = slot.m;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? AppColors.primary500 : AppColors.borderPrimary),
                      ),
                      alignment: Alignment.center,
                      child: Text('${slot.h.toString().padLeft(2, '0')}:${slot.m.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppColors.textPrimary)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Выберите мастера', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InkWell(
            onTap: () => _showStaffPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderPrimary),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedStaff == null ? 'Любой мастер' : _selectedStaff!.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedStaff == null ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 24),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showStaffPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _staffPickerTile(ctx, null, 'Любой мастер'),
                  ..._effectiveStaff.map((s) => _staffPickerTile(ctx, s, s.name)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staffPickerTile(BuildContext context, StaffMember? staff, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedStaff = staff);
          Navigator.pop(context);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeSegmentChip(int index, String label) {
    final selected = _timeSegment == index;
    return Material(
      color: selected ? AppColors.backgroundPrimary : AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _timeSegment = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primary500 : AppColors.borderPrimary),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
        ),
      ),
    );
  }

  String _formatBookingDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _formatBookingTime() => '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          'Сводка бронирования',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
            children: [
              TextSpan(text: 'Услуга', style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ':: '),
              TextSpan(text: _selectedService?.displayName ?? '—'),
              const TextSpan(text: '\n'),
              TextSpan(text: 'Дата', style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ':: '),
              TextSpan(text: _formatBookingDate(_selectedDate)),
              const TextSpan(text: '\n'),
              TextSpan(text: 'Время', style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ':: '),
              TextSpan(text: _formatBookingTime()),
              const TextSpan(text: '\n'),
              TextSpan(text: 'Мастер', style: TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ': '),
              TextSpan(text: _selectedStaff?.name ?? 'Любой мастер'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Информация о клиенте',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Text(
          'Email клиента (Необязательно)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'client@example.com',
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderPrimary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Напоминания не будут отправлены без указания email адреса.',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Имя клиента (Необязательно)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Имя клиента',
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderPrimary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        Text(
          'Телефон клиента (Необязательно)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+7...',
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderPrimary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _loading ? null : _goNext,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary500,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Далее'),
        ),
      ),
    );
  }

  Widget _buildStep2Buttons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.borderPrimary),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Назад'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isEditMode ? context.read<LocaleProvider>().t('common.save') : context.read<LocaleProvider>().t('booking.book')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле выбора услуги: по клику открывается список, поиск в том же месте что и «Выберите услугу».
class _ServiceSearchField extends StatefulWidget {
  const _ServiceSearchField({
    required this.services,
    required this.selected,
    required this.onSelected,
    required this.hintText,
  });

  final List<ServiceItem> services;
  final ServiceItem? selected;
  final ValueChanged<ServiceItem?> onSelected;
  final String hintText;

  @override
  State<_ServiceSearchField> createState() => _ServiceSearchFieldState();
}

class _ServiceSearchFieldState extends State<_ServiceSearchField> {
  bool _open = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && mounted) _closeOverlay();
    });
  }

  @override
  void dispose() {
    _closeOverlay();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<ServiceItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.services;
    return widget.services.where((s) => s.displayName.toLowerCase().contains(q)).toList();
  }

  void _showOverlay() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final overlay = Overlay.of(context);
    final fieldOffset = box.localToGlobal(Offset.zero);
    final fieldSize = box.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final list = _filtered;
        return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            left: fieldOffset.dx,
            top: fieldOffset.dy + fieldSize.height + 4,
            width: fieldSize.width,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppColors.backgroundPrimary,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final s = list[i];
                    return InkWell(
                      onTap: () {
                        widget.onSelected(s);
                        _searchController.clear();
                        _closeOverlay();
                        _searchFocus.unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${s.duration ?? 0} мин · ${formatVnd(s.price)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: _fieldKey,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: _open
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  onChanged: (_) {
                    setState(() {});
                    _overlayEntry?.markNeedsBuild();
                  },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search, size: 22, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                )
              : InkWell(
                  onTap: () {
                    setState(() => _open = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 22, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.selected?.displayName ?? widget.hintText,
                            style: TextStyle(fontSize: 14, color: widget.selected != null ? AppColors.textPrimary : AppColors.textSecondary),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
