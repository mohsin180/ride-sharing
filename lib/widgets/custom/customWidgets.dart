import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        fontFamily: Consonants.fontFamily,
      ),
    );
  }

  static Widget customButton(
    String text,
    Future<void> Function()? onPressed, {
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        maximumSize: Size(300.w, 56.h),
        minimumSize: Size(200.w, 40.h),
        backgroundColor: Consonants.primaryColor,
        disabledBackgroundColor: Consonants.primaryColor.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40.r),
        ),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Consonants.whiteColor,
                  ),
                ),
              )
            : CustomWidgets.customText(
                text,
                14.sp,
                Consonants.whiteColor,
                FontWeight.w600,
              ),
      ),
    );
  }

  static SnackBar customErrorSnackBar(String message) {
    return _statusSnackBar(
      message: message,
      title: "Something went wrong",
      icon: Icons.priority_high_rounded,
      accent: const Color(0xffEF4444),
      accentBg: const Color(0xffFEE2E2),
    );
  }

  static SnackBar customSuccessSnackBar(String message) {
    return _statusSnackBar(
      message: message,
      title: "Success",
      icon: Icons.check_rounded,
      accent: const Color(0xff15803D),
      accentBg: Consonants.primaryGreenColor,
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
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
                    style: TextStyle(
                      fontFamily: Consonants.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Consonants.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: Consonants.boldTextColor,
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomWidgets.customText(
            text,
            10.sp,
            Consonants.boldTextColor,
            FontWeight.w600,
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            readOnly: readOnly,

            // ✅ APPLY OPTIONALS
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,

            decoration: InputDecoration(
              counterText: "", // hides maxLength counter (clean UI)
              suffixIcon: suffixIcon,
              suffixIconColor: Consonants.primaryColor,
              hoverColor: Consonants.whiteColor,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: Consonants.whiteColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(color: Consonants.whiteColor),
              ),
              filled: true,
              fillColor: readOnly
                  ? Consonants.scaffoldBackgroundColor
                  : Consonants.whiteColor,
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
          _obscure ? Icons.visibility : Icons.visibility_off,
        ),
      ),
    );
  }
}

class AuthContainer extends StatelessWidget {
  final String buttonText;
  final String accountText;
  final String actionText;
  final Future<void> Function()? onPressed;
  final VoidCallback onTap;
  final bool isLoading;
  const AuthContainer({
    super.key,
    required this.buttonText,
    required this.accountText,
    required this.actionText,
    required this.onPressed,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          CustomWidgets.customButton(
            buttonText,
            onPressed,
            isLoading: isLoading,
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Spacer(),
              CustomWidgets.customText(
                accountText,
                10.sp,
                Consonants.boldTextColor,
                FontWeight.w400,
              ),
              SizedBox(width: 4.w),
              GestureDetector(
                onTap: onTap,
                child: CustomWidgets.customText(
                  actionText,
                  10.sp,
                  Consonants.primaryColor,
                  FontWeight.w600,
                ),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 10.h),
        ],
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
