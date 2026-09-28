import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// 未知の URL / 不正なパスパラメータに対する画面。
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({this.location, super.key});

  /// 解決できなかった URL（デバッグ用に表示する）。
  final String? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ページが見つかりません')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('お探しのページは見つかりませんでした', style: theme.textTheme.titleMedium),
              if (location case final location?) ...[
                const SizedBox(height: 4),
                Text(
                  location,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.library),
                child: const Text('ライブラリへ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
