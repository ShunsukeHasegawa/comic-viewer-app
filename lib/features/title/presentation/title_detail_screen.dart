import 'package:flutter/material.dart';

import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/feature_placeholder.dart';

/// タイトル詳細 / 巻一覧画面。
class TitleDetailScreen extends StatelessWidget {
  const TitleDetailScreen({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('タイトル詳細'),
        leading: const AppBackButton(),
      ),
      body: FeaturePlaceholder(title: 'タイトル詳細 (book: $bookId)', issue: 6),
    );
  }
}
