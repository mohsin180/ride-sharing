import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// A fixed-center pin that sits on top of the map so the pickup point
/// stays anchored while the map pans beneath it. Wrapped in
/// [IgnorePointer] so it never swallows map gestures.
class HomePickupPin extends StatelessWidget {
  const HomePickupPin({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: Consonants.boldTextColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: CustomWidgets.customText(
                'Pickup here',
                9.sp,
                Consonants.whiteColor,
                FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Icon(
              Icons.location_pin,
              color: Consonants.primaryColor,
              size: 40.sp,
            ),
            Container(
              height: 6.h,
              width: 6.h,
              decoration: const BoxDecoration(
                color: Consonants.boldTextColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
