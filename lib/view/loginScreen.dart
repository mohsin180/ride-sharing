import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/view/forgotPassword.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Loginscreen extends ConsumerStatefulWidget {
  const Loginscreen({super.key});

  @override
  ConsumerState<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends ConsumerState<Loginscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null) {
        CustomWidgets.customErrorSnackBar(next.error!);
      } else if (next.isLoggedIn) {
        context.go(Approutes.home);
      }
    });
    final authState = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Form(
          key: _formKey,
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value!)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      controller: emailController,
                    ),
                    SizedBox(height: 20.h),
                    AuthFields(
                      text: 'Password',
                      obscure: true,
                      suffixIcon: Icon(Icons.remove_red_eye, size: 10.sp),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters long';
                        }
                        return null;
                      },
                      controller: passwordController,
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final request = LoginRequest(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );
                    ref
                        .read(authControllerProvider.notifier)
                        .loginProvider(request);
                  }
                },
                onTap: () => context.go(Approutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
