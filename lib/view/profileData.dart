import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

class PassengerProfileData extends ConsumerStatefulWidget {
  const PassengerProfileData({super.key});

  @override
  ConsumerState<PassengerProfileData> createState() =>
      _PassengerProfileDataState();
}

class _PassengerProfileDataState extends ConsumerState<PassengerProfileData> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Clear any leftover success/error from a prior profile attempt so the
    // ref.listen below only fires on this screen's outcome.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final request = PassengerProfileRequest(
      fullName: nameController.text.trim(),
      phoneNo: phoneController.text.trim(),
      cnic: cnicController.text.trim(),
    );

    try {
      await ref
          .read(profileControllerProvider.notifier)
          .createPassengerProfile(request);
      // Navigation handled by ref.listen below.
    } on ApiException catch (e) {
      // The profile is already there — most often because a previous attempt
      // reached the server and only the response was lost. Repeating it can
      // never succeed, so treat it as done rather than leaving the user
      // pressing a button that will always fail.
      if (e.isConflict && mounted) {
        ref.invalidate(passengerProfileProvider);
        context.go(Approutes.passengerKyc);
        return;
      }
    } catch (_) {
      // Surfaced via state.error → ref.listen.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isSuccess && prev?.isSuccess != true) {
        ErrorHandler.success(context, "Profile created successfully");
        // Bust the cached fetch so the profile tab on the bottom-navbar
        // sees the freshly-created data instead of any stale value
        // left over from a previous session. Mirrors what the driver
        // onboarding flow already does in [driverVehicleDetails].
        ref.invalidate(passengerProfileProvider);
        context.go(Approutes.passengerKyc);
      }
    });

    final profileState = ref.watch(profileControllerProvider);

    return ResponsiveAuthScaffold(
      formKey: formKey,
      bodyPadding: EdgeInsets.symmetric(vertical: 28.h),
      body: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tell us about yourself",
                  style: AppText.displayXs().copyWith(fontSize: 33.sp),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 32.h),
        AuthFields(
          text: "Full Name",
          suffixIcon: Icon(
            Icons.person_outline_rounded,
            size: 20.sp,
            color: Consonants.iconInk,
          ),
          controller: nameController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Enter your Full Name";
            }
            if (value.trim().length < 3) {
              return "Name must be at least 3 characters";
            }
            return null;
          },
        ),
        SizedBox(height: Consonants.gapFields.h),
        AuthFields(
          text: "Phone Number",
          suffixIcon: Icon(
            Icons.phone_outlined,
            size: 20.sp,
            color: Consonants.iconInk,
          ),
          controller: phoneController,
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            if (!RegExp(r'^03[0-9]{9}$').hasMatch(value)) {
              return 'Enter valid Pakistani phone number';
            }
            return null;
          },
        ),
        SizedBox(height: Consonants.gapFields.h),
        AuthFields(
          text: "CNIC Number",
          suffixIcon: Icon(
            Icons.badge_outlined,
            size: 20.sp,
            color: Consonants.iconInk,
          ),
          controller: cnicController,
          keyboardType: TextInputType.number,
          maxLength: 15,
          inputFormatters: [
            FilteringTextInputFormatter.singleLineFormatter,
            CnicInputFormatter(),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'CNIC is required';
            }
            if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$').hasMatch(value)) {
              return 'Enter valid CNIC';
            }
            return null;
          },
        ),
      ],
      bottomBar: profileContainer(
        profileState.isloading ? null : _submit,
        isLoading: profileState.isloading,
      ),
    );
  }
}

Widget profileContainer(
  Future<void> Function()? onPressed, {
  bool isLoading = false,
}) {
  // Shared by both onboarding wizards: the single primary action, pinned to
  // the bottom of the screen on the canvas.
  return Padding(
    padding: EdgeInsets.fromLTRB(
      Consonants.gutter.w,
      12.h,
      Consonants.gutter.w,
      22.h,
    ),
    child: AppButton(
      label: "Continue",
      onPressed: onPressed,
      isLoading: isLoading,
    ),
  );
}
