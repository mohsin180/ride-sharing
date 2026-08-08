import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

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
    barrierColor: Consonants.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 20.h),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rSheet.r),
          boxShadow: Consonants.cardLift,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Consonants.indigoWash,
                ),
                child: Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 22.sp,
                  color: Consonants.iconInk,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'Accept $requesterName?',
                style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                p == null
                    ? "They'll share your ride and split the fare."
                    : 'Adding them re-splits the fare across the trip.',
                style: AppText.caption().copyWith(fontSize: 13.sp, height: 1.4),
              ),
              if (p != null) ...[
                SizedBox(height: 18.h),
                // The money is the largest thing on this surface: the host is
                // deciding on a number, not on a name.
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 15.h),
                  decoration: BoxDecoration(
                    color: Consonants.canvas,
                    borderRadius: BorderRadius.circular(Consonants.rCard.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your fare',
                        style: AppText.caption().copyWith(fontSize: 12.5.sp),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            p.nowLabel,
                            style: AppText.rowLabel(color: Consonants.textMuted)
                                .copyWith(
                                  fontSize: 15.sp,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Consonants.textMuted,
                                ),
                          ),
                          SizedBox(width: 10.w),
                          Flexible(
                            child: Text(
                              p.afterLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.figure(
                                color: drops
                                    ? Consonants.credit
                                    : Consonants.danger,
                              ).copyWith(fontSize: 28.sp),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      const AppDivider(),
                      SizedBox(height: 12.h),
                      _MetaLine(
                        icon: Icons.account_balance_wallet_outlined,
                        text: '$requesterName pays ${p.requesterLabel}',
                      ),
                      SizedBox(height: 8.h),
                      _MetaLine(
                        icon: Icons.route_outlined,
                        text:
                            'Trip becomes ${p.tripKmAfter.toStringAsFixed(1)} km · ${p.tripMinAfter} min',
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 22.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Not now',
                      kind: AppButtonKind.secondary,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  SizedBox(width: Consonants.gapButtons.w),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Accept',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok == true;
}

/// One supporting fact under the fare — outline icon, muted caption.
class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15.sp, color: Consonants.iconInk),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: AppText.caption().copyWith(fontSize: 12.5.sp, height: 1.35),
          ),
        ),
      ],
    );
  }
}
