import 'package:flutter/material.dart';
import '../constants/colors.dart';

class _SubscriptionColors {
  static const purple = Color(0xFF9C27B0);
  static const purpleLight = Color(0xFFE1BEE7);
  static const teal = Color(0xFF14B8A6);
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  static const _expiredDate = '31.12.2025';

  static const _liteFeatures = [
    '1 сотрудник',
    'Автонапоминания',
    'Аналитика базы клиентов',
    'Электронная записная',
    'Учёт доходов',
    'Онлайн-запись через приложение',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text(
          'Ваша подписка',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Истекла $_expiredDate',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.error500,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _SubscriptionColors.purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Пробный период',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _SubscriptionColors.purple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Описание пакета',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ..._liteFeatures.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: _SubscriptionColors.teal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Продление подписки — в разработке'),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _SubscriptionColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Продлить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
