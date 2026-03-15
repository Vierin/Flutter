import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/salon.dart';
import '../../utils/currency_format.dart';
import '../../models/service_item.dart';
import '../../services/auth_service.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/cache/services_staff_cache.dart';
import '../../services/services_api_service.dart';
import '../../utils/show_api_error.dart';

enum ServicesSort {
  nameAz,
  nameZa,
  priceAsc,
  priceDesc,
  durationAsc,
  durationDesc,
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  Salon? _salon;
  List<ServiceItem> _services = [];
  bool _isLoading = true;
  bool _isActionLoading = false;
  ServicesSort _sort = ServicesSort.nameAz;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedGroup;

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
      if (mounted) {
        setState(() {
          _salon = null;
          _services = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final salon = await context.read<SalonCache>().getSalon(token);
      final services = salon != null
          ? await context.read<ServicesStaffCache>().getServicesForSalon(
              token,
              salon.id,
            )
          : <ServiceItem>[];
      if (mounted) {
        setState(() {
          _salon = salon;
          _services = services;
          _isLoading = false;
          if (_selectedCategory != null &&
              !_services.any((s) => s.categoryName == _selectedCategory)) {
            _selectedCategory = null;
          }
          if (_selectedGroup != null &&
              !_services.any((s) => s.groupName == _selectedGroup)) {
            _selectedGroup = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _salon = null;
          _services = [];
          _isLoading = false;
        });
        showApiError(context, e);
      }
    }
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h 0m';
    return '${m}m';
  }

  List<String> get _uniqueCategories {
    final set = <String>{};
    for (final s in _services) {
      final c = s.categoryName;
      if (c != null && c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  List<String> get _uniqueGroups {
    final set = <String>{};
    for (final s in _services) {
      final g = s.groupName;
      if (g != null && g.isNotEmpty) set.add(g);
    }
    return set.toList()..sort();
  }

  List<ServiceItem> get _filteredAndSortedServices {
    var list = List<ServiceItem>.from(_services);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((s) => s.displayName.toLowerCase().contains(q))
          .toList();
    }
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      list = list.where((s) => s.categoryName == _selectedCategory).toList();
    }
    if (_selectedGroup != null && _selectedGroup!.isNotEmpty) {
      list = list.where((s) => s.groupName == _selectedGroup).toList();
    }
    list.sort((a, b) {
      switch (_sort) {
        case ServicesSort.nameAz:
          return a.displayName.compareTo(b.displayName);
        case ServicesSort.nameZa:
          return b.displayName.compareTo(a.displayName);
        case ServicesSort.priceAsc:
          return ((a.price ?? 0) - (b.price ?? 0)).sign.toInt();
        case ServicesSort.priceDesc:
          return ((b.price ?? 0) - (a.price ?? 0)).sign.toInt();
        case ServicesSort.durationAsc:
          return (a.duration ?? 0) - (b.duration ?? 0);
        case ServicesSort.durationDesc:
          return (b.duration ?? 0) - (a.duration ?? 0);
      }
    });
    return list;
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Сортировать по',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              ...ServicesSort.values.map((value) {
                final labels = {
                  ServicesSort.nameAz: 'Имя (А-Я)',
                  ServicesSort.nameZa: 'Имя (Я-А)',
                  ServicesSort.priceAsc: 'Цена (сначала дешевле)',
                  ServicesSort.priceDesc: 'Цена (сначала дороже)',
                  ServicesSort.durationAsc: 'Длительность (короткие)',
                  ServicesSort.durationDesc: 'Длительность (длинные)',
                };
                return ListTile(
                  title: Text(labels[value]!),
                  leading: Radio<ServicesSort>(
                    value: value,
                    groupValue: _sort,
                    onChanged: (v) {
                      if (v != null) setState(() => _sort = v);
                      Navigator.pop(ctx);
                    },
                  ),
                  onTap: () {
                    setState(() => _sort = value);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = null;
      _selectedGroup = null;
    });
  }

  void _showManageGroups() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Управление группами доступно в веб-версии'),
      ),
    );
  }

