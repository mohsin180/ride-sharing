import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Roleselection extends StatelessWidget {
  const Roleselection({super.key});

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
                  "How will you use the app?",
                  20.sp,
                  Consonants.boldTextColor,
                  FontWeight.w700,
                ),
                SizedBox(height: 20.h),
                RoleContainer(
                  icon: Icons.person,
                  title: "Passenger",
                  description:
                      "I need a safe, reliable ride\n to my destination\nwith professional drivers.",
                ),
                SizedBox(height: 10.h),
                RoleContainer(
                  icon: Icons.drive_eta,
                  title: "Driver",
                  description:
                      "I want to offer safe rides\n to passengers and earn\n money on my schedule.",
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
    );
  }
}

class RoleContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const RoleContainer({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35.w, vertical: 10.h),
      child: Container(
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20.sp, color: Consonants.primaryColor),
                SizedBox(width: 10.w),
                CustomWidgets.customText(
                  title,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w600,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            CustomWidgets.customText(
              description,
              10.sp,
              Consonants.greyColor,
              FontWeight.w400,
            ),
            SizedBox(height: 10.h),
            roleButton("Select", () {}),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}

Widget roleButton(String text, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      maximumSize: Size(100.w, 30.h),
      minimumSize: Size(50.w, 20.h),

      backgroundColor: Consonants.primaryColor,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    ),
    child: Center(
      child: CustomWidgets.customText(
        text,
        8.sp,
        Consonants.whiteColor,
        FontWeight.w600,
      ),
    ),
  );
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
