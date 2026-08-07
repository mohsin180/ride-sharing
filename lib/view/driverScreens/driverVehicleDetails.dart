import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/view/profileData.dart' show profileContainer;
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/responsive.dart';

/// Step 2 of the driver onboarding wizard — vehicle details + the actual
/// `POST /api/v1/profile/driver` call.
///
/// Reads personal details out of [driverOnboardingProvider] (set on
/// step 1), combines them with the vehicle fields entered here, and
/// fires one combined request.
class DriverVehicleDetails extends ConsumerStatefulWidget {
  const DriverVehicleDetails({super.key});

  @override
  ConsumerState<DriverVehicleDetails> createState() =>
      _DriverVehicleDetailsState();
}

class _DriverVehicleDetailsState extends ConsumerState<DriverVehicleDetails> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _numberController = TextEditingController();
  final _colorController = TextEditingController();
  final _seatsController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Wipe stale isSuccess/error from any prior profile attempt so the
    // ref.listen below only fires for *this* save.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _numberController.dispose();
    _colorController.dispose();
    _seatsController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final personal = ref.read(driverOnboardingProvider);
    if (personal == null) {
      // Hard guard — the user landed here without completing step 1
      // (e.g. deep link or back-stack glitch). Send them back to fix it.
      ErrorHandler.show(
        context,
        "Personal details missing. Please complete step 1.",
      );
      context.go(Approutes.driverProfileData);
      return;
    }

    final request = DriverProfileRequest(
      fullName: personal.fullName,
      phoneNo: personal.phoneNo,
      cnic: personal.cnic,
      vehicle: VehicleRequest(
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        number: _numberController.text.trim().toUpperCase(),
        color: _colorController.text.trim(),
        seats: int.parse(_seatsController.text.trim()),
        year: int.parse(_yearController.text.trim()),
      ),
    );

    try {
      await ref
          .read(profileControllerProvider.notifier)
          .createDriverProfile(request);
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
        ErrorHandler.success(context, "Driver profile created");
        // Clear the wizard buffer so a future re-entry starts clean,
        // and prime the cached driver-profile fetch with what we just
        // got back so the profile tab renders instantly without an
        // extra round-trip.
        ref.read(driverOnboardingProvider.notifier).clear();
        ref.invalidate(driverProfileProvider);
        context.go(Approutes.driverKyc);
      }
    });

    final saving = ref.watch(
      profileControllerProvider.select((s) => s.isloading),
    );

    return ResponsiveAuthScaffold(
      formKey: _formKey,
      body: [
        SizedBox(height: 8.h),
        _heroBadge(),
        SizedBox(height: 16.h),
        CustomWidgets.customText(
          "Tell us about your car",
          20.sp,
          Consonants.boldTextColor,
          FontWeight.bold,
        ),
        SizedBox(height: 6.h),
        _stepPill(),
        SizedBox(height: 22.h),
        _sectionHeader("Vehicle Identity"),
        SizedBox(height: 6.h),
        AuthFields(
          text: "Car Make",
          suffixIcon: const Icon(Icons.drive_eta),
          controller: _makeController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Make is required';
            }
            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
              return 'Only letters allowed';
            }
            if (value.trim().length < 2) {
              return 'Too short';
            }
            return null;
          },
        ),
        AuthFields(
          text: "Car Model",
          suffixIcon: const Icon(Icons.info_outline),
          controller: _modelController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Model is required';
            }
            if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(value)) {
              return 'Invalid characters';
            }
            return null;
          },
        ),
        AuthFields(
          text: "Car Number",
          suffixIcon: const Icon(Icons.confirmation_number),
          controller: _numberController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Number is required';
            }
            if (!RegExp(r'^[A-Za-z]{2,3}-[0-9]{3,4}$').hasMatch(value)) {
              return 'Format: ABC-1234';
            }
            return null;
          },
        ),
        SizedBox(height: 14.h),
        _sectionHeader("Specifications"),
        SizedBox(height: 6.h),
        AuthFields(
          text: "Car Color",
          suffixIcon: const Icon(Icons.color_lens),
          controller: _colorController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Color is required';
            }
            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
              return 'Only letters allowed';
            }
            return null;
          },
        ),
        AuthFields(
          text: "Car Seats",
          suffixIcon: const Icon(Icons.chair),
          controller: _seatsController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Seats required';
            }
            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
              return 'Numbers only';
            }
            final seats = int.parse(value);
            if (seats < 1 || seats > 4) {
              return 'Max 4 seats';
            }
            return null;
          },
        ),
        AuthFields(
          text: "Car Year",
          suffixIcon: const Icon(Icons.calendar_today),
          controller: _yearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Year is required';
            }
            if (!RegExp(r'^[0-9]{4}$').hasMatch(value)) {
              return 'Enter valid year';
            }
            final year = int.parse(value);
            final current = DateTime.now().year;
            if (year < 1980 || year > current) {
              return 'Year must be 1980 – $current';
            }
            return null;
          },
        ),
        SizedBox(height: 8.h),
      ],
      bottomBar: profileContainer(
        saving ? null : _submit,
        isLoading: saving,
      ),
    );
  }

  /// Brand-gradient circular badge with a car icon. Anchors the screen
  /// visually so the form doesn't read as a wall of inputs.
  Widget _heroBadge() {
    return Container(
      width: 72.w,
      height: 72.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.directions_car_filled_rounded,
        color: Consonants.whiteColor,
        size: 34.sp,
      ),
    );
  }

  /// Pill chip showing the wizard position. Replaces the plain grey
  /// subtitle with something more deliberate.
  Widget _stepPill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.directions_car_rounded,
            size: 11.sp,
            color: Consonants.primaryColor,
          ),
          SizedBox(width: 5.w),
          CustomWidgets.customText(
            "Step 2 of 3 · the vehicle you'll drive",
            9.sp,
            Consonants.primaryColor,
            FontWeight.w700,
          ),
        ],
      ),
    );
  }

  /// Lightweight section divider with an uppercase label. Matches the
  /// section style used on the profile screen so the visual language is
  /// consistent across the app.
  Widget _sectionHeader(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text.toUpperCase(),
            9.sp,
            Consonants.greyColor,
            FontWeight.w800,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
        ],
      ),
    );
  }
}
