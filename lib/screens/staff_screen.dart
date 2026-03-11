import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/salon.dart';
import '../../models/service_item.dart';
import '../../models/staff_member.dart';
import '../../services/auth_service.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/cache/services_staff_cache.dart';
import '../../services/staff_api_service.dart';
import 'add_staff_screen.dart';

enum StaffSort { nameAz, nameZa }

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  Salon? _salon;
  List<StaffMember> _staff = [];
  bool _isLoading = false;
  bool _isActionLoading = false;
  StaffSort _sort = StaffSort.nameAz;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final staff = salon != null
          ? await context.read<ServicesStaffCache>().getStaffForSalon(
              token,
              salon.id,
            )
          : <StaffMember>[];
      if (mounted) {
        setState(() {
          _salon = salon;
          _staff = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteStaff(StaffMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сотрудника'),
        content: Text('Удалить ${member.name}?'),
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
      final ok = await StaffApiService.delete(token, member.id);
      if (!mounted) return;
      if (ok) {
        context.read<ServicesStaffCache>().invalidateStaff(_salon?.id);
        await _loadData();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Сотрудник удалён'),
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
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _openAddStaff() {
    final salonId = _salon?.id;
    if (salonId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => AddStaffScreen(salonId: salonId)),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  List<StaffMember> get _sortedStaff {
    final list = List<StaffMember>.from(_staff);
    list.sort((a, b) {
      switch (_sort) {
        case StaffSort.nameAz:
          return a.name.compareTo(b.name);
        case StaffSort.nameZa:
          return b.name.compareTo(a.name);
      }
    });
    return list;
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Сортировка',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              title: const Text('По имени (А–Я)'),
              leading: Radio<StaffSort>(
                value: StaffSort.nameAz,
                groupValue: _sort,
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                setState(() => _sort = StaffSort.nameAz);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('По имени (Я–А)'),
              leading: Radio<StaffSort>(
                value: StaffSort.nameZa,
                groupValue: _sort,
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                setState(() => _sort = StaffSort.nameZa);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditDialog(StaffMember member) {
    final nameController = TextEditingController(text: member.name);
    final emailController = TextEditingController(text: member.email ?? '');
    final phoneController = TextEditingController(text: member.phone ?? '');
    final selectedServiceIds = <String>[];
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.92).clamp(320.0, 560.0);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxHeight: 600),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Редактировать сотрудника',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Полное имя *',
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
                              hintText: 'Полное имя',
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
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
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
                            'Телефон',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Телефон',
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
                            'Услуги (необязательно)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final token = context
                                  .read<AuthService>()
                                  .accessToken;
                              if (token == null) return;
                              final list = await context
                                  .read<ServicesStaffCache>()
                                  .getServicesForSalon(token, member.salonId);
                              if (!ctx.mounted) return;
                              final result =
                                  await showModalBottomSheet<List<String>>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (ctx2) =>
                                        _StaffServicesPickerSheet(
                                          services: list,
                                          selectedIds: List.from(
                                            selectedServiceIds,
                                          ),
                                          onDone: (ids) =>
                                              Navigator.pop(ctx2, ids),
                                        ),
                                  );
                              if (result != null && ctx.mounted) {
                                selectedServiceIds
                                  ..clear()
                                  ..addAll(result);
                                setDialogState(() {});
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                hintText: 'Все услуги',
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
                                suffixIcon: const Icon(
                                  Icons.keyboard_arrow_down,
                                ),
                              ),
                              child: Text(
                                selectedServiceIds.isEmpty
                                    ? 'Все услуги'
                                    : '${selectedServiceIds.length} услуг выбрано',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Выберите услуги, которые может выполнять этот сотрудник.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(
                                      color: AppColors.borderPrimary,
                                    ),
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                  ),
                                  child: const Text('Отмена'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        const SnackBar(
                                          content: Text('Введите полное имя'),
                                        ),
                                      );
                                      return;
                                    }
                                    final token = context
                                        .read<AuthService>()
                                        .accessToken;
                                    Navigator.pop(ctx);
                                    if (token == null) return;
                                    setState(() => _isActionLoading = true);
                                    try {
                                      final updated =
                                          await StaffApiService.update(
                                            token,
                                            member.id,
                                            name: name,
                                            email:
                                                emailController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : emailController.text.trim(),
                                            phone:
                                                phoneController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : phoneController.text.trim(),
                                            serviceIds:
                                                selectedServiceIds.isEmpty
                                                ? null
                                                : List.from(selectedServiceIds),
                                          );
                                      if (!mounted) return;
                                      if (updated != null) {
                                        context
                                            .read<ServicesStaffCache>()
                                            .invalidateStaff(_salon?.id);
                                        await _loadData();
                                        ScaffoldMessenger.maybeOf(
                                          context,
                                        )?.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Изменения сохранены',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.maybeOf(
                                          context,
                                        )?.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Не удалось сохранить',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.maybeOf(
                                          context,
                                        )?.showSnackBar(
                                          SnackBar(
                                            content: Text('Ошибка: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _isActionLoading = false,
                                        );
                                      }
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary500,
                                    minimumSize: const Size(0, 48),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                  ),
                                  child: const Text('Сохранить'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _StaffServicesPickerSheet({
    required List<ServiceItem> services,
    required List<String> selectedIds,
    required void Function(List<String>) onDone,
  }) {
    return _StaffServicesPickerSheetBody(
      services: services,
      initialSelectedIds: selectedIds,
      onDone: onDone,
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
          'Персонал',
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
                child: Text(
                  'Сначала настройте салон',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary500,
              child: _staff.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Пока нет сотрудников',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте первого сотрудника',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _sortedStaff.length,
                      itemBuilder: (context, index) {
                        final member = _sortedStaff[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (member.email != null &&
                                    member.email!.isNotEmpty)
                                  Text(
                                    member.email!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (member.phone != null &&
                                    member.phone!.isNotEmpty)
                                  Text(
                                    member.phone!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: _isActionLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _openEditDialog(member),
                                        color: AppColors.primary500,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteStaff(member),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: _salon != null && !_isLoading
          ? FloatingActionButton(
              onPressed: _openAddStaff,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _StaffServicesPickerSheetBody extends StatefulWidget {
  const _StaffServicesPickerSheetBody({
    required this.services,
    required this.initialSelectedIds,
    required this.onDone,
  });
  final List<ServiceItem> services;
  final List<String> initialSelectedIds;
  final void Function(List<String>) onDone;

  @override
  State<_StaffServicesPickerSheetBody> createState() =>
      _StaffServicesPickerSheetBodyState();
}

class _StaffServicesPickerSheetBodyState
    extends State<_StaffServicesPickerSheetBody> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Услуги сотрудника',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.services.length,
                itemBuilder: (context, i) {
                  final s = widget.services[i];
                  final isSelected = _selected.contains(s.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(s.id);
                        } else {
                          _selected.remove(s.id);
                        }
                      });
                    },
                    title: Text(
                      s.displayName,
                      style: const TextStyle(fontSize: 15),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => widget.onDone(_selected.toList()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
