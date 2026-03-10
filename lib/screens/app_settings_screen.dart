import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildListTile(
              icon: Icons.language,
              title: 'Сменить язык',
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Смена языка в разработке')),
                );
              },
            ),
            const SizedBox(height: 8),
            // Реферальная программа — скрыта пока
            // _buildListTile(
            //   icon: Icons.card_giftcard_outlined,
            //   title: 'Реферальная программа',
            //   onTap: () { ... },
            // ),
            _buildListTile(
              icon: Icons.description_outlined,
              title: 'Политика конфиденциальности',
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Политика конфиденциальности в разработке'),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildListTile(
              icon: Icons.description_outlined,
              title: 'Условия использования',
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Условия использования в разработке'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Версия 1.0.0',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            _buildExitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppColors.primary500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (icon: Icons.event_note_outlined, label: 'Как создать\nзапись'),
      (icon: Icons.person_add_outlined, label: 'Как добавить\nсотрудника'),
      (icon: Icons.list_alt_outlined, label: 'Как добавить\nуслугу'),
      (icon: Icons.public_outlined, label: 'Online\nбронирование'),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = actions[index];
          return _buildQuickActionButton(
            icon: a.icon,
            label: a.label,
            onTap: () {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    '${a.label.replaceAll('\n', ' ')} в разработке',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textInverse, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await context.read<AuthService>().logout();
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error500, width: 2),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Выход',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error500,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.logout, size: 20, color: AppColors.error500),
            ],
          ),
        ),
      ),
    );
  }
}
