import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

class CustomWidgets {
  static Widget customText(
    String text,
    double fontSize,
    Color color,
    FontWeight fontWeight,
  ) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        fontFamily: 'EncodeSans',
      ),
    );
  }

  static Widget customButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        maximumSize: Size(300.w, 56.h),
        minimumSize: Size(200.w, 40.h),

        backgroundColor: Consonants.primaryColor,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40.r),
        ),
      ),
      child: Center(
        child: CustomWidgets.customText(
          text,
          14.sp,
          Consonants.whiteColor,
          FontWeight.w600,
        ),
      ),
    );
  }

  static Widget customContinueWithGoogle() {
    return Container(
      height: 56.h,
      width: 300.w,
      decoration: BoxDecoration(
        border: Border.all(
          color: Consonants.scaffoldBackgroundColor,
          width: 2.w,
        ),
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 10.w),
          Image.asset('assets/google.png', height: 30.h, width: 30.w),
          SizedBox(width: 10.w),
          CustomWidgets.customText(
            'Continue with Google',
            14.sp,
            Consonants.boldTextColor,
            FontWeight.w600,
          ),
          SizedBox(width: 10.w),
        ],
      ),
    );
  }

  // profile custom widgets can be added here
  static Widget customProfileInfo(String text, IconData icon, String subtitle) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
        leading: Container(
          height: 50.h,
          width: 30.w,
          decoration: BoxDecoration(
            color: Consonants.lightGreyColor,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: Consonants.greyColor),
        ),
        title: CustomWidgets.customText(
          text,
          10.sp,
          Consonants.greyColor,
          FontWeight.w400,
        ),
        subtitle: CustomWidgets.customText(
          subtitle,
          12.sp,
          Consonants.boldTextColor,
          FontWeight.w600,
        ),
      ),
    );
  }

  static Widget customProfileHeader(String role, String image) {
    return Column(
      children: [
        CircleAvatar(
          radius: 70.r,
          backgroundColor: Colors.transparent,
          backgroundImage: AssetImage(image),
        ),
        CustomWidgets.customText(
          role,
          12.sp,
          Consonants.primaryColor,
          FontWeight.w700,
        ),
      ],
    );
  }

  static Widget customUpperText(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text,
            10.sp,
            Consonants.greyColor,
            FontWeight.w700,
          ),
        ],
      ),
    );
  }

  static Widget customProfileActions(
    IconData icon,
    Color leadingColor,
    String text,
    Color iconColor,
    Color textColor,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
        leading: Container(
          height: 50.h,
          width: 30.w,
          decoration: BoxDecoration(
            color: Consonants.lightGreyColor,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: leadingColor),
        ),
        title: CustomWidgets.customText(
          text,
          12.sp,
          textColor,
          FontWeight.w700,
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: iconColor, size: 14.sp),
      ),
    );
  }
}

class AuthFields extends StatelessWidget {
  final String text;
  final bool obscure;
  final Widget suffixIcon;
  const AuthFields({
    super.key,
    required this.text,
    this.obscure = false,
    required this.suffixIcon,
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
            obscureText: obscure,
            decoration: InputDecoration(
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
              fillColor: Consonants.whiteColor,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthContainer extends StatelessWidget {
  final String buttonText;
  final String accountText;
  final String actionText;
  final VoidCallback onPressed;
  final VoidCallback onTap;
  const AuthContainer({
    super.key,
    required this.buttonText,
    required this.accountText,
    required this.actionText,
    required this.onPressed,
    required this.onTap,
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
          CustomWidgets.customButton(buttonText, onPressed),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80.w,
                child: Divider(
                  thickness: 2,
                  color: Consonants.scaffoldBackgroundColor,
                ),
              ),
              CustomWidgets.customText(
                '  or  ',
                10.sp,
                Consonants.boldTextColor,
                FontWeight.w400,
              ),
              SizedBox(
                width: 80.w,
                child: Divider(
                  thickness: 2,
                  color: Consonants.scaffoldBackgroundColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          CustomWidgets.customContinueWithGoogle(),

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
