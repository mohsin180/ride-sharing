import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/rideStatsProvider.dart';
import 'package:ride_sharing/view/driverScreens/driverRideHistory.dart';
import 'package:ride_sharing/view/editProfile.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/view/passengerScreens/passengerHistory.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Profile extends StatelessWidget {
  final bool isPassenger;

  const Profile({super.key, this.isPassenger = true});

  @override
  Widget build(BuildContext context) {
    return isPassenger ? const PassengerProfile() : const DriverProfile();
  }
}

/// ───────────────────────── PASSENGER ─────────────────────────
class PassengerProfile extends ConsumerWidget {
  const PassengerProfile({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(passengerProfileProvider);
    ref.invalidate(rideStatsProvider);
    // Wait for the profile (the primary data) before dropping the spinner.
    // Stats fetch in parallel; failures there fall back to placeholders.
    await ref.read(passengerProfileProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(passengerProfileProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: Consonants.primaryColor,
        onRefresh: () => _refresh(ref),
        child: asyncProfile.when(
          loading: () => const _ProfileLoading(),
          error: (e, _) => _ProfileError(
            message: ErrorHandler.message(e),
            onRetry: () => ref.invalidate(passengerProfileProvider),
          ),
          data: (profile) => _PassengerProfileBody(profile: profile),
        ),
      ),
    );
  }
}

/// Renders the actual passenger profile once data is loaded. Pulled out
/// of [PassengerProfile] so the loading/error siblings stay tidy.
class _PassengerProfileBody extends ConsumerWidget {
  final PassengerProfileResponse profile;
  const _PassengerProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(rideStatsProvider);

    final tripsText = asyncStats.maybeWhen(
      data: (s) => s.trips.toString(),
      orElse: () => "—",
    );
    final ratingText = asyncStats.maybeWhen(
      data: (s) => s.rating?.toStringAsFixed(1) ?? "—",
      orElse: () => "—",
    );
    final memberText = profile.createdAt != null
        ? profile.createdAt!.year.toString()
        : "—";

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        children: [
          ProfileWidgets.heroHeader(
            name: profile.fullName,
            role: "Passenger",
          ),
          SizedBox(height: 14.h),
          ProfileWidgets.statsCard(
            trips: tripsText,
            rating: ratingText,
            memberSince: memberText,
          ),
          SizedBox(height: 22.h),
          ProfileWidgets.sectionLabel("Personal Details"),
          SizedBox(height: 10.h),
          ProfileWidgets.infoGroup([
            ProfileInfoItem(
              icon: Icons.person_outline_rounded,
              label: "Name",
              value: profile.fullName,
            ),
            ProfileInfoItem(
              icon: Icons.email_outlined,
              label: "Email",
              value: profile.email ?? "—",
            ),
            ProfileInfoItem(
              icon: Icons.phone_outlined,
              label: "Phone",
              value: profile.phoneNo,
            ),
            ProfileInfoItem(
              icon: Icons.badge_outlined,
              label: "CNIC Number",
              value: profile.cnic,
            ),
            ProfileInfoItem(
              icon: profile.gender == "FEMALE"
                  ? Icons.female_rounded
                  : Icons.male_rounded,
              label: "Gender",
              value: _formatGender(profile.gender),
            ),
          ]),
          SizedBox(height: 22.h),
          ProfileWidgets.sectionLabel("Account"),
          SizedBox(height: 10.h),
          ProfileWidgets.actionGroup([
            ProfileActionItem(
              icon: Icons.history_rounded,
              label: "Ride History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => History()),
              ),
            ),
            ProfileActionItem(
              icon: Icons.edit_outlined,
              label: "Edit Profile",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Editprofile(isPassenger: true),
                ),
              ),
            ),
          ]),
          SizedBox(height: 16.h),
          ProfileWidgets.logoutButton(
            onTap: () => ProfileWidgets.confirmLogout(context),
          ),
        ],
      ),
    );
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return "—";
    final lower = gender.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// Spinner state while the profile is being fetched. Wrapped in a
