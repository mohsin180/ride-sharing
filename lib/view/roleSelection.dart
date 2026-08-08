import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
      bodyPadding: EdgeInsets.symmetric(
        horizontal: Consonants.gutter.w,
        vertical: 28.h,
      ),
      body: [
        const _Header(),
        SizedBox(height: 32.h),
        _RoleCard(
          title: "I'm a Passenger",
          description:
              "Find rides going your way, share the cost and reach your destination together.",
          image: "assets/passenger.jpg",
          isSelected: selectedRole == "PASSENGER",
          onTap: roleState.isLoading
              ? null
              : () => ref
                  .read(selectedRoleProvider.notifier)
                  .selectRole("PASSENGER"),
        ),
        SizedBox(height: Consonants.gapTiles.h),
        _RoleCard(
          title: "I'm a Driver",
          description:
              "Offer rides on routes you already drive and earn extra on the way.",
          image: "assets/driver.jpg",
          isSelected: selectedRole == "DRIVER",
          onTap: roleState.isLoading
              ? null
              : () => ref
                  .read(selectedRoleProvider.notifier)
                  .selectRole("DRIVER"),
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "How will you ride?",
            style: AppText.displayXs().copyWith(fontSize: 33.sp),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final String image;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A tappable object → a card: white on the canvas, lifted by the shared
    // violet-tinted shadow, with the violet edge reserved for the selection.
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
          border: Border.all(
            color: isSelected ? Consonants.violet : Colors.transparent,
            width: 1.6,
          ),
          boxShadow: Consonants.cardLift,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 68.w,
                  height: 68.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Consonants.violet
                          : Consonants.indigoWash,
                      width: 2.5,
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
                      width: 24.w,
                      height: 24.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Consonants.indigo,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Consonants.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 13.sp,
                        color: Consonants.surface,
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
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.paragraph().copyWith(fontSize: 13.5.sp),
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
    // The one gradient on the screen, pinned to the bottom on the canvas.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        12.h,
        Consonants.gutter.w,
        22.h,
      ),
      child: AppButton(
        label: "Continue",
        isLoading: isLoading,
        onPressed: enabled ? () => onPressed() : null,
      ),
    );
  }
}
