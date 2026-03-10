import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class DashboardLoadingCard extends StatelessWidget {
  const DashboardLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
