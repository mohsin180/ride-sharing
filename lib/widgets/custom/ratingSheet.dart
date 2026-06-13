import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Shows a post-trip rating bottom sheet and resolves to the chosen star
/// count (1–5), or `null` if the user skipped / dismissed it. Pure UI — the
/// caller performs the actual API submission so the same sheet works for
/// both "passenger rates driver" and "driver rates passenger".
Future<int?> showRatingSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  String? avatarInitial,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(
      title: title,
      subtitle: subtitle,
      avatarInitial: avatarInitial,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? avatarInitial;

  const _RatingSheet({
    required this.title,
    required this.subtitle,
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        16.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Consonants.lightGreyColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 18.h),
          if (widget.avatarInitial != null) ...[
            Container(
              width: 56.w,
              height: 56.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                widget.avatarInitial!,
                style: TextStyle(
                  color: Consonants.whiteColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: Consonants.fontFamily,
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          CustomWidgets.customText(
            widget.title,
            16.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            widget.subtitle,
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _stars = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 38.sp,
                      color: i <= _stars
                          ? const Color(0xffF5B800)
                          : Consonants.lightGreyColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          CustomWidgets.customText(
            _labels[_stars],
            11.sp,
            _stars == 0 ? Consonants.greyColor : const Color(0xffF5B800),
            FontWeight.w700,
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: CustomWidgets.customText(
                      "Skip",
                      13.sp,
                      Consonants.boldTextColor,
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _stars == 0
                      ? null
                      : () => Navigator.of(context).pop(_stars),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _stars == 0
                          ? null
                          : const LinearGradient(
                              colors: [
                                Consonants.primaryColor,
                                Color(0xff5AC8FA),
                              ],
                            ),
                      color: _stars == 0 ? Consonants.lightGreyColor : null,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: CustomWidgets.customText(
                      "Submit Rating",
                      13.sp,
                      _stars == 0
                          ? Consonants.greyColor
                          : Consonants.whiteColor,
                      FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
