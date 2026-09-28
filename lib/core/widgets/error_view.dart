import 'package:flutter/material.dart';

import '../network/api_exception.dart';

/// エラーをユーザー向けの文言にする。
String apiErrorMessage(Object error) => switch (error) {
  final ApiException error => error.message,
  _ => '読み込みに失敗しました。',
};

/// 端末内の操作（保存 / 削除）のエラー文言。
///
/// DB やファイルの失敗は [ApiException] ではないので、[apiErrorMessage] に渡すと
/// 一律「読み込みに失敗しました。」になり、何をしようとして失敗したのか分からない。
String localErrorMessage(Object error) => switch (error) {
  final ApiException error => error.message,
  _ => '端末内のデータを処理できませんでした。',
};

/// 読み込み失敗の表示（再試行つき）。
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  /// ユーザーに見せる文言。[ApiException] はそのメッセージを使う。
  String get message => apiErrorMessage(error);

  /// オフラインらしさ（アイコンの出し分け）。
  bool get isOffline =>
      error is NetworkException || error is ApiTimeoutException;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off_outlined : Icons.error_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry case final onRetry?) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 一覧が空のときの表示。
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (actionLabel case final label? when onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 表示中の内容を残したまま再取得が失敗したことを知らせる。
///
/// エラー表示に切り替わらない（＝古い内容が見えたまま）ケースで、
/// 「更新できた」と誤解させないために使う。
void showRefreshFailure(
  BuildContext context,
  Object error, {
  required String what,
}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('$what を更新できませんでした: ${apiErrorMessage(error)}')),
  );
}

/// 保存 / 削除ができなかったことを知らせる。
///
/// [showRefreshFailure] は「表示中の内容を残したまま**再取得**が失敗した」用。
/// 削除や保存に流用すると「更新できませんでした」となり、消えたのか消えていないのかが
/// 読み取れない（ユーザーは削除できたと誤解しうる）。
void showActionFailure(
  BuildContext context,
  Object error, {
  required String what,
}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('$whatに失敗しました: ${localErrorMessage(error)}')),
  );
}
