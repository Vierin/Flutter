import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/dashboard_api_service.dart';
import '../services/services_api_service.dart';
import '../services/staff_api_service.dart';
import 'main_shell.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'work_schedule_screen.dart';

// Profile theme colors (purple as in design)
class _ProfileColors {
  static const purple = Color(0xFF9C27B0);
  static const purpleLight = Color(0xFFE1BEE7);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Placeholder: дата истечения подписки
  static const _expiredDate = '31.12.2025';

  int _staffCount = 0;
  int _servicesCount = 0;
  bool _loadingCounts = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  Future<void> _loadCounts() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _loadingCounts = false; });
      return;
    }
    try {
      final salon = await DashboardApiService.getCurrentSalon(token);
      if (salon == null || !mounted) {
        if (mounted) setState(() => _loadingCounts = false);
        return;
      }
      final results = await Future.wait([
        StaffApiService.getBySalon(token, salon.id),
        ServicesApiService.getBySalon(token, salon.id),
      ]);
      if (!mounted) return;
      setState(() {
        _staffCount = results[0].length;
        _servicesCount = results[1].length;
        _loadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(
            fontSize: 24,
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentSubscriptionCard(),
            const SizedBox(height: 24),
            _buildFourCardsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error500, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ваша подписка',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Истекла $_expiredDate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.launch, size: 22, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFourCardsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ProfileGridCard(
                title: 'Работники',
                count: _loadingCounts ? null : _staffCount,
                onTap: () {
                  context.findAncestorStateOfType<MainShellState>()?.navigateToTab0Route('/staff');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileGridCard(
                title: 'Сервисы',
                count: _loadingCounts ? null : _servicesCount,
                onTap: () {
                  context.findAncestorStateOfType<MainShellState>()?.navigateToTab0Route('/services');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfileGridCard(
                title: 'Work schedule',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkScheduleScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfileGridCard(
                title: 'Profile info',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileGridCard extends StatelessWidget {
  final String title;
  final int? count;
  final VoidCallback onTap;

  const _ProfileGridCard({
    required this.title,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (count != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _ProfileColors.purpleLight,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _ProfileColors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
