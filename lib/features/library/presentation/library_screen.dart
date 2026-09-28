import 'package:flutter/material.dart';

import '../../../core/widgets/feature_placeholder.dart';

/// ライブラリ（書籍一覧）画面。
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ライブラリ')),
      body: const FeaturePlaceholder(title: 'ライブラリ', issue: 5),
    );
  }
}
