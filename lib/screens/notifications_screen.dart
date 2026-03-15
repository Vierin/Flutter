import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../l10n/locale_provider.dart';
import '../models/app_notification.dart';
import '../services/notifications_store.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsStore>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final store = context.watch<NotificationsStore>();
    final items = store.items;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.neutral200,
            shape: const CircleBorder(),
          ),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          locale.t('notifications.title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (items.isNotEmpty)
            IconButton(
              onPressed: () async {
                await store.clearAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(locale.t('notifications.cleared'))),
                  );
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: AppColors.neutral200,
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('😔', style: TextStyle(fontSize: 64, height: 1)),
                    const SizedBox(height: 24),
                    Text(
                      locale.t('notifications.empty'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final n = items[index];
                return _NotificationTile(notification: n);
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final timeStr = _dateFormat.format(notification.createdAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          context.read<NotificationsStore>().markRead(notification.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notification.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: notification.read ? FontWeight.normal : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (notification.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
