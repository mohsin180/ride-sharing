import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomWidgets.customProfileHeader("Passenger", "assets/google.png"),
        SizedBox(height: 20.h),
        CustomWidgets.customUpperText("Personal Details"),
        CustomWidgets.customProfileInfo("Name", Icons.person, "Mohsin Karim"),

        CustomWidgets.customProfileInfo(
          "Email",
          Icons.email,
          "mohsinkarim@gmail.com",
        ),

        CustomWidgets.customProfileInfo(
          "Phone",
          Icons.phone,
          "+92 300 1234567",
        ),

        CustomWidgets.customProfileInfo(
          "CNIC Number",
          Icons.format_indent_decrease_rounded,
          "12345-6789012-3",
        ),
        CustomWidgets.customProfileInfo("Gender", Icons.male, "Male"),

        SizedBox(height: 30.h),
        CustomWidgets.customUpperText("Account Actions"),
        CustomWidgets.customProfileActions(Icons.history, "Ride History"),
      ],
    );
  }
}
