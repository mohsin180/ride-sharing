import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/view/forgotPassword.dart';
import 'package:ride_sharing/view/registerScreen.dart';
import 'package:ride_sharing/view/verificationScreen.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Loginscreen extends StatelessWidget {
  const Loginscreen({super.key});

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
                    'Login to Your Account',
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
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
                    suffixIcon: Icon(Icons.remove_red_eye, size: 10.sp),
                  ),
                  SizedBox(height: 5.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 33.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Forgotpassword(),
                            ),
                          ),
                          child: CustomWidgets.customText(
                            'Forgot Password?',
                            9.sp,
                            Consonants.primaryColor,
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// BOTTOM FIXED CONTAINER
            AuthContainer(
              buttonText: "Login",
              accountText: 'Dont have an account?',
              actionText: 'Sign Up',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Verificationscreen()),
                );
              },
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Registerscreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
