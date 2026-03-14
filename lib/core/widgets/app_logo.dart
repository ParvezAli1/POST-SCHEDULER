import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 92,
    this.showLabel = true,
    this.labelColor,
  });

  final double size;
  final bool showLabel;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
      color: labelColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF4F46E5), Color(0xFF22C55E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: size * 0.2,
                top: size * 0.2,
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBBF7D0),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Text(
                'PS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 10),
          Text('POST SCHEDULER', style: labelStyle),
        ],
      ],
    );
  }
}
