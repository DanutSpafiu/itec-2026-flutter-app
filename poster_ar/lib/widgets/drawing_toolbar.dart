import 'package:flutter/material.dart';

class DrawingToolbar extends StatelessWidget {
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final bool hasDrawing;

  const DrawingToolbar({
    super.key,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onClear,
    required this.onSave,
    required this.hasDrawing,
  });

  static const List<Color> colors = [
    Color(0xFFE94560),
    Color(0xFF0F3460),
    Color(0xFF00FF87),
    Color(0xFFFFD700),
    Color(0xFFFF6B6B),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((color) {
                final isSelected = color.toARGB32() == selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => onColorChanged(color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Grosime: ',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              SizedBox(
                width: 150,
                child: Slider(
                  value: strokeWidth,
                  min: 1,
                  max: 20,
                  activeColor: selectedColor,
                  inactiveColor: Colors.grey,
                  onChanged: onStrokeWidthChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: hasDrawing ? onClear : null,
                icon: const Icon(Icons.delete_outline),
                color: hasDrawing ? Colors.red : Colors.grey,
                tooltip: 'Șterge',
              ),
              IconButton(
                onPressed: onSave,
                icon: const Icon(Icons.save),
                color: Colors.green,
                tooltip: 'Salvează',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
