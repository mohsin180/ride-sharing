import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

class CustomWidgets {
  static Widget customText(
    String text,
    double fontSize,
    Color color,
    FontWeight fontWeight, {
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      textAlign: textAlign,
      // Inter comes from google_fonts; naming the family as a string would
      // silently fall back to the platform face since it isn't a bundled asset.
      style: GoogleFonts.inter(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      ),
    );
  }

  static SnackBar customErrorSnackBar(String message) {
    return _statusSnackBar(
      message: message,
      title: "Something went wrong",
      icon: Icons.priority_high_rounded,
      accent: Consonants.danger,
      accentBg: Consonants.dangerWash,
    );
  }

  static SnackBar customSuccessSnackBar(String message) {
    return _statusSnackBar(
      message: message,
      title: "Success",
      icon: Icons.check_rounded,
      accent: Consonants.credit,
      accentBg: Consonants.creditWash,
    );
  }

  /// Floating, card-style snackbar shared by [customSuccessSnackBar] and
  /// [customErrorSnackBar]. Renders as a white pill with a coloured icon
  /// badge on the left, a small status title, and the message body —
  /// matches the visual language used by chips/cards across the app.
  static SnackBar _statusSnackBar({
    required String message,
    required String title,
    required IconData icon,
    required Color accent,
    required Color accentBg,
  }) {
    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
          boxShadow: Consonants.cardLift,
        ),
        child: Row(
          children: [
            // Coloured leading stripe — keeps the status colour visible
            // even at a glance, without dominating the card.
            Container(
              width: 4.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 10.w),
            // Icon badge.
            Container(
              width: 32.w,
              height: 32.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18.sp, color: accent),
            ),
            SizedBox(width: 10.w),
            // Message body.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.navLabel(color: accent).copyWith(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(color: Consonants.bodyInk).copyWith(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthFields extends StatelessWidget {
  final String text;
  final bool obscure;
  final Widget suffixIcon;
  final String? Function(String?)? validator;
  final TextEditingController controller;

  // ✅ NEW OPTIONAL FIELDS
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool readOnly;

  const AuthFields({
    super.key,
    required this.text,
    this.obscure = false,
    required this.suffixIcon,
    this.validator,
    required this.controller,

    // ✅ optional (won’t affect old code)
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    // The system's field: r16, 17/18 padding, resting #D9D9E3 border that
    // turns violet on focus. The label sits above at 16/500 body ink.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppText.rowLabel().copyWith(fontSize: 14.5.sp)),
          SizedBox(height: 8.h),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: readOnly,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            cursorColor: Consonants.violet,
            style: AppText.rowLabel().copyWith(fontSize: 16.sp),
            decoration: InputDecoration(
              counterText: "",
              suffixIcon: suffixIcon,
              suffixIconColor: Consonants.iconInk,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18.w,
                vertical: 17.h,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Consonants.rInput.r),
                borderSide: const BorderSide(color: Consonants.border, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Consonants.rInput.r),
                borderSide: const BorderSide(color: Consonants.violet, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Consonants.rInput.r),
                borderSide: const BorderSide(color: Consonants.danger, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Consonants.rInput.r),
                borderSide: const BorderSide(color: Consonants.danger, width: 1.8),
              ),
              errorStyle: AppText.caption(color: Consonants.danger),
              filled: true,
              fillColor: readOnly ? Consonants.canvas : Consonants.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Password variant of [AuthFields] with a working show/hide toggle.
///
/// Owns a single `bool _obscure` (default true). Tapping the trailing
/// eye flips obscuring and swaps the icon between
/// [Icons.visibility]/[Icons.visibility_off] so the icon always reflects
/// the current state. Used by Login, Register, and New/Reset Password.
class PasswordField extends StatefulWidget {
  final String text;
  final String? Function(String?)? validator;
  final TextEditingController controller;

  const PasswordField({
    super.key,
    required this.text,
    this.validator,
    required this.controller,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthFields(
      text: widget.text,
      controller: widget.controller,
      obscure: _obscure,
      validator: widget.validator,
      suffixIcon: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Icon(
          // Outline pair — the system's icons are outlines, not filled glyphs.
          _obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20.sp,
          color: Consonants.iconInk,
        ),
      ),
    );
  }
}

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 13 digits
    if (digitsOnly.length > 13) {
      digitsOnly = digitsOnly.substring(0, 13);
    }

    String formatted = '';

    for (int i = 0; i < digitsOnly.length; i++) {
      formatted += digitsOnly[i];

      // Add dashes at correct positions
      if (i == 4 || i == 11) {
        if (i != digitsOnly.length - 1) {
          formatted += '-';
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
