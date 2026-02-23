import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Roleselection extends ConsumerStatefulWidget {
  const Roleselection({super.key});

  @override
  ConsumerState<Roleselection> createState() => _RoleselectionState();
}

class _RoleselectionState extends ConsumerState<Roleselection> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  @override
  void dispose() {
    fullNameController.clear();
    cnicController.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(roleProvider);
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "Complete Your Profile",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  AuthFields(
                    text: "Full Name",
                    suffixIcon: Icon(Icons.person),
                    controller: fullNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter your full Name";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 10.h),
                  AuthFields(
                    text: "CNIC Number",
                    suffixIcon: Icon(Icons.format_indent_decrease),
                    controller: cnicController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 13) {
                        return 'CNIC is too short';
                      }
                      if (value.length > 13) {
                        return 'CNIC is too long';
                      }

                      return null;
                    },
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.only(left: 30.w),
                    child: Row(
                      children: [
                        CustomWidgets.customText(
                          "Select your role",
                          10.sp,
                          Consonants.boldTextColor,
                          FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      roleSelection(
                        "Passenger",
                        Icons.person_4,
                        selectedRole == "PASSENGER",
                        () {
                          ref.read(roleProvider.notifier).selectPassenger();
                        },
                      ),
                      SizedBox(width: 10.h),
                      roleSelection(
                        "Driver",
                        Icons.drive_eta,
                        selectedRole == "DRIVER",
                        () {
                          ref.read(roleProvider.notifier).selectDriver();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          RoleSelectedContainer(
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Bottomnavbar()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RoleSelectedContainer extends StatelessWidget {
  final Future<void> Function()? onPressed;
  const RoleSelectedContainer({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          CustomWidgets.customButton("Continue", onPressed),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

Widget roleSelection(
  String text,
  IconData icon,
  bool isSelected,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 120.h,
      width: 128.w,
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? Consonants.lightBlueColor : Consonants.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? Consonants.primaryColor : Colors.transparent,
          width: 2.w,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 16.sp, color: Consonants.boldTextColor),
            SizedBox(height: 8.w),
            CustomWidgets.customText(
              text,
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w600,
            ),
          ],
        ),
      ),
    ),
  );
}
