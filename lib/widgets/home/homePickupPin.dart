import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// A fixed-center pin that sits on top of the map so the pickup point
/// stays anchored while the map pans beneath it. Wrapped in
/// [IgnorePointer] so it never swallows map gestures.
///
/// Sizes and the vertical rhythm are load-bearing — the pin's tip has to
/// land on the map centre — so the restyle only touches colour and type.
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
                color: Consonants.indigo,
                borderRadius: BorderRadius.circular(Consonants.rPill.r),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x332B2260),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Pickup here',
                style: AppText.navLabel(color: Consonants.surface)
                    .copyWith(fontSize: 9.sp, letterSpacing: 0.2),
              ),
            ),
            SizedBox(height: 4.h),
            Icon(
              Icons.location_pin,
              color: Consonants.indigo,
              size: 40.sp,
            ),
            // The ground dot: violet so the exact anchor point reads apart
            // from the pin body without introducing a third hue.
            Container(
              height: 6.h,
              width: 6.h,
              decoration: const BoxDecoration(
                color: Consonants.violet,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
