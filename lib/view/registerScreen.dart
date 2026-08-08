import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/authModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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

  /// Full-width block on the screen's gutter — the centred column inside
  /// [ResponsiveAuthScaffold] would otherwise shrink-wrap its children.
  Widget _gutter({required Widget child}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
        child: SizedBox(width: double.infinity, child: child),
      );

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
      bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
      body: [
        _gutter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kept to one line — see the matching headline on the login
              // screen; "Account" was falling to a second row.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Create Your Account',
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.displayXs().copyWith(fontSize: 33.sp),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30.h),
        AuthFields(
          text: 'Email Address',
          suffixIcon: Icon(
            Icons.mail_outline_rounded,
            size: 20.sp,
            color: Consonants.iconInk,
          ),
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
        SizedBox(height: Consonants.gapFields.h),
        PasswordField(
          text: 'Password',
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
        SizedBox(height: 26.h),
        _gutter(
          child: Text(
            "Select your Gender",
            style: AppText.rowLabel().copyWith(fontSize: 14.5.sp),
          ),
        ),
        SizedBox(height: 12.h),
        _gutter(
          child: Row(
            children: [
              Expanded(
                child: genderSelection(
                  "Male",
                  Icons.male_outlined,
                  selectedGender == "MALE",
                  () => ref.read(genderProvider.notifier).selectMale(),
                ),
              ),
              SizedBox(width: Consonants.gapTiles.w),
              Expanded(
                child: genderSelection(
                  "Female",
                  Icons.female_outlined,
                  selectedGender == "FEMALE",
                  () => ref.read(genderProvider.notifier).selectFemale(),
                ),
              ),
            ],
          ),
        ),
      ],
      bottomBar: Padding(
        padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w,
          12.h,
          Consonants.gutter.w,
          22.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: "Signup",
              isLoading: authState.isloading,
              onPressed: _handleRegister,
            ),
            SizedBox(height: Consonants.gapButtons.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: AppText.rowLabel(color: Consonants.textMuted)
                      .copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w400),
                ),
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: () => context.go(Approutes.login),
                  child: Text(
                    'Login',
                    style: AppText.rowLabel(color: Consonants.indigo).copyWith(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
  // A tappable object, so it's a card: white on the canvas, lifted by the
  // violet-tinted shadow. Selection reads as the violet edge plus the filled
  // icon circle — the gradient stays reserved for the CTA.
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(vertical: 18.h),
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius: BorderRadius.circular(Consonants.rCard.r),
        boxShadow: Consonants.cardLift,
        border: Border.all(
          color: isSelected ? Consonants.violet : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Consonants.indigo : Consonants.indigoWash,
            ),
            child: Icon(
              icon,
              size: 23.sp,
              color: isSelected ? Consonants.surface : Consonants.iconInk,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            text,
            style: AppText.rowLabel(
              color: isSelected ? Consonants.headingInk : Consonants.bodyInk,
            ).copyWith(
              fontSize: 15.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