  Future<void> _deleteService(ServiceItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить услугу'),
        content: Text('Удалить «${item.displayName}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    setState(() => _isActionLoading = true);
    try {
      final ok = await ServicesApiService.delete(token, item.id);
      if (!mounted) return;
      if (ok) {
        context.read<ServicesStaffCache>().invalidateServices(_salon?.id);
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Услуга удалена'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Не удалось удалить'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _openAddDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    final durationController = TextEditingController(text: '30');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить услугу'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Цена (VND) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Длительность (мин) *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Введите название')),
                );
                return;
              }
              final price =
                  double.tryParse(priceController.text.replaceAll(',', '.')) ??
                  0.0;
              final duration = int.tryParse(durationController.text) ?? 30;
              if (price <= 0 || duration <= 0) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Цена и длительность должны быть больше 0'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final token = context.read<AuthService>().accessToken;
              final salonId = _salon?.id;
              if (token == null || salonId == null) return;
              setState(() => _isActionLoading = true);
              try {
                final created = await ServicesApiService.create(
                  token,
                  salonId: salonId,
                  name: name,
                  price: price,
                  duration: duration,
                );
                if (!mounted) return;
                if (created != null) {
                  await _loadData();
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Услуга добавлена'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Не удалось добавить'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) showApiError(context, e);
              } finally {
                if (mounted) setState(() => _isActionLoading = false);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(ServiceItem item) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    final priceController = TextEditingController(
      text: item.price != null ? (item.price!.toStringAsFixed(0)) : '0',
    );
    final durationController = TextEditingController(
      text: (item.duration ?? 30).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Редактировать услугу',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Название услуги',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Название услуги',
                          filled: true,
                          fillColor: AppColors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderPrimary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Описание',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Описание услуги',
                          filled: true,
                          fillColor: AppColors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderPrimary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Категория',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (item.categoryName != null &&
                          item.categoryName!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.categoryName ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {},
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(32, 32),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: Text(
                            'Не выбрано',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Группа услуг (необязательно)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderPrimary,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.groupName ?? 'No group',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: item.groupName != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(8),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Используйте группы для структурирования услуг на странице салона.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Мастера (необязательно)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderPrimary),
                        ),
                        child: Text(
                          'Выберите мастеров',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Выберите мастеров, которые могут выполнять эту услугу.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Длительность (минуты)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderPrimary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Цена (₫)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.backgroundPrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderPrimary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Только числа (например, 50000 для 50k ₫)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Отмена'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  const SnackBar(
                                    content: Text('Введите название услуги'),
                                  ),
                                );
                                return;
                              }
                              final description = descriptionController.text
                                  .trim();
                              final price =
                                  double.tryParse(
                                    priceController.text.replaceAll(',', '.'),
                                  ) ??
                                  item.price ??
                                  0.0;
                              final duration =
                                  int.tryParse(durationController.text) ??
                                  item.duration ??
                                  30;
                              if (price <= 0 || duration <= 0) {
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Цена и длительность должны быть больше 0',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              final token = context
                                  .read<AuthService>()
                                  .accessToken;
                              if (token == null) return;
                              setState(() => _isActionLoading = true);
                              try {
                                final updated = await ServicesApiService.update(
                                  token,
                                  item.id,
                                  name: name,
                                  description: description.isEmpty
                                      ? null
                                      : description,
                                  price: price,
                                  duration: duration,
                                );
                                if (!mounted) return;
                                if (updated != null) {
                                  context
                                      .read<ServicesStaffCache>()
                                      .invalidateServices(_salon?.id);
                                  await _loadData();
                                  ScaffoldMessenger.maybeOf(
                                    context,
                                  )?.showSnackBar(
                                    const SnackBar(
                                      content: Text('Изменения сохранены'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.maybeOf(
                                    context,
                                  )?.showSnackBar(
                                    const SnackBar(
                                      content: Text('Не удалось сохранить'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) showApiError(context, e);
                              } finally {
                                if (mounted)
                                  setState(() => _isActionLoading = false);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                            ),
                            child: const Text('Обновить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.textPrimary,
        ),
        title: const Text(
          'Услуги',
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
        actions: [
          if (_salon != null)
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Сортировка и фильтры',
              onPressed: _isLoading ? null : _showSortMenu,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            )
          : _salon == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Сначала настройте салон',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _loadData,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Повторить'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary500,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Управляйте услугами и ценами вашего салона',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showManageGroups,
                                  icon: const Icon(
                                    Icons.folder_outlined,
                                    size: 20,
                                  ),
                                  label: const Text('Добавить/Удалить группу'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(
                                      color: AppColors.borderPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _isActionLoading
                                    ? null
                                    : _openAddDialog,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Добавить'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Категория',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: const Text('Все категории'),
                                    selected: _selectedCategory == null,
                                    onSelected: (_) =>
                                        setState(() => _selectedCategory = null),
                                    selectedColor: AppColors.primary100,
                                    checkmarkColor: AppColors.primary500,
                                  ),
                                ),
                                ..._uniqueCategories.map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(c),
                                      selected: _selectedCategory == c,
                                      onSelected: (_) =>
                                          setState(() => _selectedCategory = c),
                                      selectedColor: AppColors.primary100,
                                      checkmarkColor: AppColors.primary500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Группа',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: const Text('Все группы'),
                                    selected: _selectedGroup == null,
                                    onSelected: (_) =>
                                        setState(() => _selectedGroup = null),
                                    selectedColor: AppColors.primary100,
                                    checkmarkColor: AppColors.primary500,
                                  ),
                                ),
                                ..._uniqueGroups.map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(g),
                                      selected: _selectedGroup == g,
                                      onSelected: (_) =>
                                          setState(() => _selectedGroup = g),
                                      selectedColor: AppColors.primary100,
                                      checkmarkColor: AppColors.primary500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppColors.borderPrimary,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Поиск',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Поиск по имени...',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _clearFilters,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          AppColors.textPrimary,
                                      side: BorderSide(
                                        color: AppColors.borderPrimary,
                                      ),
                                    ),
                                    child: const Text('Очистить'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_filteredAndSortedServices.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _services.isEmpty
                                  ? 'Пока нет услуг'
                                  : 'Ничего не найдено',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _services.isEmpty
                                  ? 'Добавьте первую услугу'
                                  : 'Измените фильтры',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _filteredAndSortedServices[index];
                          return _ServiceCard(
                            item: item,
                            formatPrice: formatVnd,
                            formatDuration: _formatDuration,
                            isActionLoading: _isActionLoading,
                            onEdit: () => _openEditDialog(item),
                            onDelete: () => _deleteService(item),
                          );
                        }, childCount: _filteredAndSortedServices.length),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.item,
    required this.formatPrice,
    required this.formatDuration,
    required this.isActionLoading,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceItem item;
  final String Function(double?) formatPrice;
  final String Function(int?) formatDuration;
  final bool isActionLoading;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderPrimary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.tagNames.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: item.tagNames.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(item.duration),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        formatPrice(item.price),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isActionLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                    color: AppColors.primary500,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: AppColors.error600,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
