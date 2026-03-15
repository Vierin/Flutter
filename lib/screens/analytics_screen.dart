import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../l10n/locale_provider.dart';
import '../utils/currency_format.dart';
import 'period_picker_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await PeriodPickerScreen.show(
      context,
      DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked != null && mounted) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
    }
  }

  String get _periodText {
    final fmt = DateFormat('dd.MM.yyyy');
    return '${fmt.format(_rangeStart)} - ${fmt.format(_rangeEnd)}';
  }

  // Placeholder stats — will be wired to API later
  int get _totalClients => 1;
  int get _regularCount => 1;
  int get _newCount => 0;
  int get _sleepersCount => 0;
  double get _income => 0;
  double get _expenses => 0;
  double get _netProfit => 0;
  int get _totalVisits => 0;
  double get _averageClientCheck => 0;
  double get _totalSales => 0;
  int get _totalServices => 0;
  String get _mostPopularService => '—';

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, locale, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    locale.t('analytics.title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Period picker
                  Row(
                    children: [
                      Text(
                        locale.t('analytics.period'),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _periodText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildClientsCard(locale),
              const SizedBox(height: 24),
              SizedBox(
                height: 225,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  padEnds: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildIncomeExpensesSlide(locale),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildSalesSlide(locale),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _buildServicesSlide(locale),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentPage ? 20 : 8,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _currentPage
                            ? AppColors.analyticsPurple
                            : AppColors.neutral300,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildIncomeExpensesSlide(LocaleProvider locale) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _buildIncomeExpensesCard(locale),
    );
  }

  Widget _buildSalesSlide(LocaleProvider locale) {
    return _buildSlideCard(
      title: locale.t('analytics.sales'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsMiniCard(
                  title: locale.t('analytics.visits'),
                  value: '$_totalVisits',
                  icon: Icons.people_outline,
                  iconBg: AppColors.analyticsTealLight,
                  iconColor: AppColors.analyticsTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsMiniCard(
                  title: locale.t('analytics.average'),
                  value: formatVnd(_averageClientCheck),
                  icon: Icons.receipt_long_outlined,
                  iconBg: AppColors.analyticsTealLight,
                  iconColor: AppColors.analyticsTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAnalyticsMiniCard(
            title: locale.t('analytics.totalSales'),
            value: formatVnd(_totalSales),
            fullWidth: true,
            icon: Icons.trending_up,
            iconBg: AppColors.analyticsPurpleLight,
            iconColor: AppColors.analyticsPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSlide(LocaleProvider locale) {
    return _buildSlideCard(
      title: locale.t('analytics.services'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnalyticsMiniCard(
            title: locale.t('analytics.totalServices'),
            value: '$_totalServices',
            fullWidth: true,
            icon: Icons.miscellaneous_services_outlined,
            iconBg: AppColors.analyticsPurpleLight,
            iconColor: AppColors.analyticsPurple,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsMiniCard(
            title: locale.t('analytics.mostPopularService'),
            value: _mostPopularService,
            fullWidth: true,
            icon: Icons.star_outline,
            iconBg: AppColors.analyticsPurpleLight,
            iconColor: AppColors.analyticsPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildSlideCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAnalyticsMiniCard({
    required String title,
    required String value,
    bool fullWidth = false,
    IconData? icon,
    Color? iconBg,
    Color? iconColor,
  }) {
    final bg = iconBg ?? AppColors.analyticsPurpleLight;
    final icoColor = iconColor ?? AppColors.analyticsPurple;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: icoColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsCard(LocaleProvider locale) {
    final total = _totalClients;
    final regular = _regularCount;
    final newCount = _newCount;
    final sleepers = _sleepersCount;
    final regularPct = total > 0 ? regular / total : 0.0;
    final newPct = total > 0 ? newCount / total : 0.0;
    final sleepersPct = total > 0 ? sleepers / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Text(
            locale.t('analytics.clients'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.t('analytics.allClients'),
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (regularPct > 0)
                    Expanded(
                      flex: (regularPct * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.analyticsPurpleLight),
                    ),
                  if (newPct > 0)
                    Expanded(
                      flex: (newPct * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.analyticsTealLight),
                    ),
                  if (sleepersPct > 0)
                    Expanded(
                      flex: (sleepersPct * 1000).round().clamp(1, 1000),
                      child: Container(
                        color: AppColors.analyticsSleepersRed.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  if (total == 0)
                    Expanded(child: Container(color: AppColors.neutral200)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendDot(
                AppColors.analyticsPurpleLight,
                locale.t('analytics.regular'),
                locale.t('analytics.regularHint'),
              ),
              _buildLegendDot(
                AppColors.analyticsTealLight,
                locale.t('analytics.new'),
                locale.t('analytics.inPeriod'),
              ),
              _buildLegendDot(
                AppColors.analyticsSleepersRed.withValues(alpha: 0.5),
                locale.t('analytics.sleepers'),
                locale.t('analytics.noVisits3Months'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, String sub) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($sub)',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildIncomeExpensesCard(LocaleProvider locale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
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
        children: [
          Text(
            locale.t('analytics.incomeAndExpenses'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFinanceCard(
                  iconBg: AppColors.analyticsTealLight,
                  icon: Icons.trending_up,
                  iconColor: AppColors.analyticsTeal,
                  title: locale.t('analytics.income'),
                  value: _income,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinanceCard(
                  iconBg: AppColors.analyticsExpensesOrange.withValues(
                    alpha: 0.2,
                  ),
                  icon: Icons.trending_down,
                  iconColor: AppColors.analyticsExpensesOrange,
                  title: locale.t('analytics.expenses'),
                  value: _expenses,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFinanceCard(
            iconBg: Colors.transparent,
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.analyticsPurple,
            useOutline: false,
            title: locale.t('analytics.netProfit'),
            value: _netProfit,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required double value,
    required VoidCallback onTap,
    bool useOutline = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: useOutline
                ? Border.all(
                    color: AppColors.analyticsPurple.withValues(alpha: 0.5),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: useOutline
                      ? Border.all(color: AppColors.analyticsPurple)
                      : null,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatVnd(value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
