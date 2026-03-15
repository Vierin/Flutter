import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../l10n/app_locales.dart';
import '../l10n/locale_provider.dart';

/// Shared language picker modal: centered card, dimmed barrier, list with checkmark.
/// Optional [onLocaleSelected] (e.g. to re-register push token after change).
void showLanguageSelectorModal(
  BuildContext context,
  LocaleProvider locale, {
  void Function(String code)? onLocaleSelected,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _LanguageSelectorModalContent(
      locale: locale,
      onLocaleSelected: onLocaleSelected,
    ),
  );
}

const Map<String, String> _languageLabels = {
  'en': 'English',
  'ru': 'Русский',
  'vi': 'Tiếng Việt',
};

class _LanguageSelectorModalContent extends StatelessWidget {
  const _LanguageSelectorModalContent({
    required this.locale,
    this.onLocaleSelected,
  });

  final LocaleProvider locale;
  final void Function(String code)? onLocaleSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  locale.t('settings.changeLanguage'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final code in supportedLocaleCodes)
                InkWell(
                  onTap: () async {
                    await locale.setLocale(code);
                    onLocaleSelected?.call(code);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _languageLabels[code] ?? code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: locale.localeCode == code ? FontWeight.w600 : FontWeight.w500,
                              color: locale.localeCode == code ? AppColors.primary500 : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (locale.localeCode == code)
                          Icon(Icons.check_circle, size: 22, color: AppColors.primary500),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
