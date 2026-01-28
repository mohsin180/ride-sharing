import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Editprofile extends StatelessWidget {
  final bool isPassenger;
  const Editprofile({super.key, this.isPassenger = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: isPassenger
            ? const PassengerEditProfile()
            : const DriverEditProfile(),
      ),
    );
  }
}

class PassengerEditProfile extends StatelessWidget {
  const PassengerEditProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 60.r),
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
        SizedBox(height: 20.h),
      ],
    );
  }
}

class DriverEditProfile extends StatelessWidget {
  const DriverEditProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 60.r),
        SizedBox(height: 10.h),
        CustomWidgets.customText(
          "Change Photo",
          14.sp,
          Consonants.primaryColor,
          FontWeight.w500,
        ),
        SizedBox(height: 20.h),
        AuthFields(text: "Full Name", suffixIcon: Icon(Icons.person)),
        SizedBox(height: 10.h),
        AuthFields(
          text: "Email Address",
          suffixIcon: Icon(Icons.email_rounded),
        ),
        SizedBox(height: 10.h),
        AuthFields(text: "Phone Number", suffixIcon: Icon(Icons.phone)),
        SizedBox(height: 10.h),
        AuthFields(text: "CNIC Number", suffixIcon: Icon(Icons.credit_card)),
        SizedBox(height: 10.h),
        CustomWidgets.customText(
          "Vehicle Details",
          16.sp,
          Consonants.boldTextColor,
          FontWeight.w700,
        ),
        SizedBox(height: 10.h),
        AuthFields(text: "Car Name", suffixIcon: Icon(Icons.directions_car)),
        SizedBox(height: 10.h),
        AuthFields(text: "Car Color", suffixIcon: Icon(Icons.color_lens)),
        SizedBox(height: 10.h),
        AuthFields(
          text: "Car Plate Number",
          suffixIcon: Icon(Icons.confirmation_number),
        ),
        SizedBox(height: 10.h),
        AuthFields(text: "Car Make", suffixIcon: Icon(Icons.calendar_today)),
        SizedBox(height: 10.h),
        AuthFields(text: "Car Model", suffixIcon: Icon(Icons.info_outline)),
        SizedBox(height: 30.h),
        CustomWidgets.customButton("Save Changes", () {}),
        SizedBox(height: 20.h),
      ],
    );
  }
}
