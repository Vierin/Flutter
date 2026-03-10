import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_api_service.dart';
import 'client_detail_screen.dart';

enum ClientFilter { all, sleepers, whiteList, blocked }

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ClientFilter _filter = ClientFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final token = context.read<AuthService>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final salon = await DashboardApiService.getCurrentSalon(token);
      final bookings = salon != null
          ? await DashboardApiService.getOwnerBookings(token)
          : <Booking>[];
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookings = [];
          _isLoading = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<_ClientItem> get _uniqueClients {
    final map = <String, _ClientItem>{};
    final now = DateTime.now();
    final threeMonthsAgo = now.subtract(const Duration(days: 90));

    for (final b in _bookings) {
      final u = b.user;
      final key = (u?.email ?? u?.phone ?? u?.name ?? '').trim();
      if (key.isEmpty) continue;

      final existing = map[key];
      final latestVisit =
          (existing == null || b.dateTime.isAfter(existing.lastVisit))
          ? b.dateTime
          : existing.lastVisit;

      map[key] = _ClientItem(
        key: key,
        name: u?.name ?? u?.email ?? 'Клиент',
        email: u?.email,
        phone: u?.phone,
        lastVisit: latestVisit,
        isSleeper: latestVisit.isBefore(threeMonthsAgo),
      );
    }
    final items = map.values.toList();
    items.sort((a, b) => b.lastVisit.compareTo(a.lastVisit));
    return items;
  }

  List<_ClientItem> get _filteredClients {
    var list = _uniqueClients;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        return (c.name.toLowerCase().contains(q)) ||
            (c.email?.toLowerCase().contains(q) ?? false) ||
            (c.phone?.contains(q) ?? false);
      }).toList();
    }

    switch (_filter) {
      case ClientFilter.all:
        break;
      case ClientFilter.sleepers:
        list = list.where((c) => c.isSleeper).toList();
        break;
      case ClientFilter.whiteList:
      case ClientFilter.blocked:
        list = [];
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Клиенты',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text('Информация о клиентах — в разработке'),
                ),
              );
            },
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'i',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Все',
                  isSelected: _filter == ClientFilter.all,
                  onTap: () => setState(() => _filter = ClientFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Спящие',
                  isSelected: _filter == ClientFilter.sleepers,
                  onTap: () => setState(() => _filter = ClientFilter.sleepers),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Белый список',
                  isSelected: _filter == ClientFilter.whiteList,
                  onTap: () => setState(() => _filter = ClientFilter.whiteList),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Заблокированные',
                  isSelected: _filter == ClientFilter.blocked,
                  onTap: () => setState(() => _filter = ClientFilter.blocked),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary500,
                    ),
                  )
                : clients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.neutral300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == ClientFilter.all && _searchQuery.isEmpty
                              ? 'Нет клиентов'
                              : 'Ничего не найдено',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: clients.length,
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      return _ClientListTile(
                        name: c.name,
                        subtitle: c.email ?? c.phone ?? '',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(
                              clientKey: c.key,
                              name: c.name,
                              email: c.email,
                              phone: c.phone,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Material(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Добавление клиента — в разработке'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Добавить клиента',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
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

class _ClientItem {
  final String key;
  final String name;
  final String? email;
  final String? phone;
  final DateTime lastVisit;
  final bool isSleeper;

  _ClientItem({
    required this.key,
    required this.name,
    this.email,
    this.phone,
    required this.lastVisit,
    required this.isSleeper,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary100 : AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary500.withValues(alpha: 0.5)
                  : AppColors.borderPrimary,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary500 : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientListTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _ClientListTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderPrimary),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary100,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
