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
                  "Complete Your Profile",
                  20.sp,
                  Consonants.boldTextColor,
                  FontWeight.w700,
                ),
                AuthFields(
                  text: "Full Name",
                  suffixIcon: Icon(Icons.person),
                  controller: TextEditingController(),
                ),
                SizedBox(height: 10.h),
                AuthFields(
                  text: "CNIC Number",
                  suffixIcon: Icon(Icons.format_indent_decrease),
                  controller: TextEditingController(),
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
  const RoleContainer({super.key, required this.icon, required this.title});

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
