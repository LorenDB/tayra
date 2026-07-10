import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Themed [RefreshIndicator] with app-standard primary spinner + surface
/// background so every pull-to-refresh looks the same.
class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final ScrollNotificationPredicate notificationPredicate;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainer,
      onRefresh: onRefresh,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
