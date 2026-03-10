import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../utils/currency_format.dart';

class BookingDetailModal {
  static void show(
    BuildContext context, {
    required Booking booking,
    Function(Booking)? onEdit,
    Function(String)? onCancel,
    Function(String)? onConfirm,
    Function(String)? onReject,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingDetailContent(
        booking: booking,
        onEdit: onEdit,
        onCancel: onCancel,
        onConfirm: onConfirm,
        onReject: onReject,
      ),
    );
  }
}

class _BookingDetailContent extends StatelessWidget {
  final Booking booking;
  final Function(Booking)? onEdit;
  final Function(String)? onCancel;
  final Function(String)? onConfirm;
  final Function(String)? onReject;

  const _BookingDetailContent({
    required this.booking,
    this.onEdit,
    this.onCancel,
    this.onConfirm,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => SafeArea(
        top: false,
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 20, 16, 20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderPrimary),
                  ),
                ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Booking Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          '✕',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 20, 16, 12),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    _buildStatusBadge(booking.status),
                    const SizedBox(height: 20),
                    // Client Info
                    _buildSection(
                      'Client',
                      booking.user?.name ?? 'Unknown Client',
                      [
                        if (booking.user?.email != null && booking.user!.email!.isNotEmpty)
                          booking.user!.email!,
                        if (booking.user?.phone != null && booking.user!.phone!.isNotEmpty)
                          booking.user!.phone!,
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Service Info
                    _buildSection(
                      'Service',
                      booking.service?.name ?? 'Unknown Service',
                      [
                        if (booking.service?.duration != null)
                          'Duration: ${booking.service!.duration} minutes',
                        if (booking.service?.price != null && booking.service!.price != null)
                          'Price: ${formatVnd(booking.service!.price!)}',
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Date & Time
                    _buildSection(
                      'Date & Time',
                      DateFormat('EEEE, dd/MM/yyyy').format(booking.dateTime),
                      [DateFormat('HH:mm').format(booking.dateTime)],
                    ),
                    const SizedBox(height: 20),
                    // Staff
                    if (booking.staff != null)
                      _buildSection(
                        'Staff',
                        booking.staff!.name,
                        [],
                      ),
                    if (booking.staff != null) const SizedBox(height: 20),
                    // Notes
                    if (booking.notes != null && booking.notes!.isNotEmpty)
                      _buildSection(
                        'Notes',
                        booking.notes!,
                        [],
                      ),
                  ],
                ),
              ),
            ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderPrimary),
                  ),
                ),
                child: Column(
                children: [
                  if (booking.status == BookingStatus.pending)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onConfirm?.call(booking.id);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success500,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                color: AppColors.textInverse,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onReject?.call(booking.id);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error500,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(
                                color: AppColors.textInverse,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (booking.status == BookingStatus.pending)
                    const SizedBox(height: 12),
                  if (booking.status == BookingStatus.confirmed ||
                      booking.status == BookingStatus.pending)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onEdit?.call(booking);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Изменить',
                              style: TextStyle(
                                color: AppColors.textInverse,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Отменить запись?'),
                                  content: const Text(
                                    'Запись будет отменена. Клиент может получить уведомление.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Нет'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Да, отменить'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                onCancel?.call(booking.id);
                                if (context.mounted) Navigator.of(context).pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.neutral500,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Отменить запись',
                              style: TextStyle(
                                color: AppColors.textInverse,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                ),
              ),
            ],
          ),
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
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Pending';
        break;
      case BookingStatus.confirmed:
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        label = 'Confirmed';
        break;
      case BookingStatus.completed:
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        label = 'Completed';
        break;
      case BookingStatus.canceled:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'Cancelled';
        break;
      case BookingStatus.noShow:
        bgColor = const Color(0xFFFED7AA);
        textColor = const Color(0xFFEA580C);
        label = 'No Show';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String mainText, List<String> subTexts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          mainText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        ...subTexts.map((text) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            )),
      ],
    );
  }
}
