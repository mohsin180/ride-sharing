import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/view/editProfile.dart';
import 'package:ride_sharing/view/passengerScreens/passengerHistory.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Profile extends StatelessWidget {
  final bool isPassenger;

  const Profile({super.key, this.isPassenger = true});

  @override
  Widget build(BuildContext context) {
    return isPassenger ? const PassengerProfile() : const DriverProfile();
  }
}

class PassengerProfile extends StatelessWidget {
  const PassengerProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileCustomWidgets.customProfileHeader(
            "Passenger",
            "assets/google.png",
          ),
          SizedBox(height: 20.h),
          ProfileCustomWidgets.customUpperText("Personal Details"),
          ProfileCustomWidgets.customProfileInfo(
            "Name",
            Icons.person,
            "Mohsin Karim",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "Email",
            Icons.email,
            "mohsinkarim@gmail.com",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "Phone",
            Icons.phone,
            "+92 300 1234567",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "CNIC Number",
            Icons.format_indent_decrease_rounded,
            "12345-6789012-3",
          ),
          ProfileCustomWidgets.customProfileInfo("Gender", Icons.male, "Male"),

          SizedBox(height: 30.h),
          ProfileCustomWidgets.customUpperText("Account Actions"),
          ProfileCustomWidgets.customProfileActions(
            Icons.history,
            Consonants.greyColor,
            "Ride History",
            Consonants.greyColor,
            Consonants.boldTextColor,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => History()),
              );
            },
          ),
          ProfileCustomWidgets.customProfileActions(
            Icons.edit,
            Consonants.greyColor,
            "Edit Profile",
            Consonants.greyColor,
            Consonants.boldTextColor,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Editprofile()),
              );
            },
          ),
          SizedBox(height: 30.h),
          ProfileCustomWidgets.customProfileActions(
            Icons.logout,
            Colors.red,
            "Logout",
            Colors.red,
            Colors.red,
            () {},
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class DriverProfile extends StatelessWidget {
  const DriverProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileCustomWidgets.customProfileHeader(
            "Driver",
            "assets/google.png",
          ),
          SizedBox(height: 20.h),
          ProfileCustomWidgets.customUpperText("Personal Details"),
          ProfileCustomWidgets.customProfileInfo(
            "Name",
            Icons.person,
            "Mohsin Karim",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "Email",
            Icons.email,
            "mohsinkarim@gmail.com",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "Phone",
            Icons.phone,
            "+92 300 1234567",
          ),

          ProfileCustomWidgets.customProfileInfo(
            "CNIC Number",
            Icons.format_indent_decrease_rounded,
            "12345-6789012-3",
          ),
          ProfileCustomWidgets.customProfileInfo("Gender", Icons.male, "Male"),

          SizedBox(height: 30.h),
          ProfileCustomWidgets.customUpperText("Account Actions"),
          ProfileCustomWidgets.customProfileActions(
            Icons.history,
            Consonants.greyColor,
            "Ride History",
            Consonants.greyColor,
            Consonants.boldTextColor,
            () {},
          ),
          ProfileCustomWidgets.customProfileActions(
            Icons.edit,
            Consonants.greyColor,
            "Edit Profile",
            Consonants.greyColor,
            Consonants.boldTextColor,
            () {},
          ),
          SizedBox(height: 30.h),
          ProfileCustomWidgets.customProfileActions(
            Icons.logout,
            Colors.red,
            "Logout",
            Colors.red,
            Colors.red,
            () {},
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class ProfileCustomWidgets {
  static Widget customProfileInfo(String text, IconData icon, String subtitle) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
        leading: Container(
          height: 50.h,
          width: 30.w,
          decoration: BoxDecoration(
            color: Consonants.lightGreyColor,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: Consonants.greyColor),
        ),
        title: CustomWidgets.customText(
          text,
          10.sp,
          Consonants.greyColor,
          FontWeight.w400,
        ),
        subtitle: CustomWidgets.customText(
          subtitle,
          12.sp,
          Consonants.boldTextColor,
          FontWeight.w600,
        ),
      ),
    );
  }

  static Widget customProfileHeader(String role, String image) {
    return Column(
      children: [
        CircleAvatar(
          radius: 70.r,
          backgroundColor: Colors.transparent,
          backgroundImage: AssetImage(image),
        ),
        CustomWidgets.customText(
          role,
          12.sp,
          Consonants.primaryColor,
          FontWeight.w700,
        ),
      ],
    );
  }

  static Widget customUpperText(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text,
            10.sp,
            Consonants.greyColor,
            FontWeight.w700,
          ),
        ],
      ),
    );
  }

  static Widget customProfileActions(
    IconData icon,
    Color leadingColor,
    String text,
    Color iconColor,
    Color textColor,
    VoidCallback onpressed,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 30.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
        leading: Container(
          height: 50.h,
          width: 30.w,
          decoration: BoxDecoration(
            color: Consonants.lightGreyColor,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: leadingColor),
        ),
        title: CustomWidgets.customText(
          text,
          12.sp,
          textColor,
          FontWeight.w700,
        ),
        trailing: GestureDetector(
          onTap: onpressed,
          child: Icon(Icons.arrow_forward_ios, color: iconColor, size: 14.sp),
        ),
      ),
    );
  }
}
