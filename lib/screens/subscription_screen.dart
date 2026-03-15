import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/colors.dart';
import '../models/subscription.dart';
import '../services/auth_service.dart';
import '../services/subscription_api_service.dart';

// Цены как в веб (VND).
const int _priceMonthlyVnd = 390000;
const int _priceAnnualVnd = 3150000;
const int _price12MonthsVnd = _priceMonthlyVnd * 12;
const int _saveAnnualPercent = 33; // округлённо

String _formatVnd(int amount) {
  final s = amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );
  return '$s ₫';
}

const List<String> _featureLabels = [
  'Неограниченное количество мастеров',
  'Персональный менеджер',
  'Маркетинговые инструменты',
  'Расширенная аналитика',
  'Безлимитные имейл напоминания',
  'Неограниченное количество услуг',
];

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Subscription? _subscription;
  List<SubscriptionInvoice> _invoices = [];
  bool _loading = true;
  String? _checkoutLoading; // 'monthly' | 'annual'
  bool _portalLoading = false;
  bool _cancelLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final sub = await SubscriptionApiService.getCurrent(token);
      setState(() {
        _subscription = sub;
        _loading = false;
      });
      if (sub?.stripeCustomerId != null && sub!.stripeCustomerId!.isNotEmpty) {
        final invoices = await SubscriptionApiService.getInvoices(token);
        if (mounted) setState(() => _invoices = invoices);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isPaid => (_subscription?.amount ?? 0) > 0;

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSelectPlan(String interval) async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    setState(() => _checkoutLoading = interval);
    try {
      final url = await SubscriptionApiService.createCheckoutSession(
        token,
        interval,
      );
      if (mounted && url != null) {
        await _openUrl(url);
      } else if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Не удалось перейти к оплате')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = null);
    }
  }

  Future<void> _handleManageBilling() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    setState(() => _portalLoading = true);
    try {
      final url = await SubscriptionApiService.createPortalSession(token);
      if (mounted && url != null) {
        await _openUrl(url);
      } else if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Нет привязки к оплате. Сначала оформите подписку.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _portalLoading = false);
    }
  }

  Future<void> _handleCancelSubscription() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить подписку?'),
        content: const Text(
          'Вы уверены? Доступ сохранится до конца оплаченного периода.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    setState(() => _cancelLoading = true);
    try {
      await SubscriptionApiService.cancel(token);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Подписка будет отменена в конце периода.'),
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Не удалось отменить: $e')));
      }
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text(
          'Подписка',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Управление подписками',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Управляйте тарифом и расширьте возможности бизнеса',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Триал-баннер
                    if (_subscription?.trialEndDate != null && !_isPaid) ...[
                      _TrialBanner(
                        trialEndDateFormatted:
                            _formatDate(_subscription!.trialEndDate) ?? '',
                        onGoToPlan: () => _handleSelectPlan('monthly'),
                        isLoading: _checkoutLoading != null,
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Оплаченная подписка
                    if (_isPaid) ...[
                      _PaidPlanCard(
                        subscription: _subscription!,
                        formatDate: _formatDate,
                        formatVnd: _formatVnd,
                        onTap: _handleManageBilling,
                        portalLoading: _portalLoading,
                      ),
                      const SizedBox(height: 12),
                      _BillingHistorySection(
                        invoices: _invoices,
                        formatVnd: _formatVnd,
                        onManageBilling: _handleManageBilling,
                        portalLoading: _portalLoading,
                      ),
                      const SizedBox(height: 12),
                      _AccountActionsCard(
                        onManageBilling: _handleManageBilling,
                        onCancel: _subscription?.status != 'CANCELLED'
                            ? _handleCancelSubscription
                            : null,
                        portalLoading: _portalLoading,
                        cancelLoading: _cancelLoading,
                      ),
                    ],
                    // Выбор плана (нет оплаты)
                    if (!_isPaid) ...[
                      _BillingToggle(
                        billingInterval: _billingInterval,
                        onChanged: (v) => setState(() => _billingInterval = v),
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        isAnnual: _billingInterval == 'annual',
                        onSubscribe: () => _handleSelectPlan(_billingInterval),
                        checkoutLoading: _checkoutLoading,
                        formatVnd: _formatVnd,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  String _billingInterval = 'monthly';
}

class _TrialBanner extends StatelessWidget {
  final String trialEndDateFormatted;
  final VoidCallback onGoToPlan;
  final bool isLoading;

  const _TrialBanner({
    required this.trialEndDateFormatted,
    required this.onGoToPlan,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error50,
        border: Border.all(color: AppColors.primary200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.primary500, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Сейчас у вас пробный период',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Истекает $trialEndDateFormatted',
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onGoToPlan,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
              child: Text(isLoading ? 'Загрузка...' : 'Продлить подписку'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaidPlanCard extends StatelessWidget {
  final Subscription subscription;
  final String? Function(String?) formatDate;
  final String Function(int) formatVnd;
  final VoidCallback? onTap;
  final bool portalLoading;

  const _PaidPlanCard({
    required this.subscription,
    required this.formatDate,
    required this.formatVnd,
    this.onTap,
    this.portalLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAnnual =
        (subscription.amount ?? 0) >= 1000000; // годовой тариф в VND
    final nextPayment = formatDate(subscription.nextPaymentDate);
    final endDate = formatDate(subscription.endDate);
    final isCancelled = subscription.status == 'CANCELLED';

    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border.all(color: AppColors.borderPrimary),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: AppColors.primary500, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starter – ${isAnnual ? 'Годовой' : 'Месячный'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isCancelled && endDate != null)
                      Text(
                        'Подписка до: $endDate',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.warning700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (nextPayment != null && !isCancelled)
                      Text(
                        'Дата продления: $nextPayment',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (!isCancelled)
                      Text(
                        '${isAnnual ? 'Списание раз в год' : 'Списание раз в месяц'} ${formatVnd(isAnnual ? _priceAnnualVnd : _priceMonthlyVnd)}/${isAnnual ? 'год' : 'мес'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (portalLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.warning100
                        : AppColors.primary500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCancelled ? 'ОТМЕНЕНА' : 'АКТИВЕН',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCancelled
                          ? AppColors.warning700
                          : AppColors.primary500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: portalLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }
    return content;
  }
}

class _BillingHistorySection extends StatelessWidget {
  final List<SubscriptionInvoice> invoices;
  final String Function(int) formatVnd;
  final VoidCallback onManageBilling;
  final bool portalLoading;

  const _BillingHistorySection({
    required this.invoices,
    required this.formatVnd,
    required this.onManageBilling,
    required this.portalLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border.all(color: AppColors.borderPrimary),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary500, size: 20),
              const SizedBox(width: 8),
              const Text(
                'История платежей',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Пока нет платежей',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...invoices.take(10).map((inv) {
              final displayNumber =
                  inv.number ??
                  (inv.id.length >= 12
                      ? inv.id.substring(inv.id.length - 12)
                      : inv.id);
              final dateStr = DateTime.tryParse(inv.date) != null
                  ? '${DateTime.parse(inv.date).day.toString().padLeft(2, '0')}.${DateTime.parse(inv.date).month.toString().padLeft(2, '0')}.${DateTime.parse(inv.date).year}'
                  : inv.date;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      inv.currency == 'VND'
                          ? formatVnd(inv.amount.round())
                          : '${inv.amount.toStringAsFixed(2)} ${inv.currency}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: portalLoading ? null : onManageBilling,
              child: Text(
                portalLoading ? 'Загрузка...' : 'ВСЕ ТРАНЗАКЦИИ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountActionsCard extends StatelessWidget {
  final VoidCallback onManageBilling;
  final VoidCallback? onCancel;
  final bool portalLoading;
  final bool cancelLoading;

  const _AccountActionsCard({
    required this.onManageBilling,
    this.onCancel,
    required this.portalLoading,
    required this.cancelLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border.all(color: AppColors.borderPrimary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'НАСТРОЙКИ АККАУНТА',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: portalLoading ? null : onManageBilling,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Управление оплатой'),
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: cancelLoading ? null : onCancel,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textSecondary,
              ),
              label: Text(
                cancelLoading ? 'Отменяем...' : 'Отменить подписку',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final String billingInterval;
  final ValueChanged<String> onChanged;

  const _BillingToggle({
    required this.billingInterval,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border.all(color: AppColors.borderPrimary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: billingInterval == 'monthly'
                  ? AppColors.backgroundPrimary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onChanged('monthly'),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Месячный',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: billingInterval == 'monthly'
                            ? AppColors.primary500
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: billingInterval == 'annual'
                  ? AppColors.backgroundPrimary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onChanged('annual'),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Годовой',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: billingInterval == 'annual'
                                ? AppColors.primary500
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-$_saveAnnualPercent%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _PlanCard extends StatelessWidget {
  final bool isAnnual;
  final VoidCallback onSubscribe;
  final String? checkoutLoading;
  final String Function(int) formatVnd;

  const _PlanCard({
    required this.isAnnual,
    required this.onSubscribe,
    required this.formatVnd,
    this.checkoutLoading,
  });

  @override
  Widget build(BuildContext context) {
    final price = isAnnual ? _priceAnnualVnd : _priceMonthlyVnd;
    final perLabel = isAnnual ? 'год' : 'мес';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border.all(color: AppColors.primary500.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary500.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Популярный выбор',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Starter',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Всё необходимое для роста вашего салона',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (isAnnual)
            Text(
              formatVnd(_price12MonthsVnd),
              style: const TextStyle(
                fontSize: 20,
                color: AppColors.textTertiary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          Text(
            '${formatVnd(price)} / $perLabel',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ..._featureLabels.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.primary500,
                  ),
                  const SizedBox(width: 10),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: checkoutLoading != null ? null : onSubscribe,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                checkoutLoading != null ? 'Загрузка...' : 'Оформить подписку',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Без долгосрочных обязательств. Отмена в любой момент.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
