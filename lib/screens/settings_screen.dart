import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/salon.dart';
import '../../services/auth_service.dart';
import '../../services/cache/salon_cache.dart';
import '../../services/dashboard_api_service.dart';
import '../../widgets/address_picker_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _salonFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _salonNameController = TextEditingController();
  final _salonDescriptionController = TextEditingController();
  final _salonAddressController = TextEditingController();
  final _salonPhoneController = TextEditingController();
  final _salonEmailController = TextEditingController();
  final _salonWebsiteController = TextEditingController();
  final _salonInstagramController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  Salon? _salon;
  bool _salonLoading = true;
  bool _salonSaving = false;
  double? _salonLat;
  double? _salonLon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillProfileFromUser();
      _loadSalon();
    });
  }

  void _fillProfileFromUser() {
    final user = context.read<AuthService>().user;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _loadSalon() async {
    final token = context.read<AuthService>().accessToken;
    if (token == null) {
      setState(() => _salonLoading = false);
      return;
    }
    try {
      final salon = await context.read<SalonCache>().getSalon(token);
      if (!mounted) return;
      setState(() {
        _salon = salon;
        _salonLoading = false;
      });
      _fillSalonFromData();
    } catch (_) {
      if (!mounted) return;
      setState(() => _salonLoading = false);
    }
  }

  void _fillSalonFromData() {
    final s = _salon;
    if (s == null) return;
    _salonNameController.text = s.name ?? '';
    _salonDescriptionController.text = s.description ?? '';
    _salonAddressController.text = s.address ?? '';
    _salonPhoneController.text = s.phone ?? '';
    _salonEmailController.text = s.email ?? '';
    _salonWebsiteController.text = s.website ?? '';
    _salonInstagramController.text = s.instagram ?? '';
    _salonLat = s.latitude;
    _salonLon = s.longitude;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthService>().user;
    if (user != null && _nameController.text.isEmpty && _nameController.text != (user.name ?? '')) {
      _nameController.text = user.name ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _salonNameController.dispose();
    _salonDescriptionController.dispose();
    _salonAddressController.dispose();
    _salonPhoneController.dispose();
    _salonEmailController.dispose();
    _salonWebsiteController.dispose();
    _salonInstagramController.dispose();
    super.dispose();
  }

  Future<void> _saveSalon() async {
    if (!(_salonFormKey.currentState?.validate() ?? false)) return;
    final name = _salonNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название салона')),
      );
      return;
    }
    final token = context.read<AuthService>().accessToken;
    if (token == null) return;
    final hadSalon = _salon != null;
    setState(() => _salonSaving = true);
    try {
      final payload = <String, dynamic>{
        'name': name,
        'description': _salonDescriptionController.text.trim(),
        'address': _salonAddressController.text.trim(),
        'phone': _salonPhoneController.text.trim(),
        'email': _salonEmailController.text.trim(),
        'website': _salonWebsiteController.text.trim(),
        'instagram': _salonInstagramController.text.trim(),
      };
      if (_salonLat != null && _salonLon != null) {
        payload['latitude'] = _salonLat;
        payload['longitude'] = _salonLon;
      }
      Salon result;
      if (hadSalon) {
        if (_salon!.workingHours != null) payload['workingHours'] = _salon!.workingHours;
        if (_salon!.reminderSettings != null) payload['reminderSettings'] = _salon!.reminderSettings;
        result = await DashboardApiService.updateCurrentSalon(token, payload);
      } else {
        result = await DashboardApiService.createCurrentSalon(token, payload);
      }
      if (!mounted) return;
      context.read<SalonCache>().invalidate();
      setState(() {
        _salon = result;
        _salonSaving = false;
      });
      _fillSalonFromData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hadSalon ? 'Салон обновлён' : 'Салон создан')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _salonSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSavingProfile = true);
    final auth = context.read<AuthService>();
    final result = await auth.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSavingProfile = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль обновлён')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Ошибка обновления профиля')),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    final newPwd = _newPasswordController.text;
    if (newPwd != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }
    if (newPwd.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть не менее 8 символов')),
      );
      return;
    }
    setState(() => _isSavingPassword = true);
    final auth = context.read<AuthService>();
    final result = await auth.updatePassword(newPwd);
    if (!mounted) return;
    setState(() {
      _isSavingPassword = false;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль изменён')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Ошибка смены пароля')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthService>();
    final result = await auth.deleteAccount();
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Не удалось удалить аккаунт')),
      );
    }
  }

  InputDecoration _inputDecoration({required String hint, bool alignLabelWithHint = false}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.backgroundPrimary,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderPrimary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить аккаунт'),
        content: const Text(
          'Вы уверены, что хотите удалить аккаунт? Это действие необратимо. Все данные будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAccount();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error600),
            child: const Text('Удалить аккаунт'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    const pageBg = Color(0xFFF8F9FA);
    const maxContentWidth = 680.0;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Заголовок блока «Настройки профиля»
                    const Center(
                      child: Text(
                        'Настройки профиля',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Укажите детали о вашем салоне, включая название, описание, адрес, контактную информацию, фотографии и часы работы.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Секции салона в одной форме
                    _salonLoading
                        ? _SectionCard(
                            title: 'Основная информация',
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        : Form(
                            key: _salonFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SectionCard(
                                  title: 'Основная информация',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _labeledField(
                                        label: 'Название салона',
                                        child: TextFormField(
                                          controller: _salonNameController,
                                          decoration: _inputDecoration(hint: 'Введите название'),
                                          textCapitalization: TextCapitalization.words,
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _labeledField(
                                        label: 'Описание',
                                        child: TextFormField(
                                          controller: _salonDescriptionController,
                                          decoration: _inputDecoration(hint: 'Опишите ваш салон', alignLabelWithHint: true),
                                          maxLines: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _labeledField(
                                        label: 'Адрес',
                                        child: InkWell(
                                          onTap: () async {
                                            await AddressPickerModal.show(
                                              context,
                                              initialAddress: _salonAddressController.text,
                                              initialLat: _salonLat,
                                              initialLon: _salonLon,
                                              onSelect: (address, lat, lon) {
                                                setState(() {
                                                  _salonAddressController.text = address;
                                                  _salonLat = lat;
                                                  _salonLon = lon;
                                                });
                                              },
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: InputDecorator(
                                            decoration: _inputDecoration(hint: 'Введите адрес').copyWith(
                                              suffixIcon: Icon(Icons.location_on_outlined, size: 20, color: AppColors.textSecondary),
                                            ),
                                            child: Text(
                                              _salonAddressController.text.isEmpty
                                                  ? ''
                                                  : _salonAddressController.text,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: _salonAddressController.text.isEmpty
                                                    ? AppColors.textSecondary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        height: 44,
                                        child: FilledButton(
                                          onPressed: _salonSaving ? null : _saveSalon,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary500,
                                          ),
                                          child: _salonSaving
                                              ? const SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(_salon == null ? 'Добавить салон' : 'Сохранить'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _SectionCard(
                            title: 'Контактная информация',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _labeledField(
                                  label: 'Телефон салона',
                                  child: TextFormField(
                                    controller: _salonPhoneController,
                                    decoration: _inputDecoration(hint: 'Введите телефон'),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _labeledField(
                                  label: 'Email салона',
                                  child: TextFormField(
                                    controller: _salonEmailController,
                                    decoration: _inputDecoration(hint: 'Введите email'),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _labeledField(
                                  label: 'Сайт',
                                  child: TextFormField(
                                    controller: _salonWebsiteController,
                                    decoration: _inputDecoration(hint: 'https://'),
                                    keyboardType: TextInputType.url,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _labeledField(
                                  label: 'Instagram',
                                  child: TextFormField(
                                    controller: _salonInstagramController,
                                    decoration: _inputDecoration(hint: '@username'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                                ],
                              ),
                            ),
                    const SizedBox(height: 24),

                // Настройки аккаунта
                Text(
                  'Настройки аккаунта',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Персональная информация
                _SectionCard(
                  title: 'Персональные данные',
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Имя',
                            hintText: 'Введите имя',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: ValueKey('email_${user.email}'),
                          initialValue: user.email,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: AppColors.backgroundTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Email нельзя изменить.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Телефон',
                            hintText: 'Введите телефон',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _isSavingProfile ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                            ),
                            child: _isSavingProfile
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Безопасность — смена пароля
                _SectionCard(
                  title: 'Безопасность',
                  child: Form(
                    key: _passwordFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Новый пароль',
                            hintText: 'Минимум 8 символов',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 8) {
                              return 'Не менее 8 символов';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Подтвердите пароль',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_newPasswordController.text.isNotEmpty &&
                                v != _newPasswordController.text) {
                              return 'Пароли не совпадают';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _isSavingPassword ? null : _changePassword,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                            ),
                            child: _isSavingPassword
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Сменить пароль'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Опасная зона
                _SectionCard(
                  title: 'Опасная зона',
                  titleColor: AppColors.error600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'После удаления аккаунта восстановление невозможно. Все данные будут удалены.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _showDeleteAccountDialog,
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: const Text('Удалить аккаунт'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error600,
                          side: const BorderSide(color: AppColors.error600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Выход
                OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary500,
                    side: const BorderSide(color: AppColors.primary500),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.titleColor,
  });

  final String title;
  final Widget child;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPrimary),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: titleColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
