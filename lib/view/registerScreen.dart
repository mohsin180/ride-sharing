import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class Registerscreen extends ConsumerStatefulWidget {
  const Registerscreen({super.key});

  @override
  ConsumerState<Registerscreen> createState() => _RegisterscreenState();
}

class _RegisterscreenState extends ConsumerState<Registerscreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final gender = ref.read(genderProvider);
    if (gender == null) {
      ErrorHandler.show(context, "Please select gender");
      return;
    }

    final request = RegisterRequest(
      email: emailController.text.trim(),
      password: passwordController.text,
      gender: gender,
    );

    try {
      await ref
          .read(authControllerProvider.notifier)
          .registerProvider(request);
      // Success snackbar + navigation handled by ref.listen below.
    } catch (_) {
      // Error surfaced via AuthState.error → ref.listen.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isRegistered && previous?.isRegistered != true) {
        ErrorHandler.success(context, "Account was created successfully");
        context.go(Approutes.verification);
      }
    });

    final authState = ref.watch(authControllerProvider);
    final selectedGender = ref.watch(genderProvider);

    return ResponsiveAuthScaffold(
      formKey: _formKey,
      body: [
        CustomWidgets.customText(
          'Create  Your Account',
          25.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
        ),
        SizedBox(height: 30.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(Icons.email_rounded),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        SizedBox(height: 10.h),
        AuthFields(
          text: 'Password',
          obscure: true,
          suffixIcon: Icon(Icons.remove_red_eye_rounded),
          controller: passwordController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters long';
            }
            return null;
          },
        ),
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.only(left: 30.w),
          child: Row(
            children: [
              CustomWidgets.customText(
                "Select your Gender",
                10.sp,
                Consonants.boldTextColor,
                FontWeight.w600,
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            genderSelection(
              "Male  ",
              Icons.male,
              selectedGender == "MALE",
              () => ref.read(genderProvider.notifier).selectMale(),
            ),
            SizedBox(width: 20.w),
            genderSelection(
              "Female",
              Icons.female,
              selectedGender == "FEMALE",
              () => ref.read(genderProvider.notifier).selectFemale(),
            ),
          ],
        ),
      ],
      bottomBar: AuthContainer(
        buttonText: "Signup",
        accountText: 'Already have an account?',
        actionText: 'Login',
        isLoading: authState.isloading,
        onPressed: _handleRegister,
        onTap: () => context.go(Approutes.login),
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
      height: 100.h,
      width: 128.w,
      decoration: BoxDecoration(
        color: isSelected ? Consonants.lightBlueColor : Consonants.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Consonants.primaryColor : Colors.transparent,
          width: 2.w,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16.sp, color: Consonants.boldTextColor),
          SizedBox(height: 8.h),
          CustomWidgets.customText(
            text,
            12.sp,
            Consonants.boldTextColor,
            FontWeight.w600,
          ),
        ],
      ),
    ),
  );
}
