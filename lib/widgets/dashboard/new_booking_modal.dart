import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/service_item.dart';
import '../../models/staff_member.dart';
import '../../services/dashboard_api_service.dart';

/// Модалка добавления новой резервации (2 шага, как на скриншоте).
class NewBookingModal extends StatefulWidget {
  const NewBookingModal({
    super.key,
    required this.salonId,
    required this.services,
    required this.staffMembers,
    required this.accessToken,
    required this.onSaved,
    this.getAccessToken,
  });

  final String salonId;
  final List<ServiceItem> services;
  final List<StaffMember> staffMembers;
  final String accessToken;
  final VoidCallback onSaved;
  /// Если задан, перед отправкой вызывается для получения свежего токена (обход истёкшего).
  final Future<String?> Function()? getAccessToken;

  static Future<void> show(
    BuildContext context, {
    required String salonId,
    required List<ServiceItem> services,
    required List<StaffMember> staffMembers,
    required String accessToken,
    required VoidCallback onSaved,
    Future<String?> Function()? getAccessToken,
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
        ),
      ),
    );
  }

  @override
  State<NewBookingModal> createState() => _NewBookingModalState();
}

class _NewBookingModalState extends State<NewBookingModal> {
  int _step = 1;
  final _serviceSearchController = TextEditingController();
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

  static const _monthNamesShort = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
  ];
  static const _weekDaysShort = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatPrice(double? price) {
    if (price == null) return '—';
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(0)}M ₫';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K ₫';
    return '₫${price.toStringAsFixed(0)}';
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
      await DashboardApiService.createBooking(
        token,
        salonId: widget.salonId,
        serviceId: _selectedService!.id,
        timeIso: dateTime.toUtc().toIso8601String(),
        staffId: _selectedStaff?.id,
        clientName: name.isEmpty ? null : name,
        clientPhone: phone.isEmpty ? null : phone,
        clientEmail: email.isEmpty ? null : email,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Резервация создана'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
            if (_step == 1) _buildNextButton() else _buildStep2Buttons(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary500,
                child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Container(width: 24, height: 2, color: _step >= 2 ? AppColors.primary500 : AppColors.borderPrimary),
              CircleAvatar(
                radius: 14,
                backgroundColor: _step >= 2 ? AppColors.primary500 : AppColors.borderPrimary,
                child: Text('2', style: TextStyle(color: _step >= 2 ? Colors.white : AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            _serviceSearchController.clear();
            showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Выберите услугу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _serviceSearchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск по названию услуги',
                          prefixIcon: const Icon(Icons.search, size: 22, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _serviceSearchController,
                        builder: (_, value, __) {
                          final list = value.text.trim().isEmpty
                              ? widget.services
                              : widget.services
                                  .where((s) => s.displayName.toLowerCase().contains(value.text.trim().toLowerCase()))
                                  .toList();
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final s = list[i];
                              return ListTile(
                                title: Text(s.displayName),
                                subtitle: Text('${s.duration ?? 0} мин · ${_formatPrice(s.price)}'),
                                onTap: () {
                                  setState(() => _selectedService = s);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'Услуга',
              prefixIcon: const Icon(Icons.search, size: 22, color: AppColors.textSecondary),
              suffixIcon: _selectedService != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _selectedService = null),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderPrimary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text(
              _selectedService?.displayName ?? '',
              style: TextStyle(fontSize: 14, color: _selectedService != null ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ),
        if (_selectedService != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('${_selectedService!.duration ?? 0} мин', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Text(_formatPrice(_selectedService!.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary500)),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
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
        const Text('Выберите время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _timeSegmentChip(0, 'Утро')),
            const SizedBox(width: 4),
            Expanded(child: _timeSegmentChip(1, 'День')),
            const SizedBox(width: 4),
            Expanded(child: _timeSegmentChip(2, 'Вечер')),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
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
        const Text('Выберите мастера', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        InkWell(
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
                  ...widget.staffMembers.map((s) => _staffPickerTile(ctx, s, s.name)),
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
    return Column(
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
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _goNext,
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
                  : const Text('Записаться'),
            ),
          ),
        ],
      ),
    );
  }
}
