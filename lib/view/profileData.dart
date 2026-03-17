import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class PassengerProfileData extends StatelessWidget {
  const PassengerProfileData({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController cnicController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "Tell us about yourself",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
                  ),
                  AuthFields(
                    text: "Full Name",
                    suffixIcon: Icon(Icons.person),
                    controller: nameController,
                  ),
                  AuthFields(
                    text: "Phone Number",
                    suffixIcon: Icon(Icons.phone),
                    controller: phoneController,
                  ),
                  AuthFields(
                    text: "CNIC Number",
                    suffixIcon: Icon(Icons.format_indent_decrease_rounded),
                    controller: cnicController,
                  ),
                ],
              ),
            ),
          ),
          ProfileContainer(() async {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DriverProfileData()),
            );
          }),
        ],
      ),
    );
  }
}

Widget ProfileContainer(Future<void> Function()? onPressed) {
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

class DriverProfileData extends StatelessWidget {
  const DriverProfileData({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController makeController = TextEditingController();
    final TextEditingController modelController = TextEditingController();
    final TextEditingController colorController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "Enter your car details",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
                  ),
                  AuthFields(
                    text: "Car Make",
                    suffixIcon: Icon(Icons.calendar_today),
                    controller: makeController,
                  ),
                  AuthFields(
                    text: "Car Model",
                    suffixIcon: Icon(Icons.info_outline),
                    controller: modelController,
                  ),
                  AuthFields(
                    text: "Car Number",
                    suffixIcon: Icon(Icons.confirmation_number),
                    controller: numberController,
                  ),
                  AuthFields(
                    text: "Car Color",
                    suffixIcon: Icon(Icons.color_lens),
                    controller: colorController,
                  ),
                ],
              ),
            ),
          ),
          ProfileContainer(() async {}),
        ],
      ),
    );
  }
}
