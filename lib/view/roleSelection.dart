import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Roleselection extends ConsumerStatefulWidget {
  const Roleselection({super.key});

  @override
  ConsumerState<Roleselection> createState() => _RoleselectionState();
}

class _RoleselectionState extends ConsumerState<Roleselection> {
  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(selectedRoleProvider);
    final roleState = ref.watch(roleProvider);

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "How will you use the app?",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  SizedBox(height: 20.h),

                  roleSelection(
                    ref: ref,
                    roleValue: "PASSENGER",
                    text: "Passenger",
                    image: "assets/passenger.jpg",
                    icon: Icons.person_2_outlined,
                  ),

                  SizedBox(height: 15.h),

                  roleSelection(
                    ref: ref,
                    roleValue: "DRIVER",
                    text: "  Driver  ",
                    image: "assets/driver.jpg",
                    icon: Icons.drive_eta,
                  ),
                ],
              ),
            ),

            /// Bottom Continue Button
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.r),
                  topRight: Radius.circular(24.r),
                ),
              ),
              child: CustomWidgets.customButton(
                roleState.isLoading ? "" : "",
                roleState.isLoading
                    ? null
                    : () async {
                        if (selectedRole == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            CustomWidgets.customErrorSnackBar(
                              "Please select a role",
                            ),
                          );
                          return;
                        }

                        try {
                          final userId = ref
                              .read(authControllerProvider)
                              .userId;

                          await ref
                              .read(roleProvider.notifier)
                              .selectRole(userId!, selectedRole);

                          ScaffoldMessenger.of(context).showSnackBar(
                            CustomWidgets.customSuccessSnackBar(
                              "Role assigned successfully",
                            ),
                          );

                          if (selectedRole == "PASSENGER") {
                            context.go(Approutes.passengerProfileData);
                          }
                          if (selectedRole == "DRIVER") {
                            context.go(Approutes.driverProfileData);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            CustomWidgets.customErrorSnackBar("Failed: $e"),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget roleSelection({
    required WidgetRef ref,
    required String roleValue,
    required String text,
    required String image,
    required IconData icon,
  }) {
    final selectedRole = ref.watch(selectedRoleProvider);
    final isSelected = selectedRole == roleValue;

    return InkWell(
      onTap: () {
        ref.read(selectedRoleProvider.notifier).selectRole(roleValue);
      },
      child: Container(
        height: 150.h,
        width: 300.w,
        padding: EdgeInsets.symmetric(horizontal: 15.w),
        decoration: BoxDecoration(
          color: isSelected ? Consonants.lightBlueColor : Consonants.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? Consonants.primaryColor : Colors.transparent,
            width: 2.w,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20.sp, color: Consonants.primaryColor),
                SizedBox(height: 10.h),
                CustomWidgets.customText(
                  text,
                  16.sp,
                  Consonants.boldTextColor,
                  FontWeight.w600,
                ),
              ],
            ),
            CircleAvatar(backgroundImage: AssetImage(image), radius: 70.r),
          ],
        ),
      ),
    );
  }
}
