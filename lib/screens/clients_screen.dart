import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/booking.dart';
import '../../models/client_summary.dart';
import '../../services/auth_service.dart';
import '../../services/cache/bookings_cache.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/clients/client_list_tile.dart';
import '../../widgets/clients/clients_filter_chip.dart';
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
      final salon = await context.read<SalonCache>().getSalon(token);
      final bookings = salon != null
          ? await context.read<BookingsCache>().getBookings(token)
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

  List<ClientSummary> get _uniqueClients {
    final map = <String, ClientSummary>{};
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

      map[key] = ClientSummary(
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

  List<ClientSummary> get _filteredClients {
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
        centerTitle: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ClientsFilterChip(
                  label: 'Все',
                  isSelected: _filter == ClientFilter.all,
                  onTap: () => setState(() => _filter = ClientFilter.all),
                ),
                const SizedBox(width: 8),
                ClientsFilterChip(
                  label: 'Спящие',
                  isSelected: _filter == ClientFilter.sleepers,
                  onTap: () => setState(() => _filter = ClientFilter.sleepers),
                ),
                const SizedBox(width: 8),
                ClientsFilterChip(
                  label: 'Белый список',
                  isSelected: _filter == ClientFilter.whiteList,
                  onTap: () => setState(() => _filter = ClientFilter.whiteList),
                ),
                const SizedBox(width: 8),
                ClientsFilterChip(
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: clients.length,
                    itemBuilder: (context, i) {
                      final c = clients[i];
                      return ClientListTile(
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
