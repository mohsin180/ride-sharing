import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Roleselection extends ConsumerStatefulWidget {
  const Roleselection({super.key});

  @override
  ConsumerState<Roleselection> createState() => _RoleselectionState();
}

class _RoleselectionState extends ConsumerState<Roleselection> {
  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(roleProvider);
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "How will you use the app?",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  SizedBox(height: 10.h),
                  roleSelection(
                    context,
                    ref,
                    "PASSENGER",
                    "Passenger",
                    Icons.person_4,
                    "assets/passenger.jpg",
                  ),
                  SizedBox(height: 10.h),
                  roleSelection(
                    context,
                    ref,
                    "DRIVER",
                    "Driver",
                    Icons.person_4,
                    "assets/driver.jpg",
                  ),
                ],
              ),
            ),
            RoleSelectedContainer(
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Bottomnavbar()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RoleSelectedContainer extends StatelessWidget {
  final Future<void> Function()? onPressed;
  const RoleSelectedContainer({super.key, required this.onPressed});

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
          CustomWidgets.customButton("Continue", onPressed),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

Widget roleSelection(
  BuildContext context,
  WidgetRef ref,
  String roleValue,
  String text,
  IconData icon,
  String image,
) {
  final selectedRole = ref.watch(roleProvider).value;
  final isSelected = selectedRole == roleValue;
  return InkWell(
    onTap: () {
      if (roleValue == "PASSENGER") {
        ref.read(roleProvider.notifier).selectPassenger();
      } else {
        ref.read(roleProvider.notifier).selectDriver();
      }
    },
    child: Container(
      height: 280.h,
      width: 212.w,
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? Consonants.lightBlueColor : Consonants.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Consonants.primaryColor : Colors.transparent,
          width: 2.w,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  color: Consonants.scaffoldBackgroundColor,
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 5.h,
                    ),
                    child: Icon(
                      icon,
                      size: 16.sp,
                      color: Consonants.boldTextColor,
                    ),
                  ),
                ),
                SizedBox(height: 8.w),
                CustomWidgets.customText(
                  text,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w600,
                ),
              ],
            ),
            CircleAvatar(backgroundImage: AssetImage(image), radius: 80.r),
          ],
        ),
      ),
    ),
  );
}
