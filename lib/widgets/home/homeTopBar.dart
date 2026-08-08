import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// Floating header shown over the map — current-location pill + profile avatar.
/// Stateless and const-constructable, so it never rebuilds with the map.
///
/// Both pieces float over live map tiles, so they're translucent canvas over a
/// blur rather than opaque chips: the map keeps reading through them.
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

/// Translucent canvas over a blur, lifted off the map by the violet-tinted
/// card shadow. The shadow lives on the outer box so the clip doesn't eat it.
class _FloatingSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;

  const _FloatingSurface({required this.child, required this.radius});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: Consonants.cardLift,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Consonants.canvas.withValues(alpha: 0.86),
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
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
      child: _FloatingSurface(
        radius: BorderRadius.circular(Consonants.rCard.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Consonants.iconInk,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current location',
                      style: AppText.caption().copyWith(fontSize: 10.sp),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel(color: Consonants.headingInk)
                          .copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Consonants.textMuted,
                size: 18.sp,
              ),
            ],
          ),
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
      child: _FloatingSurface(
        radius: BorderRadius.circular(Consonants.rPill.r),
        child: SizedBox(
          height: 44.h,
          width: 44.h,
          child: Icon(
            Icons.person_outline_rounded,
            color: Consonants.iconInk,
            size: 22.sp,
          ),
        ),
      ),
    );
  }
}
