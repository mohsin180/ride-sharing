import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(color: Consonants.scaffoldBackgroundColor),
          DraggableScrollableSheet(
            initialChildSize: 0.34,
            minChildSize: 0.25,
            maxChildSize: 0.5,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
                decoration: BoxDecoration(
                  color: Consonants.whiteColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30.r),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      Divider(
                        color: Consonants.lightGreyColor,
                        thickness: 4.h,
                        indent: 150.w,
                        endIndent: 150.w,
                      ),
                      homeCustomWidgets().homeContainer(),
                      SizedBox(height: 15.h),
                      homeCustomWidgets().seatsCustomContainer(),
                      SizedBox(height: 20.h),
                      CustomWidgets.customButton("Publish", () {}),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class homeCustomWidgets {
  Widget homeContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          homeTextField(
            "Current Location",
            Icons.location_city_outlined,
            Consonants.primaryColor,
          ),
          Divider(color: Consonants.whiteColor),
          homeTextField(
            "Where are you going?",
            Icons.search,
            Consonants.boldTextColor,
          ),
        ],
      ),
    );
  }

  Widget homeTextField(String hintText, IconData icon, Color iconColor) {
    return TextField(
      decoration: InputDecoration(
        hintStyle: TextStyle(
          color: Consonants.greyColor,
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        hintText: hintText,
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 15.h),
        prefixIcon: Icon(icon, color: iconColor),
      ),
    );
  }

  Widget homeIncrementDecrementButton(IconData icon, VoidCallback onpressed) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(50.r),
      ),
      child: Center(
        child: IconButton(
          onPressed: onpressed,
          icon: Icon(icon, size: 10.sp, color: Consonants.primaryColor),
        ),
      ),
    );
  }

  Widget seatsCustomContainer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Consonants.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.person_sharp, color: Consonants.greyColor, size: 12.sp),
          CustomWidgets.customText(
            "Select Seats",
            13.sp,
            Consonants.greyColor,
            FontWeight.w600,
          ),
          SizedBox(width: 30.w),
          homeIncrementDecrementButton(Icons.minimize, () {}),
          CustomWidgets.customText(
            "1",
            12.sp,
            Consonants.boldTextColor,
            FontWeight.bold,
          ),
          homeIncrementDecrementButton(Icons.add, () {}),
        ],
      ),
    );
  }
}
