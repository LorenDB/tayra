import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final double borderRadius;

  const LogoWidget({super.key, this.size = 80, this.borderRadius = 20});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/tayra.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: size * 0.5,
            ),
          );
        },
      ),
    );
  }
}
