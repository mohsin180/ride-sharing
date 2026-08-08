import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/view/profileData.dart' show profileContainer;
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

/// Step 1 of the driver onboarding wizard — personal details only.
///
/// The combined `POST /api/v1/profile/driver` is fired on step 2 once
/// the vehicle details are also collected. This screen stashes the
/// personal fields into [driverOnboardingProvider] so step 2 can read
/// them back and assemble the full request.
class DriverProfileData extends ConsumerStatefulWidget {
  const DriverProfileData({super.key});

  @override
  ConsumerState<DriverProfileData> createState() => _DriverProfileDataState();
}

class _DriverProfileDataState extends ConsumerState<DriverProfileData> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // If the user came back from step 2 (e.g. tapped back), restore the
    // values they had so they don't have to retype.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saved = ref.read(driverOnboardingProvider);
      if (saved != null) {
        nameController.text = saved.fullName;
        phoneController.text = saved.phoneNo;
        cnicController.text = saved.cnic;
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cnicController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;

    ref
        .read(driverOnboardingProvider.notifier)
        .savePersonal(
          DriverOnboardingPersonal(
            fullName: nameController.text.trim(),
            phoneNo: phoneController.text.trim(),
            cnic: cnicController.text.trim(),
          ),
        );

    context.go(Approutes.driverVehicleDetails);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAuthScaffold(
      formKey: formKey,
      body: [
        SizedBox(height: 8.h),
        _heroBadge(),
        SizedBox(height: 20.h),
        Text(
          "Tell us about yourself",
          textAlign: TextAlign.center,
          style: AppText.screenTitle().copyWith(fontSize: 24.sp),
        ),
        SizedBox(height: 10.h),
        _stepPill(),
        SizedBox(height: 26.h),
        AuthFields(
          text: "Full Name",
          suffixIcon: const Icon(Icons.person),
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
          suffixIcon: const Icon(Icons.phone),
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
          suffixIcon: const Icon(Icons.format_indent_decrease_rounded),
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
      bottomBar: profileContainer(_continue),
    );
  }

  /// Brand-gradient badge. Anchors the screen so the form doesn't read as a
  /// wall of inputs.
  Widget _heroBadge() {
    return Center(
      child: Container(
        width: 72.w,
        height: 72.w,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: Consonants.actionGradient,
        ),
        child: Icon(
          Icons.person_outline_rounded,
          color: Consonants.surface,
          size: 32.sp,
        ),
      ),
    );
  }

  /// Pill chip showing the wizard position.
  Widget _stepPill() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: Consonants.indigoWash,
          borderRadius: BorderRadius.circular(Consonants.rPill.r),
        ),
        child: Text(
          "Step 1 of 3",
          style: AppText.navLabel(color: Consonants.indigo)
              .copyWith(fontSize: 12.5.sp),
        ),
      ),
    );
  }
}
