import 'dart:math';
import 'package:flutter/material.dart';

class FloatingMathSymbols extends StatefulWidget {
  final int count;

  const FloatingMathSymbols({super.key, this.count = 20});

  @override
  State<FloatingMathSymbols> createState() => _FloatingMathSymbolsState();
}

class _FloatingMathSymbolsState extends State<FloatingMathSymbols>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();

  static const List<String> _symbols = [
    "∫",
    "∑",
    "∏",
    "√",
    "∞",
    "π",
    "θ",
    "Δ",
    "∂",
    "∇",
    "α",
    "β",
    "γ",
    "λ",
    "μ",
    "σ",
    "Ω",
    "φ",
    "ψ",
    "ω",
    "≈",
    "≠",
    "≤",
    "≥",
    "±",
    "×",
    "÷",
    "∈",
    "∉",
    "⊂",
    "∪",
    "∩",
    "∴",
    "∵",
    "⊥",
    "∠",
    "∝",
    "ℕ",
    "ℝ",
    "ℂ",
  ];

  late final List<_MathSymbolData> items;

  @override
  void initState() {
    super.initState();

    items = List.generate(widget.count, (index) {
      return _MathSymbolData(
        symbol: _symbols[_random.nextInt(_symbols.length)],
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 16 + _random.nextDouble() * 32,
        opacity: 0.03 + _random.nextDouble() * 0.08,
        durationFactor: 0.5 + _random.nextDouble() * 1.5,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: items.map((item) {
                  final wave = sin(
                    (_controller.value * 2 * pi * item.durationFactor) +
                        item.x * 10,
                  );
                  final offsetY = wave * 20;

                  return Positioned(
                    left: item.x * constraints.maxWidth,
                    top: (item.y * constraints.maxHeight) + offsetY,
                    child: Opacity(
                      opacity: item.opacity,
                      child: Text(
                        item.symbol,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: item.size,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _MathSymbolData {
  final String symbol;
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double durationFactor;

  _MathSymbolData({
    required this.symbol,
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.durationFactor,
  });
}
