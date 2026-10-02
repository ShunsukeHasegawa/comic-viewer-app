import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/push_notifications_controller.dart';
import '../domain/push_message.dart';
import '../domain/push_status.dart';

/// マイページの「新刊通知」（#14）。
///
/// 使えない / 断られた / 登録に失敗した、を黙らずにその場で出す（設定が ON の
/// まま通知が来ない理由を利用者が見分けられるように）。
class PushNotificationSettings extends ConsumerStatefulWidget {
  const PushNotificationSettings({super.key});

  static const switchKey = Key('push-notification-switch');
  static const testButtonKey = Key('push-notification-test');
  static const openSettingsKey = Key('push-notification-open-settings');

  @override
  ConsumerState<PushNotificationSettings> createState() =>
      _PushNotificationSettingsState();
}

class _PushNotificationSettingsState
    extends ConsumerState<PushNotificationSettings> {
  /// 切り替え / テスト送信の最中（連打で重ねない）。
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(pushNotificationsProvider);
    final available = status.availability == PushAvailability.available;
    final enabled = status.enabled ?? false;
    final denied =
        enabled && available && status.permission == PushPermission.denied;
    final (subtitle, isWarning) = _subtitleOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: PushNotificationSettings.switchKey,
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('新刊通知'),
          subtitle: Text(
            subtitle,
            style: isWarning ? TextStyle(color: theme.colorScheme.error) : null,
          ),
          value: available && enabled,
          onChanged: !available || status.enabled == null || _busy
              ? null
              : _toggle,
        ),
        if (denied)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: PushNotificationSettings.openSettingsKey,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('通知の設定を開く'),
                onPressed: _openSystemSettings,
              ),
            ),
          ),
        ListTile(
          key: PushNotificationSettings.testButtonKey,
          leading: const Icon(Icons.send_outlined),
          title: const Text('テスト通知を送る'),
          subtitle: const Text('この端末に通知が届くか確かめます（ログイン中の全端末に届きます）'),
          enabled: available && enabled && status.registered && !_busy,
          onTap: _sendTest,
        ),
      ],
    );
  }

  /// 補足の文言と、警告として目立たせるか。
  static (String, bool) _subtitleOf(PushStatus status) {
    switch (status.availability) {
      case PushAvailability.checking:
        return ('確認しています…', false);
      case PushAvailability.unavailable:
        return ('このビルドではプッシュ通知を使えません（Firebase が未設定）', true);
      case PushAvailability.available:
        break;
    }
    if (status.enabled == null) return ('読み込んでいます…', false);
    if (status.enabled == false) {
      // OFF にしたのに止めきれていない（圏外で解除も破棄もできなかった）。
      // 「通知しません」と出すと、届き続ける通知の理由が分からなくなる。
      if (status.failure case final failure?) return (failure, true);
      return ('お気に入りの新刊を通知しません', false);
    }
    if (status.permission == PushPermission.denied) {
      return ('通知が許可されていません。端末の設定で許可してください', true);
    }
    if (status.failure case final failure?) {
      return ('登録できませんでした: $failure（スイッチを入れ直すか、しばらくしてから開き直すともう一度試します）', true);
    }
    if (status.registered) return ('お気に入りのタイトルに新しい巻が出たら通知します', false);
    return ('登録しています…', false);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(pushNotificationsProvider.notifier).setEnabled(value);
    } on Object catch (error) {
      if (!mounted) return;
      _showFailure(
        ScaffoldMessenger.maybeOf(context),
        value ? '新刊通知の登録' : '新刊通知の解除',
        error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTest() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(pushNotificationsProvider.notifier).sendTest();
      messenger?.showSnackBar(
        const SnackBar(content: Text('テスト通知を送りました。届くまで少しかかることがあります。')),
      );
    } on Object catch (error) {
      _showFailure(messenger, 'テスト通知の送信', error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSystemSettings() async {
    try {
      await ref.read(pushNotificationsProvider.notifier).openSystemSettings();
    } on Object catch (error) {
      if (!mounted) return;
      _showFailure(ScaffoldMessenger.maybeOf(context), '通知の設定画面の表示', error);
    }
  }

  static void _showFailure(
    ScaffoldMessengerState? messenger,
    String what,
    Object error,
  ) {
    messenger?.showSnackBar(
      SnackBar(content: Text('$whatに失敗しました: ${describePushError(error)}')),
    );
  }
}
