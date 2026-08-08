import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

/// Shows a post-trip rating bottom sheet and resolves to the chosen star
/// count (1–5), or `null` if the user skipped / dismissed it. Pure UI — the
/// caller performs the actual API submission so the same sheet works for
/// both "passenger rates driver" and "driver rates passenger".
Future<int?> showRatingSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  String? avatarInitial,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Consonants.scrim,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.82,
    ),
    builder: (_) => _RatingSheet(
      title: title,
      subtitle: subtitle,
      avatarInitial: avatarInitial,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? avatarInitial;

  const _RatingSheet({
    required this.title,
    this.subtitle,
    this.avatarInitial,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;

  static const _labels = [
    "Tap a star to rate",
    "Poor",
    "Fair",
    "Good",
    "Great",
    "Excellent",
  ];

  @override
  Widget build(BuildContext context) {
    final rated = _stars > 0;

    return Container(
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(Consonants.rSheet.r)),
        boxShadow: Consonants.sheetLift,
      ),
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        16.h,
        Consonants.gutter.w,
        30.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber at the system's spec. Not SheetHeader: this sheet's
              // title is centred under an avatar rather than left-aligned.
              Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D6E2),
                  borderRadius: BorderRadius.circular(Consonants.rPill.r),
                ),
              ),
              SizedBox(height: 14.h),
              if (widget.avatarInitial != null) ...[
                SizedBox(height: 8.h),
                // Wash, not gradient — the submit button is the only gradient
                // this sheet is allowed.
                Container(
                  width: 56.w,
                  height: 56.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Consonants.indigoWash,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.avatarInitial!,
                    style: AppText.sectionHeading(color: Consonants.indigo)
                        .copyWith(fontSize: 22.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
              Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
              ),
              if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.paragraph().copyWith(fontSize: 14.sp),
                ),
              ],
              SizedBox(height: 22.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setState(() => _stars = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: AnimatedScale(
                          scale: i <= _stars ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOut,
                          child: Icon(
                            i <= _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 38.sp,
                            color: i <= _stars
                                ? Consonants.violet
                                : Consonants.border,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                _labels[_stars],
                style: AppText.rowLabel(
                  color: rated ? Consonants.indigo : Consonants.textMuted,
                ).copyWith(fontSize: 13.5.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 26.h),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Skip',
                      kind: AppButtonKind.neutral,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SizedBox(width: Consonants.gapButtons.w),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Submit rating',
                      onPressed: rated
                          ? () => Navigator.of(context).pop(_stars)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
