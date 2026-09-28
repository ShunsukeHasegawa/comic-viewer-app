import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// 読書履歴画面。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: const FeaturePlaceholder(title: '読書履歴', issue: 5),
    );
  }
}
