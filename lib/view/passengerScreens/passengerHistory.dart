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
          4.8,
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
    double rating,
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
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: Consonants.primaryGreenColor,
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

          SizedBox(
            height: 20.h,
            child: Divider(color: Consonants.lightGreyColor),
          ),

          customTravelledWithSection(driverName, carMake, carColor, rating),
          SizedBox(height: 5.h),

          CustomWidgets.customText(
            "Travelled with",
            10.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
          ),
          SizedBox(height: 5.h),
          customTravelledWithSection(driverName, carMake, carColor, rating),
        ],
      ),
    );
  }
}

Widget customTravelledWithSection(
  String driverName,
  String carMake,
  String carColor,
  double rating,
) {
  return Row(
    children: [
      CircleAvatar(radius: 20.r),
      SizedBox(width: 10.w),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomWidgets.customText(
            driverName,
            10.sp,
            Consonants.boldTextColor,
            FontWeight.w600,
          ),
          CustomWidgets.customText(
            "$carMake • $carColor",
            8.sp,
            Consonants.greyColor,
            FontWeight.w400,
          ),
        ],
      ),
      Spacer(),
      Row(
        children: [
          Icon(Icons.star, color: Colors.amber, size: 14.sp),
          SizedBox(width: 4.w),
          CustomWidgets.customText(
            rating.toStringAsFixed(1),
            10.sp,
            Consonants.boldTextColor,
            FontWeight.w600,
          ),
        ],
      ),
    ],
  );
}
