import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/device/in_app_browser.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

/// ログイン中のユーザーが管理者か（管理画面の入口を出すかどうか。#20）。
///
/// 端末に控えたユーザー情報なので古いことがあるが、権限はサーバーが判定する
/// （`/api/admin/*` は管理者でなければ 403）。ここでは入口の表示にだけ使う。
bool watchIsAdmin(WidgetRef ref) => switch (ref.watch(authControllerProvider)) {
  AuthAuthenticated(:final user) => user.isAdmin,
  _ => false,
};

/// Web 版の管理画面の URL。[bookId] を渡すとそのタイトルの編集画面。
///
/// 管理画面は Web 版（Nuxt）の中のページで、本番は API と同じオリジンから
/// 配信されているので API のベース URL から組み立てる。
Uri adminPageUrl(AppConfig config, {int? bookId}) =>
    config.resolvePath(bookId == null ? '/admin' : '/admin/books/$bookId');

/// 管理画面を Custom Tabs で開く。開けなければ SnackBar で知らせる。
///
/// 管理画面は Cookie セッションで動くので、アプリのトークンは渡せない
/// （Chrome で Web 版に未ログインなら、開いた先でログインする）。
Future<void> openAdminPage(
  BuildContext context,
  WidgetRef ref, {
  int? bookId,
}) async {
  final url = adminPageUrl(ref.read(appConfigProvider), bookId: bookId);
  final opened = await ref.read(inAppBrowserProvider).open(url);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('管理画面を開けませんでした。ブラウザを確認してください。')));
}
