import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Newpassword extends StatelessWidget {
  const Newpassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomWidgets.customText(
                  "Create New Password",
                  20.sp,
                  Consonants.boldTextColor,
                  FontWeight.w700,
                ),
                SizedBox(height: 10.h),
                AuthFields(
                  text: "New Password",
                  obscure: true,
                  suffixIcon: Icon(Icons.remove_red_eye_rounded, size: 10.sp),
                ),
                SizedBox(height: 10.h),
                AuthFields(
                  text: "Confirm Password",
                  obscure: true,
                  suffixIcon: Icon(Icons.remove_red_eye_rounded, size: 10.sp),
                ),
              ],
            ),
          ),
          UpdatePassword(onPressed: () {}),
        ],
      ),
    );
  }
}

class UpdatePassword extends StatelessWidget {
  final VoidCallback onPressed;
  const UpdatePassword({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          CustomWidgets.customButton("Update Password", () {}),

          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: ((context) => Loginscreen())),
            ),
            child: CustomWidgets.customText(
              'Back to Login',
              10.sp,
              Consonants.greyColor,
              FontWeight.w400,
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