/// scrollable so [RefreshIndicator] still works.
class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 220.h),
        Center(
          child: CircularProgressIndicator(color: Consonants.primaryColor),
        ),
        SizedBox(height: 16.h),
        Center(
          child: CustomWidgets.customText(
            "Loading your profile…",
            12.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Friendly error state with a retry button. Wrapped in a scrollable
/// so [RefreshIndicator] still works.
class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 80.h),
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 56.sp,
          color: Consonants.primaryColor,
        ),
        SizedBox(height: 16.h),
        CustomWidgets.customText(
          "Couldn't load your profile",
          16.sp,
          Consonants.boldTextColor,
          FontWeight.w800,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        CustomWidgets.customText(
          message,
          11.sp,
          Consonants.greyColor,
          FontWeight.w500,
          textAlign: TextAlign.center,
          maxLines: 4,
        ),
        SizedBox(height: 20.h),
        Center(
          child: GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(40.r),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 14.sp,
                    color: Consonants.whiteColor,
                  ),
                  SizedBox(width: 6.w),
                  CustomWidgets.customText(
                    "Try again",
                    12.sp,
                    Consonants.whiteColor,
                    FontWeight.w700,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ───────────────────────── DRIVER ─────────────────────────
class DriverProfile extends ConsumerWidget {
  const DriverProfile({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(driverProfileProvider);
    ref.invalidate(rideStatsProvider);
    await ref.read(driverProfileProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(driverProfileProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: Consonants.primaryColor,
        onRefresh: () => _refresh(ref),
        child: asyncProfile.when(
          loading: () => const _ProfileLoading(),
          error: (e, _) => _ProfileError(
            message: ErrorHandler.message(e),
            onRetry: () => ref.invalidate(driverProfileProvider),
          ),
          data: (profile) => _DriverProfileBody(profile: profile),
        ),
      ),
    );
  }
}

class _DriverProfileBody extends ConsumerWidget {
  final DriverProfileResponse profile;
  const _DriverProfileBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(rideStatsProvider);

    final tripsText = asyncStats.maybeWhen(
      data: (s) => s.trips.toString(),
      orElse: () => "—",
    );
    final ratingText = asyncStats.maybeWhen(
      data: (s) => s.rating?.toStringAsFixed(1) ?? "—",
      orElse: () => "—",
    );
    final memberText = profile.createdAt != null
        ? profile.createdAt!.year.toString()
        : "—";

    final v = profile.vehicle;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        children: [
          ProfileWidgets.heroHeader(name: profile.fullName, role: "Driver"),
          SizedBox(height: 14.h),
          ProfileWidgets.statsCard(
            trips: tripsText,
            rating: ratingText,
            memberSince: memberText,
          ),
          SizedBox(height: 22.h),
          ProfileWidgets.sectionLabel("Personal Details"),
          SizedBox(height: 10.h),
          ProfileWidgets.infoGroup([
            ProfileInfoItem(
              icon: Icons.person_outline_rounded,
              label: "Name",
              value: profile.fullName,
            ),
            ProfileInfoItem(
              icon: Icons.email_outlined,
              label: "Email",
              value: profile.email ?? "—",
            ),
            ProfileInfoItem(
              icon: Icons.phone_outlined,
              label: "Phone",
              value: profile.phoneNo,
            ),
            ProfileInfoItem(
              icon: Icons.badge_outlined,
              label: "CNIC Number",
              value: profile.cnic,
            ),
            ProfileInfoItem(
              icon: profile.gender == "FEMALE"
                  ? Icons.female_rounded
                  : Icons.male_rounded,
              label: "Gender",
              value: _formatGender(profile.gender),
            ),
          ]),
          SizedBox(height: 22.h),
          ProfileWidgets.sectionLabel("Vehicle"),
          SizedBox(height: 10.h),
          ProfileWidgets.infoGroup([
            ProfileInfoItem(
              icon: Icons.drive_eta,
              label: "Car Make",
              value: v.make.isEmpty ? "—" : v.make,
            ),
            ProfileInfoItem(
              icon: Icons.info_outline,
              label: "Car Model",
              value: v.model.isEmpty ? "—" : v.model,
            ),
            ProfileInfoItem(
              icon: Icons.confirmation_number,
              label: "Car Number",
              value: v.number.isEmpty ? "—" : v.number,
            ),
            ProfileInfoItem(
              icon: Icons.color_lens,
              label: "Car Color",
              value: v.color.isEmpty ? "—" : v.color,
            ),
            ProfileInfoItem(
              icon: Icons.chair,
              label: "Car Seats",
              value: v.seats > 0 ? v.seats.toString() : "—",
            ),
            ProfileInfoItem(
              icon: Icons.calendar_today,
              label: "Car Year",
              value: v.year > 0 ? v.year.toString() : "—",
            ),
          ]),
          SizedBox(height: 22.h),
          ProfileWidgets.sectionLabel("Account"),
          SizedBox(height: 10.h),
          ProfileWidgets.actionGroup([
            ProfileActionItem(
              icon: Icons.history_rounded,
              label: "Ride History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverRideHistory()),
              ),
            ),
            ProfileActionItem(
              icon: Icons.edit_outlined,
              label: "Edit Profile",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Editprofile(isPassenger: false),
                ),
              ),
            ),
          ]),
          SizedBox(height: 16.h),
          ProfileWidgets.logoutButton(
            onTap: () => ProfileWidgets.confirmLogout(context),
          ),
        ],
      ),
    );
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return "—";
    final lower = gender.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// ─────────────────────── DATA HOLDERS ───────────────────────
