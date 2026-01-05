import 'package:flutter/material.dart';

class MascotIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MascotIcon({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Icon(Icons.pest_control, color: Colors.white, size: size * 0.6),
      ),
    );
  }
}
