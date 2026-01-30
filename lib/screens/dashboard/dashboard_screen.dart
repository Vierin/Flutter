import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../models/salon.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/dashboard/stats_card.dart';
import '../../widgets/dashboard/period_selector.dart';
import '../../widgets/dashboard/pending_bookings_section.dart';
import '../../widgets/dashboard/upcoming_bookings_list.dart';
import '../../models/service_item.dart';
import '../../models/staff_member.dart';
import '../../services/services_api_service.dart';
import '../../services/staff_api_service.dart';
import '../../widgets/dashboard/booking_detail_modal.dart';
import '../../widgets/dashboard/new_booking_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Period _selectedPeriod = Period.thirtyDays;
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
      final salon = await DashboardApiService.getCurrentSalon(token);
      final bookings = await DashboardApiService.getOwnerBookings(token);
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
      final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message.length > 80 ? 'Ошибка подтверждения' : message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectBooking(String bookingId) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
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
      final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message.length > 80 ? 'Ошибка отклонения' : message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openNewBookingModal() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || _salon == null) return;
    List<ServiceItem> services = [];
    List<StaffMember> staffMembers = [];
    try {
      services = await ServicesApiService.getBySalon(token, _salon!.id);
      staffMembers = await StaffApiService.getBySalon(token, _salon!.id);
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
    if (staffMembers.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Добавьте сотрудников'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await NewBookingModal.show(
      context,
      salonId: _salon!.id,
      services: services,
      staffMembers: staffMembers,
      accessToken: token,
      onSaved: _loadData,
      getAccessToken: () async {
        await context.read<AuthService>().refreshSession();
        return context.read<AuthService>().accessToken;
      },
    );
  }

  String _formatVND(double amount) {
    if (amount >= 1000000000) {
      return '₫${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      return '₫${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '₫${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₫${amount.toStringAsFixed(0)}';
  }

  Map<String, dynamic> _calculateStats() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case Period.sevenDays:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case Period.thirtyDays:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case Period.oneYear:
        startDate = now.subtract(const Duration(days: 365));
        break;
    }

    final periodBookings = _bookings.where((booking) {
      return booking.dateTime.isAfter(startDate) &&
          booking.dateTime.isBefore(now) ||
          booking.dateTime.isAtSameMomentAs(startDate) ||
          booking.dateTime.isAtSameMomentAs(now);
    }).toList();

    final revenue = periodBookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<double>(
          0,
          (sum, booking) => sum + (booking.service?.price ?? 0),
        );

    final uniqueClients = periodBookings
        .map((b) => b.user?.email ?? b.user?.name ?? '')
        .where((email) => email.isNotEmpty)
        .toSet()
        .length;

    final completedCount = periodBookings
        .where((b) => b.status == BookingStatus.completed)
        .length;

    final completionRate = periodBookings.isEmpty
        ? 0
        : ((completedCount / periodBookings.length) * 100).round();

    return {
      'revenue': revenue,
      'clients': uniqueClients,
      'bookings': periodBookings.length,
      'completionRate': completionRate,
    };
  }

  List<Booking> _getUpcomingBookings() {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    return _bookings.where((booking) {
      return booking.dateTime.isAfter(now) &&
          booking.dateTime.isBefore(sevenDaysFromNow) &&
          booking.status == BookingStatus.confirmed;
    }).toList();
  }

  List<Booking> _getPendingBookings() {
    return _bookings
        .where((booking) => booking.status == BookingStatus.pending)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final upcomingBookings = _getUpcomingBookings();
    final pendingBookings = _getPendingBookings();

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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                        onPressed: _salon == null ? null : () => _openNewBookingModal(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'New Booking',
                          style: TextStyle(
                            color: AppColors.textInverse,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Period Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PeriodSelector(
                    value: _selectedPeriod,
                    onValueChange: (period) {
                      setState(() => _selectedPeriod = period);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Loader while fetching salon/data, then Setup Card or Stats
                if (_isLoading)
                  _buildLoadingCard()
                else if (_salon == null)
                  _buildSetupCard()
                else
                  Column(
                    children: [
                      // Stats Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _isLoading
                            ? _buildStatsSkeleton()
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StatsCard(
                                          title: 'Total Revenue',
                                          value: _formatVND(stats['revenue']),
                                          icon: const Icon(
                                            Icons.attach_money,
                                            size: 18,
                                            color: AppColors.primary500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: StatsCard(
                                          title: 'Total Clients',
                                          value: stats['clients'].toString(),
                                          icon: const Icon(
                                            Icons.people,
                                            size: 18,
                                            color: AppColors.primary500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: StatsCard(
                                          title: 'Bookings',
                                          value: stats['bookings'].toString(),
                                          icon: const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: AppColors.primary500,
                                          ),
                                          subtitle: _selectedPeriod ==
                                                  Period.sevenDays
                                              ? 'Last 7 Days'
                                              : _selectedPeriod == Period.thirtyDays
                                                  ? 'Last 30 Days'
                                                  : 'Last 1 Year',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: StatsCard(
                                          title: 'Completion Rate',
                                          value: '${stats['completionRate']}%',
                                          icon: const Icon(
                                            Icons.trending_up,
                                            size: 18,
                                            color: AppColors.primary500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      // Pending Bookings Section
                      if (pendingBookings.isNotEmpty || _isLoading)
                        PendingBookingsSection(
                          bookings: pendingBookings,
                          loading: _isLoading,
                          count: pendingBookings.length,
                          onBookingPress: (booking) {
                            BookingDetailModal.show(
                              context,
                              booking: booking,
                              onEdit: (b) {
                                // TODO: Handle edit
                                print('Edit booking: ${b.id}');
                              },
                              onCancel: (bookingId) {
                                // TODO: Handle cancel
                                print('Cancel booking: $bookingId');
                              },
                              onConfirm: _handleConfirmBooking,
                              onReject: _handleRejectBooking,
                            );
                          },
                          onConfirmBooking: _handleConfirmBooking,
                          onRejectBooking: _handleRejectBooking,
                        ),
                      const SizedBox(height: 24),
                      // Upcoming Bookings
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: UpcomingBookingsList(
                          bookings: upcomingBookings,
                          loading: _isLoading,
                          onEditBooking: (booking) {
                            // TODO: Handle edit booking
                            print('Edit booking: ${booking.id}');
                          },
                          onCancelBooking: (bookingId) {
                            // TODO: Handle cancel booking
                            print('Cancel booking: $bookingId');
                          },
                          onConfirmBooking: _handleConfirmBooking,
                          onRejectBooking: _handleRejectBooking,
                          onBookingPress: (booking) {
                            BookingDetailModal.show(
                              context,
                              booking: booking,
                              onEdit: (b) {
                                // TODO: Handle edit
                                print('Edit booking: ${b.id}');
                              },
                              onCancel: (bookingId) {
                                // TODO: Handle cancel
                                print('Cancel booking: $bookingId');
                              },
                              onConfirm: _handleConfirmBooking,
                              onReject: _handleRejectBooking,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary500),
            const SizedBox(height: 16),
            Text(
              'Загрузка данных салона...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Setup Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please complete your salon setup to start using the dashboard.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to setup screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Setup Salon',
              style: TextStyle(
                color: AppColors.textInverse,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSkeleton() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: StatsCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: StatsCardSkeleton()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: StatsCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: StatsCardSkeleton()),
          ],
        ),
      ],
    );
  }
}

