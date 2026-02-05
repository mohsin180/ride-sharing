import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/register.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Registerscreen extends ConsumerStatefulWidget {
  const Registerscreen({super.key});

  @override
  ConsumerState<Registerscreen> createState() => _RegisterscreenState();
}

class _RegisterscreenState extends ConsumerState<Registerscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(CustomWidgets.customSnackBar(next.error!));
      } else if (next.isSuccess) {
        context.go(Approutes.verification);
      }
    });
    final authState = ref.watch(authControllerProvider);
    final selectedGender = ref.watch(genderProvider);
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
                      'Create  Your Account',
                      25.sp,
                      Consonants.boldTextColor,
                      FontWeight.bold,
                    ),
                    SizedBox(height: 20.h),
                    AuthFields(
                      text: 'Full Name',
                      suffixIcon: Icon(Icons.person, size: 10.sp),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                      controller: nameController,
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
                    SizedBox(height: 20.h),
                    AuthFields(
                      text: 'Password',
                      obscure: true,
                      suffixIcon: Icon(
                        Icons.remove_red_eye_rounded,
                        size: 10.sp,
                      ),
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
                    SizedBox(height: 20.h),
                    AuthFields(
                      text: 'PhoneNo',
                      suffixIcon: Icon(Icons.phone, size: 10.sp),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phoneNo';
                        }
                        if (value.length < 11) {
                          return 'phone No must be at least 11 characters long';
                        }
                        return null;
                      },
                      controller: phoneController,
                    ),
                    SizedBox(height: 20.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            CustomWidgets.customText(
                              "Gender",
                              10.sp,
                              Consonants.boldTextColor,
                              FontWeight.w600,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            genderSelection(
                              "Male  ",
                              Icons.male,
                              selectedGender == "MALE",
                              () {
                                ref.read(genderProvider.notifier).selectMale();
                              },
                            ),
                            SizedBox(width: 20.w),
                            genderSelection(
                              "Female",
                              Icons.female,
                              selectedGender == "FEMALE",
                              () {
                                ref
                                    .read(genderProvider.notifier)
                                    .selectFemale();
                              },
                            ),
                          ],
                        ),
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
                onPressed: authState.isloading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          final gender = ref.read(genderProvider);
                          if (gender == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              CustomWidgets.customSnackBar(
                                "Please select gender",
                              ),
                            );
                            return;
                          }

                          final request = RegisterRequest(
                            email: emailController.text.trim(),
                            password: passwordController.text.trim(),
                            username: nameController.text.trim(),
                            phoneNo: phoneController.text.trim(),
                            gender: gender,
                          );
                          await ref
                              .read(authControllerProvider.notifier)
                              .registerProvider(request);
                        }
                      },
                onTap: () => context.go(Approutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget genderSelection(
  String text,
  IconData icon,
  bool isSelected,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Consonants.primaryColor : Colors.transparent,
          width: 2.w,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.sp,
            color: isSelected
                ? Consonants.primaryColor
                : Consonants.boldTextColor,
          ),
          SizedBox(width: 8.w),
          CustomWidgets.customText(
            text,
            12.sp,
            isSelected ? Consonants.primaryColor : Consonants.boldTextColor,
            FontWeight.w600,
          ),
        ],
      ),
    ),
  );
}
