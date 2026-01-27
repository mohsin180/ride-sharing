import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Ridescreen extends StatelessWidget {
  const Ridescreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Column(children: [

        ],
      ));
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
    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Row(
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
            CustomWidgets.customText(
              fare,
              15.sp,
              Consonants.primaryColor,
              FontWeight.bold,
            ),
          ],
        ),
        SizedBox(height: 10.h),
      ],
    ),
  );
}
