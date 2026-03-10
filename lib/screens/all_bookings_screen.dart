import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/dashboard/booking_detail_modal.dart';
import '../../widgets/dashboard/new_booking_modal.dart';

enum _BookingFilter { all, new_, pending, completed }

class AllBookingsScreen extends StatefulWidget {
  const AllBookingsScreen({super.key});

  @override
  State<AllBookingsScreen> createState() => _AllBookingsScreenState();
}

class _AllBookingsScreenState extends State<AllBookingsScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;
  _BookingFilter _filter = _BookingFilter.all;

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
      final list = await context.read<BookingsCache>().getBookings(token);
      if (mounted) {
        setState(() {
          _bookings = list..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Booking> get _filteredBookings {
    switch (_filter) {
      case _BookingFilter.all:
        return _bookings;
      case _BookingFilter.new_:
      case _BookingFilter.pending:
        return _bookings
            .where((b) => b.status == BookingStatus.pending)
            .toList();
      case _BookingFilter.completed:
        return _bookings
            .where((b) => b.status == BookingStatus.completed)
            .toList();
    }
  }

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
      context.read<BookingsCache>().invalidate();
      _loadData();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Запись отменена'),
          backgroundColor: Colors.orange,
        ),
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
        const SnackBar(
          content: Text('Бронирование подтверждено'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleRejectBooking(String id) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    await DashboardApiService.rejectBooking(token, id);
    if (mounted) {
      context.read<BookingsCache>().invalidate();
      _loadData();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Бронирование отклонено'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: null,
        title: const Text(
          'Your appointments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                _filterChip('All', _BookingFilter.all),
                const SizedBox(width: 8),
                _filterChip('New', _BookingFilter.new_),
                const SizedBox(width: 8),
                _filterChip('Pending', _BookingFilter.pending),
                const SizedBox(width: 8),
                _filterChip('Completed', _BookingFilter.completed),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary500,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary500,
                    child: _filteredBookings.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 48),
                              Center(
                                child: Text(
                                  'No bookings',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: _filteredBookings.length,
                            itemBuilder: (context, index) {
                              final b = _filteredBookings[index];
                              return _BookingTile(
                                booking: b,
                                onTap: () => BookingDetailModal.show(
                                  context,
                                  booking: b,
                                  onEdit: _handleEditBooking,
                                  onCancel: _handleCancelBooking,
                                  onConfirm: _handleConfirmBooking,
                                  onReject: _handleRejectBooking,
                                ),
                                onConfirm: _handleConfirmBooking,
                                onReject: _handleRejectBooking,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _BookingFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary100,
      checkmarkColor: AppColors.primary500,
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  final Function(String) onConfirm;
  final Function(String) onReject;

  const _BookingTile({
    required this.booking,
    required this.onTap,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
                      booking.user?.name ?? booking.user?.email ?? 'Client',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.service?.name ?? '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy, HH:mm').format(booking.dateTime),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (booking.status == BookingStatus.pending) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => onConfirm(booking.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success500,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => onReject(booking.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error500,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✕',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _statusBadge(booking.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    Color bgColor;
    Color textColor;
    String label;
    switch (status) {
      case BookingStatus.pending:
        bgColor = AppColors.warning100;
        textColor = AppColors.warning600;
        label = 'Pending';
        break;
      case BookingStatus.confirmed:
        bgColor = AppColors.success100;
        textColor = AppColors.success600;
        label = 'Confirmed';
        break;
      case BookingStatus.completed:
        bgColor = AppColors.primary100;
        textColor = AppColors.primary600;
        label = 'Completed';
        break;
      case BookingStatus.canceled:
        bgColor = AppColors.error100;
        textColor = AppColors.error600;
        label = 'Cancelled';
        break;
      case BookingStatus.noShow:
        bgColor = AppColors.warning200;
        textColor = AppColors.warning700;
        label = 'No Show';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
