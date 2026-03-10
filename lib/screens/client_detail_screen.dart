import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../utils/currency_format.dart';
import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/dashboard/booking_detail_modal.dart';
import '../../widgets/dashboard/new_booking_modal.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientKey;
  final String name;
  final String? email;
  final String? phone;

  const ClientDetailScreen({
    super.key,
    required this.clientKey,
    required this.name,
    this.email,
    this.phone,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final all = await DashboardApiService.getOwnerBookings(token);
      final list = all
          .where((b) =>
              (b.user?.email ?? b.user?.phone ?? b.user?.name ?? '').trim() ==
              widget.clientKey)
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (mounted) {
        setState(() {
          _bookings = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? get _firstVisit =>
      _bookings.isEmpty ? null : _bookings.map((b) => b.dateTime).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get _lastVisit =>
      _bookings.isEmpty ? null : _bookings.map((b) => b.dateTime).reduce((a, b) => a.isAfter(b) ? a : b);
  double get _income => _bookings
      .where((b) => b.status != BookingStatus.canceled)
      .fold(0.0, (s, b) => s + (b.service?.price ?? 0));
  int get _rejectedVisits =>
      _bookings.where((b) => b.status == BookingStatus.canceled || b.status == BookingStatus.noShow).length;
  int get _totalVisits => _bookings.length;

  Future<void> _handleEditBooking(Booking booking) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    await NewBookingModal.show(
      context,
      accessToken: token,
      onSaved: _loadData,
      getAccessToken: () async {
        await context.read<AuthService>().refreshSession();
        return context.read<AuthService>().accessToken;
      },
      existingBooking: booking,
    );
  }

  Future<void> _handleCancelBooking(String id) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    await DashboardApiService.cancelBooking(token, id);
    if (mounted) {
      _loadData();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Запись отменена'), backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _handleConfirmBooking(String id) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    await DashboardApiService.confirmBooking(token, id);
    if (mounted) {
      _loadData();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Подтверждено'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _handleRejectBooking(String id) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    await DashboardApiService.rejectBooking(token, id);
    if (mounted) {
      _loadData();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Отклонено'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Редактирование клиента — в разработке')),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary500))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary500,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_firstVisit != null) ...[
                      const Text(
                        'Дата первого визита',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd.MM.yyyy').format(_firstVisit!),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _MiniCard(
                            title: 'Последний визит',
                            value: _lastVisit != null
                                ? DateFormat('dd.MM.yy').format(_lastVisit!)
                                : '—',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniCard(
                            title: 'Income from client',
                            value: formatVnd(_income),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniCard(
                            title: 'Rejected Visits',
                            value: '$_rejectedVisits',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniCard(
                            title: 'Total visits',
                            value: '$_totalVisits',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.phone != null && widget.phone!.isNotEmpty)
                          IconButton(
                            onPressed: () => _showPhone(context, widget.phone!),
                            icon: const Icon(Icons.phone_outlined, size: 28),
                            color: AppColors.primary500,
                            tooltip: widget.phone,
                          ),
                        if (widget.email != null && widget.email!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showEmail(context, widget.email!),
                            icon: const Icon(Icons.email_outlined, size: 28),
                            color: AppColors.primary500,
                            tooltip: widget.email,
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() => _blocked = !_blocked);
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(_blocked ? 'Клиент заблокирован' : 'Клиент разблокирован'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: Icon(
                            _blocked ? Icons.block : Icons.block_outlined,
                            size: 28,
                            color: _blocked ? AppColors.error500 : AppColors.textSecondary,
                          ),
                          tooltip: 'Заблокировать клиента',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Резервации',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_bookings.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Нет записей',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._bookings.map((b) => _BookingCard(
                            booking: b,
                            onTap: () => BookingDetailModal.show(
                              context,
                              booking: b,
                              onEdit: _handleEditBooking,
                              onCancel: _handleCancelBooking,
                              onConfirm: _handleConfirmBooking,
                              onReject: _handleRejectBooking,
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  void _showPhone(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Телефон', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SelectableText(phone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showEmail(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Email', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            SelectableText(email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;

  const _MiniCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = booking.service?.price;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd.MM.yyyy, HH:mm').format(booking.dateTime),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.service?.name ?? '—',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                price != null ? formatVnd(price) : '—',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
