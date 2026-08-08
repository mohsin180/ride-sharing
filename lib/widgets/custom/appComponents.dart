import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// The design system's building blocks.
///
/// Screens compose these rather than hand-rolling containers, so the gradient,
/// the violet-tinted lift and the type scale stay identical everywhere. The
/// rules they encode:
///
/// * the gradient marks what the user should act on, plus ONE hero surface
///   per screen — two competing gradients is a bug;
/// * white cards sit on the canvas and are separated by shadow, never by a
///   border or a second white;
/// * lists divide with a 1px rule and no card wrapper — cards are for
///   tappable objects, not rows;
/// * anything floating over content is translucent canvas plus a blur.

// ─────────────────────────── BUTTONS ───────────────────────────

enum AppButtonKind {
  /// Gradient fill. The one thing on the screen the user should act on.
  primary,

  /// Indigo outline on transparent — the alternative to the primary action.
  secondary,

  /// Neutral outline. Social sign-in, dismissals.
  neutral,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = kind == AppButtonKind.primary;
    final contentColour = isPrimary
        ? Consonants.surface
        : kind == AppButtonKind.secondary
            ? Consonants.indigo
            : Consonants.bodyInk;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(contentColour),
            ),
          ),
        ] else ...[
          if (icon != null) ...[
            Icon(icon, size: 19.sp, color: contentColour),
            SizedBox(width: 10.w),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.button(color: contentColour).copyWith(
                fontSize: 17.5.sp,
              ),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: _enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: _enabled ? onPressed : null,
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 24.w),
          decoration: BoxDecoration(
            gradient: isPrimary ? Consonants.actionGradient : null,
            color: isPrimary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(Consonants.rButton.r),
            border: isPrimary
                ? null
                : Border.all(
                    width: 1.5,
                    color: kind == AppButtonKind.secondary
                        ? Consonants.indigo
                        : Consonants.border,
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────── INPUT ───────────────────────────

/// Text field at the system's spec: r16, 17/18 padding, resting border that
/// turns violet on focus. The focus hue is the only thing that moves — no
/// colour fill, no shadow.
class AppInput extends StatefulWidget {
  final String hint;
  final TextEditingController? controller;
  final IconData? leadingIcon;
  final Widget? trailing;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int? maxLength;
  final bool enabled;
  final void Function(String)? onChanged;

  const AppInput({
    super.key,
    required this.hint,
    this.controller,
    this.leadingIcon,
    this.trailing,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  bool _focused = false;

  void _onFocusChange() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      cursorColor: Consonants.violet,
      style: AppText.rowLabel().copyWith(fontSize: 16.sp),
      decoration: InputDecoration(
        counterText: '',
        hintText: widget.hint,
        hintStyle: AppText.rowLabel(color: Consonants.textMuted)
            .copyWith(fontSize: 16.sp),
        filled: true,
        fillColor: Consonants.surface,
        prefixIcon: widget.leadingIcon == null
            ? null
            : Padding(
                padding: EdgeInsets.only(left: 18.w, right: 12.w),
                child: Icon(
                  widget.leadingIcon,
                  size: 20.sp,
                  color: _focused ? Consonants.violet : Consonants.iconInk,
                ),
              ),
        prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.trailing,
        contentPadding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 18.w),
        border: _border(Consonants.border),
        enabledBorder: _border(Consonants.border),
        focusedBorder: _border(Consonants.violet, width: 1.8),
        errorBorder: _border(Consonants.danger),
        focusedErrorBorder: _border(Consonants.danger, width: 1.8),
        errorStyle: AppText.caption(color: Consonants.danger),
      ),
    );
  }

  OutlineInputBorder _border(Color colour, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Consonants.rInput.r),
        borderSide: BorderSide(color: colour, width: width),
      );
}

// ─────────────────────────── HERO SURFACE ───────────────────────────

/// The one gradient panel a screen is allowed. Carries the screen's headline
/// figure — a balance, a fare, the trip in progress.
class HeroSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const HeroSurface({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Consonants.rHero.r),
      child: Stack(
        children: [
          // The padded content is what gives the Stack its size; the gradient
          // has to be told to fill that. As a plain (non-positioned) child
          // with no height it collapsed, so the panel painted nothing and its
          // white text landed on the bare canvas.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: Consonants.surfaceGradient),
            ),
          ),
          // Sheen: a soft diagonal wash plus one blurred highlight bleeding in
          // from the top-right corner. Purely decorative, never interactive.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: Consonants.sheenOverlay),
            ),
          ),
          Positioned(
            right: -46.w,
            top: -46.h,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                width: 170.w,
                height: 170.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
          // The only non-positioned child, so it alone decides the Stack's
          // size — hence the explicit full width. Without it the panel
          // shrink-wrapped to its content and rendered as a narrow column
          // instead of spanning the screen.
          Padding(
            padding: padding ??
                EdgeInsets.symmetric(horizontal: 24.w, vertical: 22.h),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ],
      ),
    );
  }
}

