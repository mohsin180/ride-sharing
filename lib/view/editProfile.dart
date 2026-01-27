import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Editprofile extends StatelessWidget {
  const Editprofile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackground,
      body: Column(
        children: [
          CircleAvatar(radius: 30.r),
          SizedBox(height: 10.h),
          CustomWidgets.customText(
            "Change Photo",
            14.sp,
            Consonants.primaryColor,
            FontWeight.w500,
          ),
          SizedBox(height: 20.h),
          AuthFields(text: "Full Name", suffixIcon: Icon(Icons.person)),
          SizedBox(height: 20.h),
          AuthFields(
            text: "Email Address",
            suffixIcon: Icon(Icons.email_rounded),
          ),
          SizedBox(height: 20.h),
          AuthFields(text: "Phone Number", suffixIcon: Icon(Icons.phone)),
          SizedBox(height: 20.h),
          AuthFields(text: "CNIC Number", suffixIcon: Icon(Icons.credit_card)),
          SizedBox(height: 30.h),
          CustomWidgets.customButton("Save Changes", () {}),
        ],
      ),
    );
  }
}
