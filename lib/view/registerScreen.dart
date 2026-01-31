import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/view/verificationScreen.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Registerscreen extends StatelessWidget {
  const Registerscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            /// CENTER CONTENT
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    'Create  Your Account',
                    25.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
                  ),
                  SizedBox(height: 20.h),
                  AuthFields(
                    text: 'Full Name',
                    suffixIcon: Icon(Icons.person, size: 10.sp),
                  ),
                  SizedBox(height: 20.h),
                  AuthFields(
                    text: 'Email Address',
                    suffixIcon: Icon(Icons.email_rounded, size: 10.sp),
                  ),
                  SizedBox(height: 20.h),
                  AuthFields(
                    text: 'Password',
                    obscure: true,
                    suffixIcon: Icon(Icons.remove_red_eye_rounded, size: 10.sp),
                  ),
                  SizedBox(height: 20.h),
                  CustomWidgets.customText(
                    "Gender",
                    12.sp,
                    Consonants.boldTextColor,
                    FontWeight.w600,
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      genderSelection("Male", Icons.male),
                      genderSelection("Female", Icons.female),
                    ],
                  ),
                ],
              ),
            ),

            /// BOTTOM FIXED CONTAINER
            AuthContainer(
              buttonText: "Signup",
              accountText: 'Already have an account?',
              actionText: 'Login',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Verificationscreen()),
                );
              },
              onTap: () => context.go(Approutes.login),
            ),
          ],
        ),
      ),
    );
  }
}

Widget genderSelection(String text, IconData icon) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16.sp, color: Consonants.boldTextColor),
        SizedBox(width: 8.w),
        CustomWidgets.customText(
          text,
          12.sp,
          Consonants.boldTextColor,
          FontWeight.w600,
        ),
      ],
    ),
  );
}
