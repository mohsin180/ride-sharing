import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Verificationscreen extends ConsumerStatefulWidget {
  const Verificationscreen({super.key});

  @override
  ConsumerState<Verificationscreen> createState() => _VerificationscreenState();
}

class _VerificationscreenState extends ConsumerState<Verificationscreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    startPolling();
  }

  void startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final state = ref.read(authControllerProvider);
      final userId = state.userId;

      if (userId == null) {
        // userId not ready yet, wait
        return;
      }

      try {
        final verified = await ref
            .read(authControllerProvider.notifier)
            .isEmailVerified(userId);
        print("UserId in state: $userId");
        print("Email verified result: $verified");

        if (verified == true) {
          timer.cancel();
          if (mounted) {
            context.go(Approutes.roleSection);
          }
        }
      } catch (e) {
        // optional: log error
        print("Verification check failed: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
                  'Verify Your Email',
                  17.sp,
                  Colors.black,
                  FontWeight.bold,
                ),
                SizedBox(height: 5.h),
                CustomWidgets.customText(
                  'click to the link sent to',
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.normal,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  "mughallmohsin938@gmail.com",
                  10.sp,
                  Consonants.boldTextColor,
                  FontWeight.bold,
                ),
                SizedBox(height: 30.h),
                Card(
                  color: Consonants.whiteColor,
                  elevation: 10,
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Image.asset(
                    "assets/gmail.png",
                    fit: BoxFit.contain,
                    height: 200.h,
                    width: 200.w,
                  ),
                ),
              ],
            ),
          ),
          VerificationContainer(onPressed: () async {}),
        ],
      ),
    );
  }
}

// Widget VerificationField() {
//   return Container(
//     height: 50.h,
//     width: 30.w,
//     decoration: BoxDecoration(
//       color: Consonants.whiteColor,
//       borderRadius: BorderRadius.circular(12.r),
//     ),
//     child: TextField(
//       textAlign: TextAlign.center,
//       style: TextStyle(
//         fontSize: 15.sp,
//         fontWeight: FontWeight.bold,
//         color: Consonants.boldTextColor,
//       ),
//       keyboardType: TextInputType.number,
//       maxLength: 1,
//       decoration: InputDecoration(counterText: '', border: InputBorder.none),
//     ),
//   );
// }

class VerificationContainer extends StatelessWidget {
  final Future<void> Function()? onPressed;
  const VerificationContainer({super.key, required this.onPressed});

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
          CustomWidgets.customButton("Open Email App", onPressed),
          SizedBox(height: 20.h),
          CustomWidgets.customText(
            'Resend Code',
            10.sp,
            Consonants.primaryColor,
            FontWeight.w600,
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => Approutes.register,
            child: CustomWidgets.customText(
              'Change Email Address',
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
