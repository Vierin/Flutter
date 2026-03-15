import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../l10n/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/dashboard/new_booking_modal.dart';
import 'dashboard/dashboard_screen.dart';
import 'calendar_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'staff_screen.dart';
import 'clients_screen.dart';
import 'online_booking_screen.dart';
import 'all_bookings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

/// Состояние MainShell — можно использовать для навигации на экраны первой вкладки с сохранением нижней панели.
class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _salonLoading = true;
  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSalon());
  }

  Future<void> _loadSalon() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _salonLoading = false);
      return;
    }
    try {
      await context.read<SalonCache>().getSalon(token);
    } catch (_) {
      // показываем интерфейс даже при ошибке
    }
    if (mounted) {
      setState(() => _salonLoading = false);
      final locale = context.read<LocaleProvider>();
      await PushNotificationService.requestNotificationPermission();
      if (mounted) {
        PushNotificationService.registerToken(
          accessToken: token,
          language: locale.localeCode,
        );
      }
    }
  }

  /// Переключиться на первую вкладку и открыть маршрут (например /staff, /services).
  void navigateToTab0Route(String routeName) {
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeNavigatorKey.currentState?.pushNamed(routeName);
    });
  }

  Widget _buildHomeNavigator() {
    return Navigator(
      key: _homeNavigatorKey,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
          case '/services':
            return MaterialPageRoute(builder: (_) => const ServicesScreen());
          case '/staff':
            return MaterialPageRoute(builder: (_) => const StaffScreen());
          case '/clients':
            return MaterialPageRoute(builder: (_) => const ClientsScreen());
          case '/online-booking':
            return MaterialPageRoute(
              builder: (_) => const OnlineBookingScreen(),
            );
          case '/all-bookings':
            return MaterialPageRoute(builder: (_) => const AllBookingsScreen());
          default:
            return MaterialPageRoute(builder: (_) => const DashboardScreen());
        }
      },
    );
  }

  List<Widget> get _screens => [
    _buildHomeNavigator(),
    CalendarScreen(),
    AnalyticsScreen(),
    const ProfileScreen(),
  ];

  Future<void> _openNewBooking() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) return;
    await NewBookingModal.show(
      context,
      accessToken: token,
      onSaved: () {},
      getAccessToken: () async {
        await context.read<AuthService>().refreshSession();
        return context.read<AuthService>().accessToken;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (_salonLoading) const _SalonLoadingCurtain(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          constraints: const BoxConstraints(minHeight: 42, maxHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Consumer<LocaleProvider>(
            builder: (context, locale, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: locale.t('nav.dashboard'),
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_today,
                    label: locale.t('nav.calendar'),
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                Expanded(child: _PlusButton(onTap: _openNewBooking)),
                Expanded(
                  child: _NavItem(
                    icon: Icons.analytics_outlined,
                    activeIcon: Icons.analytics,
                    label: locale.t('nav.analytics'),
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: locale.t('nav.profile'),
                    isSelected: _currentIndex == 3,
                    onTap: () => setState(() => _currentIndex = 3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Center(
          child: Icon(Icons.add_circle, size: 40, color: AppColors.primary500),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary500 : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 20, color: color),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Занавес при загрузке данных салона: логотип и подпись «Подгружаем данные».
class _SalonLoadingCurtain extends StatelessWidget {
  const _SalonLoadingCurtain();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 80,
                  width: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.store,
                    size: 80,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Подгружаем данные',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
