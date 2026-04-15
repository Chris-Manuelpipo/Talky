// lib/core/widgets/country_picker.dart

import 'package:flutter/material.dart';

class CountryPicker extends StatelessWidget {
  final String selectedCountryCode;
  final ValueChanged<String> onCountrySelected;
  final bool isReadOnly;
  final String? readOnlyCountryCode;

  const CountryPicker({
    super.key,
    required this.selectedCountryCode,
    required this.onCountrySelected,
    this.isReadOnly = false,
    this.readOnlyCountryCode,
  });

  static const List<Map<String, String>> countryCodes = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroun'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'États-Unis'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'Royaume-Uni'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Allemagne'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'Espagne'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'Italie'},
    {'code': '+212', 'flag': '🇲🇦', 'name': 'Maroc'},
    {'code': '+221', 'flag': '🇸🇳', 'name': 'Sénégal'},
    {'code': '+225', 'flag': '🇨🇮', 'name': "Côte d'Ivoire"},
    {'code': '+243', 'flag': '🇨🇩', 'name': 'RD Congo'},
  ];

  static Map<String, String> getCountryByCode(String code) {
    return countryCodes.firstWhere(
      (c) => c['code'] == code,
      orElse: () => countryCodes.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCode = readOnlyCountryCode ?? selectedCountryCode;
    final country = getCountryByCode(displayCode);

    if (isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country['flag']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              displayCode,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country['flag']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              displayCode,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryPickerSheet(
        selectedCode: selectedCountryCode,
        onSelect: (code) {
          onCountrySelected(code);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onSelect;

  const _CountryPickerSheet({
    required this.selectedCode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sélectionner un pays',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: CountryPicker.countryCodes.length,
              itemBuilder: (context, index) {
                final country = CountryPicker.countryCodes[index];
                final isSelected = country['code'] == selectedCode;
                return ListTile(
                  leading: Text(
                    country['flag']!,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(country['name']!),
                  trailing: Text(
                    country['code']!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () => onSelect(country['code']!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
