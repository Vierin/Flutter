import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/colors.dart';
import '../../models/salon.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import 'booking_link_screen.dart';

const _kBookingPeriodKey = 'online_booking_period_days';

class OnlineBookingScreen extends StatefulWidget {
  const OnlineBookingScreen({super.key});

  @override
  State<OnlineBookingScreen> createState() => _OnlineBookingScreenState();
}

class _OnlineBookingScreenState extends State<OnlineBookingScreen> {
  Salon? _salon;
  bool _loading = true;
  int _bookingPeriodDays = 30;
  bool _autoConfirm = false;

  static const _periodOptions = [7, 14, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final salon = await DashboardApiService.getCurrentSalon(token);
      final prefs = await SharedPreferences.getInstance();
      final savedDays = prefs.getInt(_kBookingPeriodKey);
      if (mounted) {
        setState(() {
          _salon = salon;
          _autoConfirm = salon?.autoConfirmBookings ?? false;
          _bookingPeriodDays = savedDays ?? 30;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAutoConfirm(bool value) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null || _salon == null) return;
    // Оптимистичное обновление UI сразу, запрос в фоне
    setState(() => _autoConfirm = value);
    try {
      await DashboardApiService.updateCurrentSalon(token, {
        ..._salon!.toUpdatePayload(),
        'autoConfirmBookings': value,
      });
      final updated = await DashboardApiService.getCurrentSalon(token);
      if (mounted) setState(() => _salon = updated);
    } catch (_) {
      if (mounted) {
        setState(() => _autoConfirm = !value);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveBookingPeriod(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBookingPeriodKey, days);
    if (mounted) setState(() => _bookingPeriodDays = days);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: const Text('Online booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }

    if (_salon == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: const Text('Online booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          backgroundColor: AppColors.backgroundPrimary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: Text('Сначала настройте салон', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Online booking',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Booking period
            const Text(
              'Booking period',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Максимальное время до создания резервации (дней)',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _periodOptions.map((days) {
                final selected = _bookingPeriodDays == days;
                return ChoiceChip(
                  label: Text('$days дней'),
                  selected: selected,
                  onSelected: (_) => _saveBookingPeriod(days),
                  selectedColor: AppColors.primary100,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Automatic confirmation (оптимистичный UI, запрос в фоне)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Automatic confirmation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ),
                Switch(
                  value: _autoConfirm,
                  onChanged: (v) => _saveAutoConfirm(v),
                  activeColor: AppColors.primary500,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Новые записи подтверждаются автоматически без вашего одобрения.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 32),
            // Booking link button
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingLinkScreen(salon: _salon!),
                ),
              ),
              icon: const Icon(Icons.link, size: 20),
              label: const Text('Booking link'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
