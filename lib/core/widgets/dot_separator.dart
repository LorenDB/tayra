import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// A `•` bullet used to visually separate metadata items in a row.
class DotSeparator extends StatelessWidget {
  const DotSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '\u2022',
        style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 13),
      ),
    );
  }
}
