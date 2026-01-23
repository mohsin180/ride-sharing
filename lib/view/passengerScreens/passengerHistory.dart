import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class History extends StatelessWidget {
  const History({super.key, this.isPassenger = true});
  final bool isPassenger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: isPassenger ? const Passengerhistory() : const DriverHistory(),
    );
  }
}

class Passengerhistory extends StatelessWidget {
  const Passengerhistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HistoryCustomWidgets.customHistoryCard(
          "123 Main St",
          "456 Elm St",
          "2023-10-01",
          "10:30 AM",
          "Completed",
          "John Doe",
          "Toyota",
          "Red",
        ),
      ],
    );
  }
}

class DriverHistory extends StatelessWidget {
  const DriverHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class HistoryCustomWidgets {
  static Widget customHistoryCard(
    String pickup,
    String dropOff,
    String date,
    String time,
    String status,
    String driverName,
    String carMake,
    String carColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 3.w),
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomWidgets.customText(
                "$date . $time",
                11.sp,
                Consonants.greyColor,
                FontWeight.w400,
              ),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CustomWidgets.customText(
                  status,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_city_rounded,
                color: Consonants.primaryColor,
                size: 16.sp,
              ),
              SizedBox(width: 10.w),
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
            ],
          ),
          SizedBox(height: 20.h),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 16.sp),
              SizedBox(width: 10.w),
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

          Row(
            children: [
              CircleAvatar(radius: 20.r, backgroundColor: Consonants.greyColor),
              Column(
                children: [
                  CustomWidgets.customText(
                    driverName,
                    12.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  CustomWidgets.customText(
                    "$carMake . $carColor",
                    8.sp,
                    Consonants.greyColor,
                    FontWeight.w400,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
