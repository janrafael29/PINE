/// Shared elevated surface — matches PineSight Admin card polish.
library;

import 'package:flutter/material.dart';

class PineCard extends StatelessWidget {
  const PineCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );
    final BoxDecoration decoration = BoxDecoration(
      color: (backgroundColor ?? cs.surface).withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (borderColor ?? cs.outlineVariant).withValues(alpha: 0.55),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: decoration,
            child: content,
          ),
        ),
      ),
    );
  }
}
