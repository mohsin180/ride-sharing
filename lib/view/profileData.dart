import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
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
      body: [
        CustomWidgets.customText(
          "Tell us about yourself",
          20.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
        ),
        SizedBox(height: 10.h),
        AuthFields(
          text: "Full Name",
          suffixIcon: Icon(Icons.person),
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
        AuthFields(
          text: "Phone Number",
          suffixIcon: Icon(Icons.phone),
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
        AuthFields(
          text: "CNIC Number",
          suffixIcon: Icon(Icons.format_indent_decrease_rounded),
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
        CustomWidgets.customButton(
          "Continue",
          onPressed,
          isLoading: isLoading,
        ),
        SizedBox(height: 20.h),
      ],
    ),
  );
}
