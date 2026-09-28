import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/feature_placeholder.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

/// マイページ（統計・設定入口）。
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.name.isEmpty ? 'ユーザー' : user.name),
              subtitle: user.email == null ? null : Text(user.email!),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (user.isAdmin) const Chip(label: Text('管理者')),
                  if (user.safeMode) const Chip(label: Text('セーフモード')),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(
            height: 220,
            child: FeaturePlaceholder(title: '読書統計 / ストレージ設定', issue: 13),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        content: const Text('この端末にダウンロードしたコミックと読書進捗は削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // ダイアログを閉じる間に画面が破棄されていることがある。
    if (!context.mounted) return;

    try {
      await ref.read(authControllerProvider.notifier).logout();
    } on Object {
      // 端末内データの削除に失敗した場合など。黙って失敗させない。
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトに失敗しました。もう一度お試しください。')),
      );
    }
  }
}