/// Pill used on top of a hero surface — currency tags, live status.
class HeroChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const HeroChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0x29FFFFFF),
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.sp, color: Consonants.surface),
            SizedBox(width: 6.w),
          ],
          Text(
            label,
            style: AppText.navLabel(color: Consonants.surface)
                .copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── CARD ───────────────────────────

/// A tappable object. Rows in a list are NOT cards — they divide with a rule.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  const AppCard({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding ?? EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
          boxShadow: Consonants.cardLift,
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────── LIST ROW ───────────────────────────

/// One line of a list: 44px icon circle, name, optional meta, trailing value.
/// Separated from its neighbours by [AppDivider], never wrapped in a card.
class AppListRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColour;
  final Color? iconBg;
  final String title;
  final String? meta;
  final String? value;

  /// Colours the trailing value. Green for money in, red for money out —
  /// nothing else on the row may be coloured.
  final Color? valueColour;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    this.meta,
    this.value,
    this.valueColour,
    this.iconColour,
    this.iconBg,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg ?? Consonants.chipBg,
              ),
              child: Icon(
                icon,
                size: 20.sp,
                color: iconColour ?? Consonants.iconInk,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                  ),
                  if (meta != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption().copyWith(fontSize: 12.5.sp),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (value != null)
              Text(
                value!,
                style: AppText.amount(color: valueColour ?? Consonants.bodyInk)
                    .copyWith(fontSize: 16.5.sp),
              ),
          ],
        ),
      ),
    );
  }
}

/// The 1px rule that separates list rows.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: Consonants.divider);
}

// ─────────────────────────── ACTION TILE ───────────────────────────

/// Square-ish shortcut in the home grid.
class ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Fills the icon circle with the action gradient — for the primary
  /// shortcut on the grid, at most one.
  final bool primary;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
  });

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
          boxShadow: Consonants.cardLift,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.primary ? Consonants.actionGradient : null,
                color: widget.primary ? null : Consonants.indigoWash,
              ),
              child: Icon(
                widget.icon,
                size: 22.sp,
                color:
                    widget.primary ? Consonants.surface : Consonants.iconInk,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowLabel().copyWith(fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── HEADER ───────────────────────────

/// Screen header: title on the left, up to two 40px round actions on the
/// right, on the 24px gutter.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 18.h, Consonants.gutter.w, 16.h),
      child: Row(
        children: [
          if (showBack) ...[
            AppIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.screenTitle().copyWith(fontSize: 24.sp),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption().copyWith(fontSize: 13.sp),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            SizedBox(width: 8.w),
            action,
          ],
        ],
      ),
    );
  }
}

/// 40px round action in a header, or a 44px back button on the chip fill.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Widget? badge;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.filled = true,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? Consonants.chipBg : Colors.transparent,
            ),
            child: Icon(icon, size: 20.sp, color: Consonants.iconInk),
          ),
          if (badge != null) Positioned(right: -2, top: -2, child: badge!),
        ],
      ),
    );
  }
}

/// Uppercase section label with a rule running to the edge.
class AppSectionHeading extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const AppSectionHeading({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppText.sectionHeading().copyWith(fontSize: 17.sp)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────── SCAFFOLD ───────────────────────────

/// Canvas + optional header + a single scrolling column, with the bottom
/// clearance the floating nav needs.
class AppScreen extends StatelessWidget {
  final Widget? header;
  final List<Widget> children;
  final Widget? bottomBar;
  final EdgeInsets? padding;
  final bool navClearance;
  final ScrollController? controller;
  final GlobalKey<FormState>? formKey;

  const AppScreen({
    super.key,
    this.header,
    required this.children,
    this.bottomBar,
    this.padding,
    this.navClearance = false,
    this.controller,
    this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = ListView(
      controller: controller,
      padding: (padding ??
              EdgeInsets.symmetric(horizontal: Consonants.gutter.w))
          .copyWith(
        bottom: navClearance ? Consonants.navClearance.h : 24.h,
      ),
      children: children,
    );
    if (formKey != null) {
      body = Form(key: formKey, child: body);
    }
    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (header != null) header!,
            Expanded(child: body),
            if (bottomBar != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    Consonants.gutter.w, 8.h, Consonants.gutter.w, 20.h),
                child: bottomBar!,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── SHEET ───────────────────────────

/// Grabber + title for a bottom sheet. Sheets are r22 on the top corners
/// only, over a blurred scrim.
class SheetHeader extends StatelessWidget {
  final String title;

  const SheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44.w,
          height: 5.h,
          decoration: BoxDecoration(
            color: const Color(0xFFD6D6E2),
            borderRadius: BorderRadius.circular(Consonants.rPill.r),
          ),
        ),
        SizedBox(height: 14.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
          ),
        ),
      ],
    );
  }
}

/// Opens [child] in the system's sheet chrome — blurred scrim, translucent
/// rounded surface, capped at 82% of the screen.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Consonants.scrim,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.82,
    ),
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Consonants.rSheet.r)),
        boxShadow: Consonants.sheetLift,
      ),
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 16.h, Consonants.gutter.w, 30.h),
      child: SafeArea(top: false, child: child),
    ),
  );
}
