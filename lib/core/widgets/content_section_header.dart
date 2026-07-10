import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Title used above content sections (home carousels, search result groups).
///
/// Not the same as [SettingsSectionHeader] (uppercase primary label).
class ContentSectionHeader extends StatelessWidget {
  final String title;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ContentSectionHeader({
    super.key,
    required this.title,
    this.fontSize = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