class ProfileInfoItem {
  final IconData icon;
  final String label;
  final String value;
  const ProfileInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class ProfileActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ProfileActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// ─────────────────────── PROFILE WIDGETS ───────────────────────
class ProfileWidgets {
  // ─── Hero header ──────────────────────────────────────────
  static Widget heroHeader({
    required String name,
    required String role,
  }) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 26.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Initial avatar
          Container(
            width: 96.w,
            height: 96.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Consonants.whiteColor.withValues(alpha: 0.35),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: Consonants.primaryColor,
                fontSize: 40.sp,
                fontWeight: FontWeight.w800,
                fontFamily: Consonants.fontFamily,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: CustomWidgets.customText(
                  name,
                  17.sp,
                  Consonants.whiteColor,
                  FontWeight.w800,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(Icons.verified_rounded,
                  size: 16.sp, color: Consonants.whiteColor),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Consonants.whiteColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  role == "Driver"
                      ? Icons.directions_car_rounded
                      : Icons.person_rounded,
                  size: 12.sp,
                  color: Consonants.whiteColor,
                ),
                SizedBox(width: 5.w),
                CustomWidgets.customText(
                  role,
                  10.sp,
                  Consonants.whiteColor,
                  FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats card ───────────────────────────────────────────
  static Widget statsCard({
    required String trips,
    required String rating,
    required String memberSince,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statCell(
            icon: Icons.route_rounded,
            value: trips,
            label: "Trips",
            color: Consonants.primaryColor,
          ),
          _vDiv(),
          _statCell(
            icon: Icons.star_rounded,
            value: rating,
            label: "Rating",
            color: const Color(0xffF5B800),
          ),
          _vDiv(),
          _statCell(
            icon: Icons.calendar_today_rounded,
            value: memberSince,
            label: "Member",
            color: Consonants.primaryColor,
          ),
        ],
      ),
    );
  }

  static Widget _statCell({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            value,
            14.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
          SizedBox(height: 1.h),
          CustomWidgets.customText(
            label,
            9.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }

  static Widget _vDiv() {
    return Container(
      height: 32.h,
      width: 1,
      color: Consonants.lightGreyColor,
    );
  }

  // ─── Section label ────────────────────────────────────────
  static Widget sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text.toUpperCase(),
            10.sp,
            Consonants.greyColor,
            FontWeight.w700,
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

  // ─── Info group (multiple info tiles in one card) ─────────
  static Widget infoGroup(List<ProfileInfoItem> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _infoTile(items[i]),
            if (i < items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Container(
                  height: 1,
                  color: Consonants.lightGreyColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  static Widget _infoTile(ProfileInfoItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.lightBlueColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(item.icon,
                size: 18.sp, color: Consonants.primaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  item.label,
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  item.value,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action group ─────────────────────────────────────────
  static Widget actionGroup(List<ProfileActionItem> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _actionTile(items[i]),
            if (i < items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Container(
                  height: 1,
                  color: Consonants.lightGreyColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  static Widget _actionTile(ProfileActionItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.lightBlueColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(item.icon,
                  size: 18.sp, color: Consonants.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: CustomWidgets.customText(
                item.label,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18.sp, color: Consonants.greyColor),
          ],
        ),
      ),
    );
  }

  // ─── Logout confirmation dialog ───────────────────────────
  /// Shows an "Are you sure you want to logout?" dialog. On confirm
  /// the dialog closes and the user is sent back to the login screen
  /// with the entire navigation stack cleared, so the back button can
  /// not return into the (now logged-out) tab views.
  static Future<void> confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Consonants.whiteColor,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xffFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded,
                      size: 26.sp, color: const Color(0xffEF4444)),
                ),
                SizedBox(height: 14.h),
                CustomWidgets.customText(
                  "Are you sure?",
                  16.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 6.h),
                CustomWidgets.customText(
                  "You'll be signed out and returned to the login screen.",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(false),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Consonants.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: CustomWidgets.customText(
                            "Decline",
                            13.sp,
                            Consonants.boldTextColor,
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(true),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xffEF4444),
                                Color(0xffF87171),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffEF4444)
                                    .withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CustomWidgets.customText(
                            "OK",
                            13.sp,
                            Consonants.whiteColor,
                            FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Loginscreen()),
      (route) => false,
    );
  }

  // ─── Logout button ────────────────────────────────────────
  static Widget logoutButton({required VoidCallback onTap}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Consonants.whiteColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: const Color(0xffFEE2E2),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded,
                  size: 16.sp, color: const Color(0xffEF4444)),
              SizedBox(width: 8.w),
              CustomWidgets.customText(
                "Logout",
                13.sp,
                const Color(0xffEF4444),
                FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
