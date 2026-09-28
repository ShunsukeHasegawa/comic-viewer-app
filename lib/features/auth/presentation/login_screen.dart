import 'package:flutter/material.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/feature_placeholder.dart';

/// ログイン画面。
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン'), leading: const AppBackButton()),
      body: const FeaturePlaceholder(title: 'ログイン', issue: 3),
    );
  }
}
