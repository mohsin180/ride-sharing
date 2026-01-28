import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Ridescreen extends StatelessWidget {
  const Ridescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [rideCard(15, "10", "\$25", "123 Main St", "456 Elm St")],
    );
  }
}

Widget rideCard(
  int minutes,
  String distance,
  String fare,
  String pickupLocation,
  String dropLocation,
) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                CustomWidgets.customText(
                  "Est.Duration",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
                CustomWidgets.customText(
                  "$minutes min",
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.bold,
                ),
              ],
            ),
            Column(
              children: [
                CustomWidgets.customText(
                  "Total Distance",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
                CustomWidgets.customText(
                  "$distance km",
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.bold,
                ),
              ],
            ),
            Column(
              children: [
                CustomWidgets.customText(
                  "Price",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
                CustomWidgets.customText(
                  "$fare",
                  12.sp,
                  Consonants.primaryColor,
                  FontWeight.bold,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            customRideWidgets.customRideLocations("Hostel City", "Taramri"),
            customRideWidgets.customRideLocations("Taramri", "Alipur"),
            customRideWidgets.customRideLocations("Faizabad", "Taramri"),
          ],
        ),
        SizedBox(
          height: 20.h,
          child: Divider(color: Consonants.lightGreyColor),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CustomWidgets.customText(
              "Accept Ride",
              12.sp,
              Consonants.primaryColor,
              FontWeight.bold,
            ),
            SizedBox(
              height: 30.h,
              child: VerticalDivider(
                thickness: 1.w,
                color: Consonants.lightGreyColor,
              ),
            ),
            CustomWidgets.customText(
              "View Request",
              12.sp,
              Consonants.boldTextColor,
              FontWeight.bold,
            ),
          ],
        ),
      ],
    ),
  );
}

class customRideWidgets {
  static Widget customRideLocations(String pickup, String dropOff) {
    return Column(
      children: [
        SizedBox(height: 10.h),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// LEFT: Timeline (icons + divider)
            Column(
              children: [
                SizedBox(
                  height: 12.h, // aligns icon with "Pickup" text
                ),
                Icon(
                  Icons.location_city_rounded,
                  color: Consonants.primaryColor,
                  size: 16.sp,
                ),
                SizedBox(
                  height: 20.h,
                  child: VerticalDivider(
                    thickness: 2.w,
                    color: Consonants.lightGreyColor,
                  ),
                ),
                Icon(Icons.location_on, color: Colors.red, size: 16.sp),
              ],
            ),

            SizedBox(width: 10.w),

            /// RIGHT: Text content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Pickup text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      "Pickup",
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w700,
                    ),
                    CustomWidgets.customText(
                      pickup,
                      10.sp,
                      Consonants.boldTextColor,
                      FontWeight.w600,
                    ),
                  ],
                ),

                SizedBox(height: 15.h),

                /// Destination text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      "Destination",
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w700,
                    ),
                    CustomWidgets.customText(
                      dropOff,
                      10.sp,
                      Consonants.boldTextColor,
                      FontWeight.w600,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
