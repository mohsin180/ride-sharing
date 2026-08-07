import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class Roleselection extends ConsumerStatefulWidget {
  const Roleselection({super.key});

  @override
  ConsumerState<Roleselection> createState() => _RoleselectionState();
}

class _RoleselectionState extends ConsumerState<Roleselection> {
  Future<void> _submit() async {
    final selectedRole = ref.read(selectedRoleProvider);
    if (selectedRole == null) {
      ErrorHandler.show(context, "Please select a role");
      return;
    }

    // The user is identified by the stored onboarding token, not by an id
    // held in memory — that used to vanish whenever the app was killed
    // between registering and verifying the email.
    await ref.read(roleProvider.notifier).selectRole(selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RoleState>(roleProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.response != null && prev?.response == null) {
        ErrorHandler.success(context, "Role assigned successfully");
        final selected = ref.read(selectedRoleProvider);
        if (selected == "PASSENGER") {
          context.go(Approutes.passengerProfileData);
        } else if (selected == "DRIVER") {
          context.go(Approutes.driverProfileData);
        }
      }
    });

    final selectedRole = ref.watch(selectedRoleProvider);
    final roleState = ref.watch(roleProvider);

    return ResponsiveAuthScaffold(
      bodyPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      body: [
        const _Header(),
        SizedBox(height: 28.h),
        _RoleCard(
          title: "I'm a Passenger",
          description:
              "Find rides going your way, share the cost and reach your destination together.",
          perks: const ["Affordable fares", "Verified drivers"],
          image: "assets/passenger.jpg",
          accentColor: Consonants.primaryColor,
          isSelected: selectedRole == "PASSENGER",
          onTap: roleState.isLoading
              ? null
              : () => ref
                  .read(selectedRoleProvider.notifier)
                  .selectRole("PASSENGER"),
        ),
        SizedBox(height: 14.h),
        _RoleCard(
          title: "I'm a Driver",
          description:
              "Offer rides on routes you already drive and earn extra on the way.",
          perks: const ["Earn extra income", "Flexible hours"],
          image: "assets/driver.jpg",
          accentColor: Consonants.primaryColor,
          isSelected: selectedRole == "DRIVER",
          onTap: roleState.isLoading
              ? null
              : () => ref
                  .read(selectedRoleProvider.notifier)
                  .selectRole("DRIVER"),
        ),
        SizedBox(height: 18.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12.sp,
              color: Consonants.greyColor,
            ),
            SizedBox(width: 6.w),
            CustomWidgets.customText(
              "You can switch roles anytime from Settings",
              10.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
          ],
        ),
      ],
      bottomBar: _ContinueBar(
        enabled: selectedRole != null && !roleState.isLoading,
        isLoading: roleState.isLoading,
        onPressed: _submit,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64.w,
          height: 64.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Consonants.primaryColor.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: 32.sp,
            color: Consonants.whiteColor,
          ),
        ),
        SizedBox(height: 18.h),
        CustomWidgets.customText(
          "How will you ride?",
          22.sp,
          Consonants.boldTextColor,
          FontWeight.w800,
        ),
        SizedBox(height: 6.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: CustomWidgets.customText(
            "Pick the role that fits you best — you'll set up your profile next.",
            12.sp,
            Consonants.greyColor,
            FontWeight.w500,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> perks;
  final String image;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.perks,
    required this.image,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 20 : 12,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(
                        alpha: isSelected ? 1.0 : 0.15,
                      ),
                      width: 3,
                    ),
                    image: DecorationImage(
                      image: AssetImage(image),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: -2.w,
                    bottom: -2.h,
                    child: Container(
                      width: 22.w,
                      height: 22.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Consonants.whiteColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12.sp,
                        color: Consonants.whiteColor,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomWidgets.customText(
                    title,
                    14.sp,
                    Consonants.boldTextColor,
                    FontWeight.w800,
                    maxLines: 1,
                  ),
                  SizedBox(height: 4.h),
                  CustomWidgets.customText(
                    description,
                    11.sp,
                    Consonants.greyColor,
                    FontWeight.w500,
                    maxLines: 2,
                  ),
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      for (final perk in perks)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 10.sp,
                                color: accentColor,
                              ),
                              SizedBox(width: 4.w),
                              CustomWidgets.customText(
                                perk,
                                9.sp,
                                accentColor,
                                FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final Future<void> Function() onPressed;

  const _ContinueBar({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: enabled ? () => onPressed() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54.h,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                  )
                : null,
            color: enabled ? null : Consonants.lightGreyColor,
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Consonants.primaryColor.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Consonants.whiteColor,
                    ),
                  ),
                ),
              ] else ...[
                CustomWidgets.customText(
                  "Continue",
                  14.sp,
                  enabled ? Consonants.whiteColor : Consonants.greyColor,
                  FontWeight.w700,
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16.sp,
                  color: enabled ? Consonants.whiteColor : Consonants.greyColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
