import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Edit-profile screen used by both passengers and drivers. The driver
/// variant adds a Vehicle section underneath; everything else is shared.
///
/// Both flows are wired end-to-end:
///   - pre-populate from the cached profile provider
///     ([passengerProfileProvider] / [driverProfileProvider])
///   - submit via `PUT /api/v1/profile/{role}` through
///     [Profileprovider.updatePassengerProfile] /
///     [Profileprovider.updateDriverProfile]
///   - on success, invalidate the matching provider so the profile tab
///     refetches fresh data, then pop
class Editprofile extends ConsumerStatefulWidget {
  final bool isPassenger;
  const Editprofile({super.key, this.isPassenger = true});

  @override
  ConsumerState<Editprofile> createState() => _EditprofileState();
}

class _EditprofileState extends ConsumerState<Editprofile> {
  final _formKey = GlobalKey<FormState>();

  // Personal
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _cnic = TextEditingController();

  // Vehicle (driver only)
  final _carMake = TextEditingController();
  final _carModel = TextEditingController();
  final _carNumber = TextEditingController();
  final _carColor = TextEditingController();
  final _carSeats = TextEditingController();
  final _carYear = TextEditingController();

  bool _populated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear stale isSuccess/error from a prior create/update attempt
      // so the ref.listen below only fires for *this* save.
      ref.read(profileControllerProvider.notifier).reset();
      // Try to pre-populate from the cached profile (the user almost
      // always lands here from the profile tab, where it's already loaded).
      if (widget.isPassenger) {
        final cached = ref
            .read(passengerProfileProvider)
            .whenOrNull(data: (p) => p);
        if (cached != null) _populateFromPassenger(cached);
      } else {
        final cached = ref
            .read(driverProfileProvider)
            .whenOrNull(data: (p) => p);
        if (cached != null) _populateFromDriver(cached);
      }
    });
  }

  void _populateFromPassenger(PassengerProfileResponse p) {
    if (_populated) return;
    _name.text = p.fullName;
    _email.text = p.email ?? '';
    _phone.text = p.phoneNo;
    _cnic.text = p.cnic;
    setState(() => _populated = true);
  }

  void _populateFromDriver(DriverProfileResponse p) {
    if (_populated) return;
    _name.text = p.fullName;
    _email.text = p.email ?? '';
    _phone.text = p.phoneNo;
    _cnic.text = p.cnic;
    final v = p.vehicle;
    _carMake.text = v.make;
    _carModel.text = v.model;
    _carNumber.text = v.number;
    _carColor.text = v.color;
    _carSeats.text = v.seats > 0 ? v.seats.toString() : '';
    _carYear.text = v.year > 0 ? v.year.toString() : '';
    setState(() => _populated = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _cnic.dispose();
    _carMake.dispose();
    _carModel.dispose();
    _carNumber.dispose();
    _carColor.dispose();
    _carSeats.dispose();
    _carYear.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.isPassenger) {
        await ref
            .read(profileControllerProvider.notifier)
            .updatePassengerProfile(
              PassengerProfileRequest(
                fullName: _name.text.trim(),
                phoneNo: _phone.text.trim(),
                cnic: _cnic.text.trim(),
              ),
            );
      } else {
        await ref
            .read(profileControllerProvider.notifier)
            .updateDriverProfile(
              DriverProfileRequest(
                fullName: _name.text.trim(),
                phoneNo: _phone.text.trim(),
                cnic: _cnic.text.trim(),
                vehicle: VehicleRequest(
                  make: _carMake.text.trim(),
                  model: _carModel.text.trim(),
                  number: _carNumber.text.trim().toUpperCase(),
                  color: _carColor.text.trim(),
                  seats: int.parse(_carSeats.text.trim()),
                  year: int.parse(_carYear.text.trim()),
                ),
              ),
            );
      }
      // Navigation handled by ref.listen below.
    } catch (_) {
      // Surfaced via state.error → ref.listen.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pre-populate the form once the profile fetch resolves (covers the
    // edge case where the user lands here before the cache warms up).
    if (widget.isPassenger) {
      ref.listen<AsyncValue<PassengerProfileResponse>>(
        passengerProfileProvider,
        (prev, next) {
          next.whenData(_populateFromPassenger);
        },
      );
    } else {
      ref.listen<AsyncValue<DriverProfileResponse>>(
        driverProfileProvider,
        (prev, next) {
          next.whenData(_populateFromDriver);
        },
      );
    }

    ref.listen<ProfileState>(profileControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isSuccess && prev?.isSuccess != true) {
        ErrorHandler.success(context, "Profile updated");
        // Bust the cache so the profile tab shows fresh data.
        if (widget.isPassenger) {
          ref.invalidate(passengerProfileProvider);
        } else {
          ref.invalidate(driverProfileProvider);
        }
        Navigator.of(context).pop();
      }
    });

    final saving = ref.watch(
      profileControllerProvider.select((s) => s.isloading),
    );

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: 16.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(height: 8.h),
                      _avatarHeader(),
                      SizedBox(height: 24.h),
                      _sectionLabel("Personal Details"),
                      SizedBox(height: 12.h),
                      AuthFields(
                        text: "Full Name",
                        controller: _name,
                        suffixIcon: const Icon(Icons.person_outline_rounded),
                        validator: _required("Enter your full name"),
                      ),
                      AuthFields(
                        text: "Email Address",
                        controller: _email,
                        suffixIcon: const Icon(Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                        // Email is locked for both roles: changing it
                        // requires a separate re-verification flow.
                        readOnly: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Email is required";
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) {
                            return "Enter a valid email";
                          }
                          return null;
                        },
                      ),
                      AuthFields(
                        text: "Phone Number",
                        controller: _phone,
                        suffixIcon: const Icon(Icons.phone_outlined),
                        keyboardType: TextInputType.number,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Phone number is required";
                          }
                          if (!RegExp(r'^03[0-9]{9}$').hasMatch(v)) {
                            return "Enter a valid Pakistani number";
                          }
                          return null;
                        },
                      ),
                      AuthFields(
                        text: "CNIC Number",
                        controller: _cnic,
                        suffixIcon: const Icon(Icons.badge_outlined),
                        keyboardType: TextInputType.number,
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.singleLineFormatter,
                          CnicInputFormatter(),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "CNIC is required";
                          }
                          if (!RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$')
                              .hasMatch(v)) {
                            return "Enter a valid CNIC";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8.h),
                      if (!widget.isPassenger) ...[
                        SizedBox(height: 24.h),
                        _sectionLabel("Vehicle Details"),
                        SizedBox(height: 12.h),
                        AuthFields(
                          text: "Car Make",
                          controller: _carMake,
                          suffixIcon: const Icon(Icons.drive_eta),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Required";
                            }
                            if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
                              return "Letters only";
                            }
                            return null;
                          },
                        ),
                        AuthFields(
                          text: "Car Model",
                          controller: _carModel,
                          suffixIcon: const Icon(Icons.info_outline),
                          validator: _required("Required"),
                        ),
                        AuthFields(
                          text: "Car Number",
                          controller: _carNumber,
                          suffixIcon: const Icon(Icons.confirmation_number),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Required";
                            }
                            if (!RegExp(r'^[A-Za-z]{2,3}-[0-9]{3,4}$')
                                .hasMatch(v)) {
                              return "Format: ABC-1234";
                            }
                            return null;
                          },
                        ),
                        AuthFields(
                          text: "Car Color",
                          controller: _carColor,
                          suffixIcon: const Icon(Icons.color_lens),
                          validator: _required("Required"),
                        ),
                        AuthFields(
                          text: "Car Seats",
                          controller: _carSeats,
                          suffixIcon: const Icon(Icons.chair),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Required";
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                              return "Numbers only";
                            }
                            final seats = int.parse(v);
                            if (seats < 1 || seats > 4) {
                              return "Max 4 seats";
                            }
                            return null;
                          },
                        ),
                        AuthFields(
                          text: "Car Year",
                          controller: _carYear,
                          suffixIcon: const Icon(Icons.calendar_today),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Required";
                            }
                            if (!RegExp(r'^[0-9]{4}$').hasMatch(v)) {
                              return "Enter valid year";
                            }
                            final year = int.parse(v);
                            final current = DateTime.now().year;
                            if (year < 1980 || year > current) {
                              return "1980 – $current";
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _saveBar(saving: saving),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38.w,
              height: 38.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18.sp, color: Consonants.boldTextColor),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Edit Profile",
                  18.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  widget.isPassenger
                      ? "Update your personal details"
                      : "Update your personal & vehicle details",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Avatar header ───────────────────────────────────────

  Widget _avatarHeader() {
    final initial = _name.text.trim().isNotEmpty
        ? _name.text.trim()[0].toUpperCase()
        : "?";
    return Column(
      children: [
        Container(
          width: 96.w,
          height: 96.w,
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
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: Consonants.whiteColor,
              fontSize: 36.sp,
              fontWeight: FontWeight.w800,
              fontFamily: Consonants.fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Section label ───────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text.toUpperCase(),
            10.sp,
            Consonants.greyColor,
            FontWeight.w800,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(height: 1, color: Consonants.lightGreyColor),
          ),
        ],
      ),
    );
  }

  // ─── Save bar ────────────────────────────────────────────

  Widget _saveBar({required bool saving}) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
      child: GestureDetector(
        onTap: saving ? null : _save,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52.h,
          decoration: BoxDecoration(
            gradient: saving
                ? null
                : const LinearGradient(
                    colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                  ),
            color: saving ? Consonants.lightGreyColor : null,
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: saving
                ? null
                : [
                    BoxShadow(
                      color: Consonants.primaryColor.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: saving
                ? [
                    SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Consonants.greyColor,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    CustomWidgets.customText(
                      "Saving…",
                      13.sp,
                      Consonants.greyColor,
                      FontWeight.w700,
                    ),
                  ]
                : [
                    Icon(Icons.check_rounded,
                        size: 18.sp, color: Consonants.whiteColor),
                    SizedBox(width: 8.w),
                    CustomWidgets.customText(
                      "Save Changes",
                      13.sp,
                      Consonants.whiteColor,
                      FontWeight.w700,
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────

  String? Function(String?) _required(String message) {
    return (v) => (v == null || v.trim().isEmpty) ? message : null;
  }
}
