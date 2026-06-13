// Standard scaffold: themed AppBar + optional PineSight patterned body.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Wraps [Scaffold] with consistent app chrome and optional
/// [AppBackground.withPattern] (Home-style) behind the body.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.body,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.usePatternBackground = true,
    this.bodyPadding,
    this.extendBodyBehindAppBar = false,
  }) : assert(
          title != null || titleWidget != null,
          'Provide title or titleWidget',
        ),
       assert(
          title == null || titleWidget == null,
          'Use either title or titleWidget, not both',
        );

  /// Plain string title (centered via [AppBarTheme]).
  final String? title;

  /// Custom title widget (e.g. multi-line).
  final Widget? titleWidget;

  final Widget? body;

  final List<Widget>? actions;

  final Widget? leading;

  final Widget? floatingActionButton;

  final Widget? bottomNavigationBar;

  final bool? resizeToAvoidBottomInset;

  /// When true, body sits on the same patterned gradient as Settings/Home-style screens.
  final bool usePatternBackground;

  /// Optional padding around [body] (inside pattern / plain scaffold).
  final EdgeInsetsGeometry? bodyPadding;

  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget appBar = AppBar(
      leading: leading,
      title: titleWidget ?? Text(title!),
      actions: actions,
    );

    Widget content = body ?? const SizedBox.shrink();
    if (bodyPadding != null) {
      content = Padding(
        padding: bodyPadding!,
        child: content,
      );
    }

    final Widget scaffoldBody = usePatternBackground
        ? AppBackground.withPattern(context, child: content)
        : content;

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: scaffoldBody,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
