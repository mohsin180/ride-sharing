import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/view/forgotPassword.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

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

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final request = LoginRequest(
      email: emailController.text.trim(),
      password: passwordController.text,
    );

    try {
      await ref.read(authControllerProvider.notifier).loginProvider(request);
      // Success snackbar + navigation handled by ref.listen below.
    } catch (_) {
      // Error already pushed onto AuthState; ref.listen surfaces it.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ErrorHandler.success(context, "Logged in successfully");
        context.go(Approutes.bottomNavbar);
      }
    });

    final authState = ref.watch(authControllerProvider);

    return ResponsiveAuthScaffold(
      formKey: _formKey,
      body: [
        CustomWidgets.customText(
          'Login to Your Account',
          20.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
        ),
        SizedBox(height: 20.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(Icons.email_rounded),
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        SizedBox(height: 20.h),
        AuthFields(
          text: 'Password',
          obscure: true,
          suffixIcon: Icon(Icons.remove_red_eye),
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
        SizedBox(height: 5.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 33.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Forgotpassword()),
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
      bottomBar: AuthContainer(
        buttonText: "Login",
        accountText: 'Dont have an account?',
        actionText: 'Sign Up',
        isLoading: authState.isloading,
        onPressed: _handleLogin,
        onTap: () => context.go(Approutes.register),
      ),
    );
  }
}
