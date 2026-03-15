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
              BookingDetailHeader(
                title: 'Booking Details',
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BookingDetailStatusBadge(status: booking.status),
                      const SizedBox(height: 20),
                      BookingDetailSection(
                        title: 'Client',
                        mainText: booking.user?.name ?? 'Unknown Client',
                        subTexts: [
                          if (booking.user?.email != null &&
                              booking.user!.email!.isNotEmpty)
                            booking.user!.email!,
                          if (booking.user?.phone != null &&
                              booking.user!.phone!.isNotEmpty)
                            booking.user!.phone!,
                        ],
                      ),
                      const SizedBox(height: 20),
                      BookingDetailSection(
                        title: 'Service',
                        mainText:
                            booking.service?.name ?? 'Unknown Service',
                        subTexts: [
                          if (booking.service?.duration != null)
                            'Duration: ${booking.service!.duration} minutes',
                          if (booking.service?.price != null &&
                              booking.service!.price != null)
                            'Price: ${formatVnd(booking.service!.price!)}',
                        ],
                      ),
                      const SizedBox(height: 20),
                      BookingDetailSection(
                        title: 'Date & Time',
                        mainText: DateFormat('EEEE, dd/MM/yyyy')
                            .format(booking.dateTime),
                        subTexts: [
                          DateFormat('HH:mm').format(booking.dateTime),
                        ],
                      ),
                      if (booking.staff != null) ...[
                        const SizedBox(height: 20),
                        BookingDetailSection(
                          title: 'Staff',
                          mainText: booking.staff!.name,
                          subTexts: [],
                        ),
                      ],
                      if (booking.notes != null &&
                          booking.notes!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        BookingDetailSection(
                          title: 'Notes',
                          mainText: booking.notes!,
                          subTexts: [],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _BookingDetailActions(
                booking: booking,
                onEdit: onEdit,
                onCancel: onCancel,
                onConfirm: onConfirm,
                onReject: onReject,
                onClose: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable header for booking detail modal: title + close button.
class BookingDetailHeader extends StatelessWidget {
  const BookingDetailHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderPrimary),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: onClose,
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
    );
  }
}

/// Section with title and main/sub lines.
class BookingDetailSection extends StatelessWidget {
  const BookingDetailSection({
    super.key,
    required this.title,
    required this.mainText,
    this.subTexts = const [],
  });

  final String title;
  final String mainText;
  final List<String> subTexts;

  @override
  Widget build(BuildContext context) {
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
        ...subTexts.map(
          (text) => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingDetailStatusBadge extends StatelessWidget {
  const _BookingDetailStatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
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
}

class _BookingDetailActions extends StatelessWidget {
  const _BookingDetailActions({
    required this.booking,
    this.onEdit,
    this.onCancel,
    this.onConfirm,
    this.onReject,
    required this.onClose,
  });

  final Booking booking;
  final Function(Booking)? onEdit;
  final Function(String)? onCancel;
  final Function(String)? onConfirm;
  final Function(String)? onReject;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      onClose();
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
                      onClose();
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
          if (booking.status == BookingStatus.pending) const SizedBox(height: 12),
          if (booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onEdit?.call(booking);
                      onClose();
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
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Да, отменить'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        onCancel?.call(booking.id);
                        if (context.mounted) onClose();
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
    );
  }
}
