import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Forgotpassword extends ConsumerStatefulWidget {
  const Forgotpassword({super.key});

  @override
  ConsumerState<Forgotpassword> createState() => _ForgotpasswordState();
}

class _ForgotpasswordState extends ConsumerState<Forgotpassword> {
  final emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Timer? timer;
  // @override
  // void initState(){
  //  super.initState();
  //  startPolling();
  // }

  // void startPolling(){
  //   timer= Timer.periodic(Duration(seconds: 5), (timer) async{
  //     final state= ref.read(authControllerProvider);
  //     final verified= ref.read(authControllerProvider.notifier).checkResetStatus(token);

  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "Reset Your Password",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  SizedBox(height: 10.h),
                  CustomWidgets.customText(
                    "Please enter your email address to receive a\nlink to create a new password via email",
                    10.sp,
                    Consonants.greyColor,
                    FontWeight.w400,
                  ),
                  SizedBox(height: 20.h),
                  AuthFields(
                    text: 'Email Address',
                    suffixIcon: Icon(Icons.email_rounded, size: 10.sp),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      }
                      final emailRegex = RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      );
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    controller: emailController,
                  ),
                ],
              ),
            ),
            ResetPassword(
              onPressed: authState.isloading
                  ? null
                  : () async {
                      final request = ForgotPassword(
                        email: emailController.text.trim(),
                      );
                      if (_formKey.currentState!.validate()) {
                        await ref
                            .read(authControllerProvider.notifier)
                            .forgotpassword(request);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPassword extends StatelessWidget {
  final Future<void> Function()? onPressed;
  const ResetPassword({super.key, required this.onPressed});

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
          CustomWidgets.customButton("Send Reset Link", onPressed),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () {},
            child: CustomWidgets.customText(
              'Resent Link',
              10.sp,
              Consonants.primaryColor,
              FontWeight.w700,
            ),
          ),

          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
