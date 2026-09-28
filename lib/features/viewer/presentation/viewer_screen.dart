import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/feature_placeholder.dart';

/// コミックビューア画面。
class ViewerScreen extends StatelessWidget {
  const ViewerScreen({required this.volumeId, super.key});

  final int volumeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.viewerBackground,
      appBar: AppBar(title: const Text('ビューア'), leading: const AppBackButton()),
      body: FeaturePlaceholder(title: 'ビューア (volume: $volumeId)', issue: 7),
    );
  }
}
