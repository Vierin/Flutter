import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/service_item.dart';
import '../../services/auth_service.dart';
import '../../services/cache/services_staff_cache.dart';
import '../../services/staff_api_service.dart';
import '../../services/services_api_service.dart';
import '../../utils/show_api_error.dart';

/// Полноэкранная форма добавления сотрудника (как на вебе: имя, email, телефон, выбор услуг).
class AddStaffScreen extends StatefulWidget {
  final String salonId;

  const AddStaffScreen({super.key, required this.salonId});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  List<ServiceItem> _services = [];
  final List<String> _selectedServiceIds = [];
  bool _loadingServices = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      if (mounted) setState(() => _loadingServices = false);
      return;
    }
    try {
      final list = await ServicesApiService.getBySalon(token, widget.salonId);
      if (mounted) setState(() {
        _services = list;
        _loadingServices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Введите имя';
        _saving = false;
      });
      return;
    }
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      setState(() => _saving = false);
      return;
    }
    try {
      final created = await StaffApiService.create(
        token,
        salonId: widget.salonId,
        name: name,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        serviceIds:
            _selectedServiceIds.isEmpty ? null : List.from(_selectedServiceIds),
      );
      if (!mounted) return;
      if (created != null) {
        context.read<ServicesStaffCache>().invalidateStaff(widget.salonId);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Сотрудник добавлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'Не удалось добавить';
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
        showApiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('Добавить сотрудника'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Имя *',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.backgroundPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.backgroundPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.backgroundPrimary,
              ),
            ),
            if (_services.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Услуги (опционально)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите услуги, которые выполняет сотрудник. Пусто = все услуги.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingServices)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                      color: AppColors.primary500, strokeWidth: 2),
                ))
              else
                ..._services.map((s) {
                  final selected = _selectedServiceIds.contains(s.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedServiceIds.add(s.id);
                        } else {
                          _selectedServiceIds.remove(s.id);
                        }
                      });
                    },
                    title: Text(
                      s.displayName,
                      style: const TextStyle(fontSize: 14),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Добавить сотрудника'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
