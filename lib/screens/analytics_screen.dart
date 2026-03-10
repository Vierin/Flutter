import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../utils/currency_format.dart';

// Analytics-specific colors (purple/teal theme from design)
class _AnalyticsColors {
  static const purple = Color(0xFF9C27B0);
  static const purpleLight = Color(0xFFE1BEE7);
  static const teal = Color(0xFF14B8A6);
  static const tealLight = Color(0xFF99F6E4);
  static const sleepersRed = Color(0xFFEF4444);
  static const expensesOrange = Color(0xFFFF9800);
}

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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: _AnalyticsColors.purple),
        ),
        child: child!,
      ),
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
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Аналитика',
                style: TextStyle(
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
                    'Период:',
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
              // Slider: Доходы и расходы | Sales | Services
              SizedBox(
                height: 340,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildIncomeExpensesSlide(),
                    _buildSalesSlide(),
                    _buildServicesSlide(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentPage
                            ? _AnalyticsColors.purple
                            : AppColors.neutral300,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              _buildClientsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpensesSlide() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _buildIncomeExpensesCard(),
    );
  }

  Widget _buildSalesSlide() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Sales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsMiniCard(
                  title: 'Total visits',
                  value: '$_totalVisits',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsMiniCard(
                  title: 'Average client check',
                  value: formatVnd(_averageClientCheck),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAnalyticsMiniCard(
            title: 'Total sales',
            value: formatVnd(_totalSales),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSlide() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _buildAnalyticsMiniCard(
            title: 'Total services',
            value: '$_totalServices',
            fullWidth: true,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsMiniCard(
            title: 'Most popular service',
            value: _mostPopularService,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMiniCard({
    required String title,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsCard() {
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
          const Text(
            'Клиенты',
            style: TextStyle(
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
                'Все клиенты',
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
                      child: Container(color: _AnalyticsColors.purpleLight),
                    ),
                  if (newPct > 0)
                    Expanded(
                      flex: (newPct * 1000).round().clamp(1, 1000),
                      child: Container(color: _AnalyticsColors.tealLight),
                    ),
                  if (sleepersPct > 0)
                    Expanded(
                      flex: (sleepersPct * 1000).round().clamp(1, 1000),
                      child: Container(
                        color: _AnalyticsColors.sleepersRed.withValues(
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
                _AnalyticsColors.purpleLight,
                'Регулярные',
                '2+ визитов за 3 мес.',
              ),
              _buildLegendDot(
                _AnalyticsColors.tealLight,
                'Новые',
                'За выбранный период',
              ),
              _buildLegendDot(
                _AnalyticsColors.sleepersRed.withValues(alpha: 0.5),
                'Спящие',
                'Без визитов 3 мес.',
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

  Widget _buildIncomeExpensesCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Доходы и расходы',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Material(
                color: _AnalyticsColors.purpleLight,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.add,
                      color: _AnalyticsColors.purple,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFinanceCard(
                  iconBg: _AnalyticsColors.tealLight,
                  icon: Icons.trending_up,
                  iconColor: _AnalyticsColors.teal,
                  title: 'Доходы',
                  value: _income,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinanceCard(
                  iconBg: _AnalyticsColors.expensesOrange.withValues(
                    alpha: 0.2,
                  ),
                  icon: Icons.trending_down,
                  iconColor: _AnalyticsColors.expensesOrange,
                  title: 'Расходы',
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
            iconColor: _AnalyticsColors.purple,
            useOutline: true,
            title: 'Чистая прибыль',
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
                    color: _AnalyticsColors.purple.withValues(alpha: 0.5),
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
                      ? Border.all(color: _AnalyticsColors.purple)
                      : null,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
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
