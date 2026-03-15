import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../l10n/locale_provider.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/cache/salon_cache.dart';
import '../services/cache/services_staff_cache.dart';
import '../services/dashboard_api_service.dart';
import 'main_shell.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'work_schedule_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _staffCount = 0;
  int _servicesCount = 0;
  bool _loadingCounts = true;
  Subscription? _subscription;
  bool _loadingSubscription = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCounts();
      _loadSubscription();
    });
  }

  Future<void> _loadSubscription() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _loadingSubscription = false);
      return;
    }
    try {
      final sub = await DashboardApiService.getCurrentSubscription(token);
      if (mounted) setState(() {
        _subscription = sub;
        _loadingSubscription = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSubscription = false);
    }
  }

  static String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final d = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy').format(d);
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _loadCounts() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _loadingCounts = false; });
      return;
    }
    try {
      final salon = await context.read<SalonCache>().getSalon(token);
      if (salon == null || !mounted) {
        if (mounted) setState(() => _loadingCounts = false);
        return;
      }
      final cache = context.read<ServicesStaffCache>();
      final staff = await cache.getStaffForSalon(token, salon.id);
      final services = await cache.getServicesForSalon(token, salon.id);
      if (!mounted) return;
      setState(() {
        _staffCount = staff.length;
        _servicesCount = services.length;
        _loadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(
            title: Text(
              locale.t('profile.title'),
              style: const TextStyle(
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
          body: RefreshIndicator(
            onRefresh: () async {
              await _loadSubscription();
              if (mounted) await _loadCounts();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
          ),
    );
      },
    );
  }

  static String _packageLabel(String? type) {
    if (type == null || type.isEmpty) return '—';
    switch (type.toUpperCase()) {
      case 'TRIAL':
        return 'Пробный';
      case 'STARTER':
        return 'Starter';
      default:
        return type;
    }
  }

  static String _statusLabel(bool loading, Subscription? sub) {
    if (loading) return 'Загрузка...';
    if (sub == null) return 'Нет подписки';
    switch (sub.status.toUpperCase()) {
      case 'ACTIVE':
        return 'Активна';
      case 'CANCELLED':
        return 'Отменена';
      case 'EXPIRED':
        return 'Истекла';
      case 'INACTIVE':
        return 'Неактивна';
      default:
        return sub.status;
    }
  }

  Widget _buildCurrentSubscriptionCard() {
    final sub = _subscription;
    final isActive = sub?.isActive ?? false;
    final borderColor = isActive ? AppColors.primary500 : AppColors.error500;
    final statusColor = isActive ? AppColors.primary500 : AppColors.error500;
    final endDateStr = sub != null
        ? _formatDate(sub.endDate ?? sub.nextPaymentDate ?? sub.trialEndDate)
        : '—';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        ).then((_) {
          if (mounted) _loadSubscription();
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 10),
                    Text(
                      'Пакет: ${_packageLabel(sub?.type)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Статус: ${_statusLabel(_loadingSubscription, sub)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _loadingSubscription
                            ? AppColors.textSecondary
                            : statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Действительна до: $endDateStr',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
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
                        color: AppColors.primary100,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary600,
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
