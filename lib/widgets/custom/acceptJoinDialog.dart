import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Fare-aware confirmation before the host accepts a join request: fetches
/// the before/after preview ("your fare Rs 157 → Rs 120 · requester pays
/// Rs 240") so the host never approves blind. Returns true on confirm.
/// If the preview can't be fetched, falls back to a generic confirm.
Future<bool> confirmAcceptJoin(
  BuildContext context,
  WidgetRef ref, {
  required String rideId,
  required String requestId,
  String requesterName = 'this rider',
}) async {
  HostAcceptFarePreview? p;
  try {
    p = await ref
        .read(rideServiceProvider)
        .getAcceptFarePreview(rideId, requestId);
  } catch (_) {
    // Preview unavailable — still let the host decide, just without numbers.
  }
  if (!context.mounted) return false;

  final drops = p != null && p.yourShareAfter <= p.yourShareNow;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Consonants.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: CustomWidgets.customText("Accept $requesterName?", 15.sp,
          Consonants.boldTextColor, FontWeight.w800),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null) ...[
            Row(
              children: [
                CustomWidgets.customText("Your fare:  ", 12.sp,
                    Consonants.greyColor, FontWeight.w600),
                CustomWidgets.customText(p.nowLabel, 12.sp,
                    Consonants.greyColor, FontWeight.w700),
                CustomWidgets.customText("  →  ", 12.sp,
                    Consonants.greyColor, FontWeight.w600),
                CustomWidgets.customText(
                    p.afterLabel,
                    13.sp,
                    drops ? const Color(0xff15803D) : const Color(0xffB45309),
                    FontWeight.w800),
              ],
            ),
            SizedBox(height: 6.h),
            CustomWidgets.customText(
                "$requesterName pays ${p.requesterLabel}", 12.sp,
                Consonants.greyColor, FontWeight.w600),
            SizedBox(height: 6.h),
            CustomWidgets.customText(
                "Trip becomes ${p.tripKmAfter.toStringAsFixed(1)} km · ${p.tripMinAfter} min",
                11.sp,
                Consonants.greyColor,
                FontWeight.w500),
          ] else
            CustomWidgets.customText(
                "They'll share your ride and split the fare.", 12.sp,
                Consonants.greyColor, FontWeight.w500, maxLines: 2),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Not now")),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Accept")),
      ],
    ),
  );
  return ok == true;
}
