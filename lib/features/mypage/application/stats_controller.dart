import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/api/user_api.dart';
import '../../../domain/models/reading_book.dart';
import '../../library/application/library_controller.dart';

part 'stats_controller.g.dart';

/// 読書統計（`GET /api/v2/user/stats`）。
@Riverpod(retry: noAutoRetry)
class StatsController extends _$StatsController {
  @override
  Future<UserStats> build() {
    return ref.read(userApiProvider).fetchStats();
  }

  Future<void> refresh() async {
    final api = ref.read(userApiProvider);
    final next = await AsyncValue.guard(api.fetchStats);
    if (!ref.mounted) return;
    state = next;
  }
}
