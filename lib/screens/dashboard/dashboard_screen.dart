import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../models/salon.dart';
import '../../utils/auth_load_helper.dart';
import '../../services/auth_service.dart';
import '../../services/cache/bookings_cache.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/dashboard/booking_detail_modal.dart';
import '../../widgets/dashboard/dashboard_header_pill.dart';
import '../../widgets/dashboard/dashboard_link_card.dart';
import '../../widgets/dashboard/dashboard_loading_card.dart';
import '../../widgets/dashboard/dashboard_setup_card.dart';
import '../../widgets/dashboard/upcoming_bookings_list.dart';
import '../app_settings_screen.dart';
import '../notifications_screen.dart';
import '../salon_setup_screen.dart';
import '../../widgets/dashboard/new_booking_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Salon? _salon;
  List<Booking> _bookings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _salon = null;
          _bookings = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final salon = await context.read<SalonCache>().getSalon(token);
      final bookings = await context.read<BookingsCache>().getBookings(token);
      if (mounted) {
        setState(() {
          _salon = salon;
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salon = null;
          _bookings = [];
          _isLoading = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить данные: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  Future<void> _handleConfirmBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final ok = await DashboardApiService.confirmBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        context.read<BookingsCache>().invalidate();
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Бронирование подтверждено'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Не удалось подтвердить бронирование'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message.length > 80 ? 'Ошибка подтверждения' : message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCancelBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final ok = await DashboardApiService.cancelBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        context.read<BookingsCache>().invalidate();
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
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message.length > 80 ? 'Ошибка отмены' : message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleEditBooking(Booking booking) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
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

  Future<void> _handleRejectBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final ok = await DashboardApiService.rejectBooking(token, bookingId);
      if (!mounted) return;
      if (ok) {
        context.read<BookingsCache>().invalidate();
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Бронирование отклонено'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Не удалось отклонить бронирование'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message.length > 80 ? 'Ошибка отклонения' : message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Booking> _getTodayBookings() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return _bookings.where((booking) {
      return !booking.dateTime.isBefore(todayStart) &&
          booking.dateTime.isBefore(todayEnd) &&
          booking.status != BookingStatus.canceled;
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final todayBookings = _getTodayBookings();

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary500,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _salon?.name ?? 'Мой салон',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          if (_salon != null)
                            _buildHeaderPill(
                              icon: Icons.star_rounded,
                              label: '—',
                              onTap: null,
                            ),
                          _buildHeaderIconPill(
                            icon: Icons.notifications_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                          DashboardHeaderIconPill(
                            icon: Icons.settings_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppSettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Link cards: Клиенты, Online booking
                if (!_isLoading && _salon != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLinkCard(
                            title: 'Клиенты',
                            icon: Icons.people_outline,
                            color: AppColors.primary100,
                            onTap: () =>
                                Navigator.of(context).pushNamed('/clients'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLinkCard(
                            title: 'Online booking',
                            icon: Icons.calendar_month_outlined,
                            color: AppColors.secondary100,
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/online-booking'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isLoading)
                  const DashboardLoadingCard()
                else if (_salon == null)
                  DashboardSetupCard(
                    onSetupTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalonSetupScreen(
                          onSaved: () {
                            Navigator.pop(context);
                            _loadData();
                          },
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: UpcomingBookingsList(
                      title: 'Today bookings',
                      bookings: todayBookings,
                      loading: _isLoading,
                      onViewAll: () =>
                          Navigator.of(context).pushNamed('/all-bookings'),
                      onEditBooking: _handleEditBooking,
                      onCancelBooking: _handleCancelBooking,
                      onConfirmBooking: _handleConfirmBooking,
                      onRejectBooking: _handleRejectBooking,
                      onBookingPress: (booking) {
                        BookingDetailModal.show(
                          context,
                          booking: booking,
                          onEdit: _handleEditBooking,
                          onCancel: _handleCancelBooking,
                          onConfirm: _handleConfirmBooking,
                          onReject: _handleRejectBooking,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
