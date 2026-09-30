import 'package:flutter/material.dart';

/// 設定画面のセクション見出し。
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// 補足の文章（セクションの注記）。
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 選択肢を 1 つ選ぶ設定項目。
///
/// [onChanged] が `null` なら選べない（読み込み中 / この端末では使えない）。
class SettingChoiceTile<T> extends StatelessWidget {
  const SettingChoiceTile({
    required this.dropdownKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final Key dropdownKey;
  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final void Function(T value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      enabled: onChanged != null,
      trailing: DropdownButton<T>(
        key: dropdownKey,
        value: value,
        items: [
          for (final candidate in values)
            DropdownMenuItem<T>(
              value: candidate,
              child: Text(labelOf(candidate)),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected == null || selected == value) return;
                onChanged(selected);
              },
      ),
    );
  }
}
