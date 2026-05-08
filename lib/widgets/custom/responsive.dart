import 'package:flutter/material.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// A scaffold layout that vertically centres [body] when there's free space
/// and scrolls when content (or the on-screen keyboard) would overflow.
///
/// [bottomBar] is pinned to the bottom and never scrolls out of view — pass
/// the action container that follows the centred form on auth/onboarding
/// screens (Login, Register, Role Selection, Profile, etc.).
///
/// Wrap the screen with this instead of the manual
/// `Column → Expanded(Column centered) → fixed bottom` pattern.
class ResponsiveAuthScaffold extends StatelessWidget {
  final List<Widget> body;
  final Widget? bottomBar;
  final Color? backgroundColor;
  final EdgeInsets? bodyPadding;
  final GlobalKey<FormState>? formKey;
  final bool useSafeArea;

  const ResponsiveAuthScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.backgroundColor,
    this.bodyPadding,
    this.formKey,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final scrollable = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: bodyPadding,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: body,
              ),
            ),
          ),
        );
      },
    );

    Widget content = Column(
      children: [
        Expanded(child: scrollable),
        if (bottomBar != null) bottomBar!,
      ],
    );

    if (formKey != null) {
      content = Form(key: formKey, child: content);
    }
    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? Consonants.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: content,
    );
  }
}

/// Wraps any vertically-stacked screen so it scrolls when content exceeds the
/// viewport. Use for screens that aren't strictly the "form + bottom bar"
/// pattern (e.g. history lists, dashboards) but still risk overflow.
class ResponsiveScrollBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool useSafeArea;
  final ScrollPhysics? physics;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveScrollBody({
    super.key,
    required this.children,
    this.padding,
    this.useSafeArea = false,
    this.physics,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = SingleChildScrollView(
      padding: padding,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
    if (useSafeArea) child = SafeArea(child: child);
    return child;
  }
}
