import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Floating header shown over the map — current-location pill + profile avatar.
/// Stateless and const-constructable, so it never rebuilds with the map.
class HomeTopBar extends StatelessWidget {
  final String locationLabel;
  final VoidCallback? onLocationTap;
  final VoidCallback? onProfileTap;

  const HomeTopBar({
    super.key,
    required this.locationLabel,
    this.onLocationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LocationPill(
            label: locationLabel,
            onTap: onLocationTap,
          ),
        ),
        SizedBox(width: 10.w),
        _ProfileButton(onTap: onProfileTap),
      ],
    );
  }
}

class _LocationPill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _LocationPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: Consonants.primaryColor,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomWidgets.customText(
                    'Current Location',
                    9.sp,
                    Consonants.greyColor,
                    FontWeight.w500,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Consonants.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Consonants.boldTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Consonants.greyColor,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ProfileButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44.h,
        width: 44.h,
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.person_rounded,
          color: Consonants.primaryColor,
          size: 22.sp,
        ),
      ),
    );
  }
}
