import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';

class UpcomingBookingsList extends StatefulWidget {
  final String title;
  final List<Booking> bookings;
  final bool loading;
  final VoidCallback? onViewAll;
  final Function(Booking)? onEditBooking;
  final Function(String)? onCancelBooking;
  final Function(String)? onConfirmBooking;
  final Function(String)? onRejectBooking;
  final Function(Booking)? onBookingPress;

  const UpcomingBookingsList({
    super.key,
    this.title = 'Upcoming Bookings',
    required this.bookings,
    required this.loading,
    this.onViewAll,
    this.onEditBooking,
    this.onCancelBooking,
    this.onConfirmBooking,
    this.onRejectBooking,
    this.onBookingPress,
  });

  @override
  State<UpcomingBookingsList> createState() => _UpcomingBookingsListState();
}

class _UpcomingBookingsListState extends State<UpcomingBookingsList> {
  int _currentPage = 0;
  final int _itemsPerPage = 5;
  final int _maxPages = 4;

  @override
  Widget build(BuildContext context) {
    final totalPages = (widget.bookings.length / _itemsPerPage).ceil().clamp(
      0,
      _maxPages,
    );
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(
      0,
      widget.bookings.length,
    );
    final currentBookings = widget.bookings.sublist(
      startIndex.clamp(0, widget.bookings.length),
      endIndex,
    );
    final hasMorePages = widget.bookings.length > _maxPages * _itemsPerPage;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderPrimary),
              ),
            ),
            child: widget.loading
                ? Container(
                    width: double.infinity,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.neutral200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.onViewAll != null)
                        IconButton(
                          onPressed: widget.onViewAll,
                          icon: const Icon(
                            Icons.launch,
                            size: 20,
                            color: AppColors.primary500,
                          ),
                          tooltip: 'Все записи',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                    ],
                  ),
          ),
          // Content
          if (widget.loading)
            ...List.generate(3, (index) => _buildSkeletonItem(index < 2))
          else if (widget.bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(
                      widget.title == 'Today bookings'
                          ? 'Нет записей на сегодня'
                          : 'No upcoming bookings',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                ...currentBookings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final booking = entry.value;
                  return _buildBookingItem(
                    booking,
                    index < currentBookings.length - 1,
                  );
                }),
                // Pagination
                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(totalPages, (index) {
                          final isSelected = _currentPage == index;
                          return GestureDetector(
                            onTap: () => setState(() => _currentPage = index),
                            child: Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary500
                                    : AppColors.neutral200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textInverse
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (hasMorePages)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '+${widget.bookings.length - _maxPages * _itemsPerPage} more',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonItem(bool showBorder) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: AppColors.borderPrimary))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 150,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingItem(Booking booking, bool showBorder) {
    return GestureDetector(
      onTap: () => widget.onBookingPress?.call(booking),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: showBorder
              ? const Border(bottom: BorderSide(color: AppColors.borderPrimary))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.user?.name ??
                        booking.user?.email ??
                        'Client ${booking.id.substring(0, 6)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    booking.service?.name ?? 'Unknown Service',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM/yyyy, HH:mm').format(booking.dateTime),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (booking.status == BookingStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                widget.onConfirmBooking?.call(booking.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                widget.onRejectBooking?.call(booking.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✕',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _buildStatusBadge(booking.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
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
