import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

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
  Widget build(BuildContext context) {
    final profilestate = ref.watch(profileControllerProvider);
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
                    "Tell us about yourself",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
                  ),
                  AuthFields(
                    text: "Full Name",
                    suffixIcon: Icon(Icons.person),
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter your Full Name";
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
                      if (!RegExp(
                        r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$',
                      ).hasMatch(value)) {
                        return 'Enter valid CNIC';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          ProfileContainer(
            profilestate.isloading
                ? null
                : () async {
                    if (formKey.currentState!.validate()) {
                      final request = PassengerProfileRequest(
                        fullName: nameController.text.trim(),
                        phoneNo: phoneController.text.trim(),
                        cnic: cnicController.text.trim(),
                      );
                      ref
                          .read(profileControllerProvider.notifier)
                          .createPassengerProfile(request);
                    }
                    context.go(Approutes.bottomNavbar);
                  },
          ),
        ],
      ),
    );
  }
}

Widget ProfileContainer(Future<void> Function()? onPressed) {
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

class DriverProfileData extends ConsumerStatefulWidget {
  const DriverProfileData({super.key});

  @override
  ConsumerState<DriverProfileData> createState() => _DriverProfileDataState();
}

class _DriverProfileDataState extends ConsumerState<DriverProfileData> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController makeController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    final profilestate = ref.watch(profileControllerProvider);
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
                    "Tell us about yourself",
                    20.sp,
                    Consonants.boldTextColor,
                    FontWeight.bold,
                  ),
                  AuthFields(
                    text: "Full Name",
                    suffixIcon: Icon(Icons.person),
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter your Full Name";
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
                      if (!RegExp(
                        r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$',
                      ).hasMatch(value)) {
                        return 'Enter valid CNIC';
                      }
                      return null;
                    },
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: AuthFields(
                          text: "Car Make",
                          suffixIcon: Icon(Icons.drive_eta),
                          controller: makeController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Car make is required';
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
                      ),
                      Expanded(
                        child: AuthFields(
                          text: "Car Model",
                          suffixIcon: Icon(Icons.info_outline),
                          controller: modelController,
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
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: AuthFields(
                          text: "Car Number",
                          suffixIcon: Icon(Icons.confirmation_number),
                          controller: numberController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Car number is required';
                            }

                            if (!RegExp(
                              r'^[A-Za-z]{2,3}-[0-9]{3,4}$',
                            ).hasMatch(value)) {
                              return 'Format: ABC-1234';
                            }

                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: AuthFields(
                          text: "Car Color",
                          suffixIcon: Icon(Icons.color_lens),
                          controller: colorController,
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
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AuthFields(
                          text: "Car Seats",
                          suffixIcon: Icon(Icons.chair),
                          controller: seatsController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Seats required';
                            }

                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                              return 'Only numbers allowed';
                            }

                            int seats = int.parse(value);

                            if (seats < 1 || seats > 10) {
                              return 'Invalid seat count';
                            }

                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: AuthFields(
                          text: "Car Year",
                          suffixIcon: Icon(Icons.calendar_today),
                          controller: yearController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Year is required';
                            }

                            if (!RegExp(r'^[0-9]{4}$').hasMatch(value)) {
                              return 'Enter valid year';
                            }

                            int year = int.parse(value);
                            int currentYear = DateTime.now().year;

                            if (year < 1980 || year > currentYear) {
                              return 'Year must be between 1980 and $currentYear';
                            }

                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ProfileContainer(
            profilestate.isloading
                ? null
                : () async {
                    if (formKey.currentState!.validate()) {
                      final seats = int.parse(seatsController.text.trim());
                      final year = int.parse(yearController.text.trim());
                      final vehicle = VehicleRequest(
                        make: makeController.text.trim(),
                        model: modelController.text.trim(),
                        number: numberController.text.trim(),
                        color: colorController.text.trim(),
                        seats: seats,
                        year: year,
                      );
                      final request = DriverProfileRequest(
                        fullName: nameController.text.trim(),
                        phoneNo: phoneController.text.trim(),
                        cnic: cnicController.text.trim(),
                        vehicle: vehicle,
                      );
                      ref
                          .read(profileControllerProvider.notifier)
                          .createDriverProfile(request);
                    }
                    context.go(Approutes.bottomNavbar);
                  },
          ),
        ],
      ),
    );
  }
}
