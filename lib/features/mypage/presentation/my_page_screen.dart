import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// マイページ（統計・設定入口）。
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: const FeaturePlaceholder(title: 'マイページ', issue: 13),
    );
  }
}
