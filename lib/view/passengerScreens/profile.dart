import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/profileModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/rideStatsProvider.dart';
import 'package:ride_sharing/provider/sessionReset.dart';
import 'package:ride_sharing/view/driverScreens/driverRideHistory.dart';
import 'package:ride_sharing/view/editProfile.dart';
import 'package:ride_sharing/view/passengerScreens/passengerHistory.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

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
        color: Consonants.indigo,
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
      padding: EdgeInsets.only(bottom: Consonants.navClearance.h),
      child: Column(
        children: [
          ProfileWidgets.heroHeader(
            name: profile.fullName,
            role: "Passenger",
          ),
          SizedBox(height: 16.h),
          ProfileWidgets.statsCard(
            trips: tripsText,
            rating: ratingText,
            memberSince: memberText,
          ),
          SizedBox(height: 32.h),
          ProfileWidgets.sectionLabel("Personal Details"),
          SizedBox(height: 4.h),
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
                  ? Icons.female_outlined
                  : Icons.male_outlined,
              label: "Gender",
              value: _formatGender(profile.gender),
            ),
          ]),
          SizedBox(height: 32.h),
          ProfileWidgets.sectionLabel("Account"),
          SizedBox(height: 4.h),
          ProfileWidgets.actionGroup([
            ProfileActionItem(
              icon: Icons.history_outlined,
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
          SizedBox(height: 28.h),
          ProfileWidgets.logoutButton(
            onTap: () => ProfileWidgets.confirmLogout(context, ref),
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
        const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Consonants.indigo,
          ),
        ),
        SizedBox(height: 18.h),
        Center(
          child: Text(
            "Loading your profile…",
            style: AppText.caption().copyWith(fontSize: 13.sp),
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
      padding: EdgeInsets.symmetric(
        horizontal: Consonants.gutter.w,
        vertical: 80.h,
      ),
      children: [
        Center(
          child: Container(
            width: 72.w,
            height: 72.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Consonants.indigoWash,
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              size: 32.sp,
              color: Consonants.indigo,
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          "Couldn't load your profile",
          textAlign: TextAlign.center,
          style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppText.paragraph().copyWith(fontSize: 15.sp),
        ),
        SizedBox(height: 26.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              label: "Try again",
              icon: Icons.refresh_rounded,
              kind: AppButtonKind.secondary,
              expand: false,
              onPressed: onRetry,
            ),
          ],
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
        color: Consonants.indigo,
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
      padding: EdgeInsets.only(bottom: Consonants.navClearance.h),
      child: Column(
        children: [
          ProfileWidgets.heroHeader(name: profile.fullName, role: "Driver"),
          SizedBox(height: 16.h),
          ProfileWidgets.statsCard(
            trips: tripsText,
            rating: ratingText,
            memberSince: memberText,
          ),
          SizedBox(height: 32.h),
          ProfileWidgets.sectionLabel("Personal Details"),
          SizedBox(height: 4.h),
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
                  ? Icons.female_outlined
                  : Icons.male_outlined,
              label: "Gender",
              value: _formatGender(profile.gender),
            ),
          ]),
          SizedBox(height: 32.h),
          ProfileWidgets.sectionLabel("Vehicle"),
          SizedBox(height: 4.h),
          ProfileWidgets.infoGroup([
            ProfileInfoItem(
              icon: Icons.directions_car_outlined,
              label: "Car Make",
              value: v.make.isEmpty ? "—" : v.make,
            ),
            ProfileInfoItem(
              icon: Icons.info_outline,
              label: "Car Model",
              value: v.model.isEmpty ? "—" : v.model,
            ),
            ProfileInfoItem(
              icon: Icons.confirmation_number_outlined,
              label: "Car Number",
              value: v.number.isEmpty ? "—" : v.number,
            ),
            ProfileInfoItem(
              icon: Icons.color_lens_outlined,
              label: "Car Color",
              value: v.color.isEmpty ? "—" : v.color,
            ),
            ProfileInfoItem(
              icon: Icons.event_seat_outlined,
              label: "Car Seats",
              value: v.seats > 0 ? v.seats.toString() : "—",
            ),
            ProfileInfoItem(
              icon: Icons.calendar_today_outlined,
              label: "Car Year",
              value: v.year > 0 ? v.year.toString() : "—",
            ),
          ]),
          SizedBox(height: 32.h),
          ProfileWidgets.sectionLabel("Account"),
          SizedBox(height: 4.h),
          ProfileWidgets.actionGroup([
            ProfileActionItem(
              icon: Icons.history_outlined,
              label: "Ride History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DriverRideHistoryScreen()),
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
          SizedBox(height: 28.h),
          ProfileWidgets.logoutButton(
            onTap: () => ProfileWidgets.confirmLogout(context, ref),
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
  /// The one gradient surface on the profile: who you are, and the role
  /// you're signed in as.
  static Widget heroHeader({
    required String name,
    required String role,
  }) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        18.h,
        Consonants.gutter.w,
        0,
      ),
      child: HeroSurface(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        child: Column(
          children: [
            Container(
              width: 88.w,
              height: 88.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x29FFFFFF),
                border: Border.all(color: const Color(0x47FFFFFF), width: 2),
              ),
              child: Text(
                initial,
                style: AppText.figure(color: Consonants.surface)
                    .copyWith(fontSize: 34.sp),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.screenTitle(color: Consonants.surface)
                  .copyWith(fontSize: 22.sp),
            ),
            SizedBox(height: 12.h),
            HeroChip(
              label: role,
              icon: role == "Driver"
                  ? Icons.directions_car_outlined
                  : Icons.person_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats card ───────────────────────────────────────────
  static Widget statsCard({
    required String trips,
    required String rating,
    required String memberSince,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 8.w),
        child: Row(
          children: [
            _statCell(value: trips, label: "Trips"),
            _vDiv(),
            _statCell(value: rating, label: "Rating"),
            _vDiv(),
            _statCell(value: memberSince, label: "Member since"),
          ],
        ),
      ),
    );
  }

  static Widget _statCell({required String value, required String label}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: AppText.screenTitle().copyWith(fontSize: 22.sp),
          ),
          SizedBox(height: 5.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption().copyWith(fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  static Widget _vDiv() {
    return Container(height: 34.h, width: 1, color: Consonants.divider);
  }

  // ─── Section label ────────────────────────────────────────
  static Widget sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppSectionHeading(label: text),
    );
  }

  // ─── Info group ───────────────────────────────────────────
  /// Facts about the account: a list, so it divides with a 1px rule and
  /// never gets a card wrapper.
  static Widget infoGroup(List<ProfileInfoItem> items) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _infoTile(items[i]),
            if (i < items.length - 1) const AppDivider(),
          ],
        ],
      ),
    );
  }

  static Widget _infoTile(ProfileInfoItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Consonants.chipBg,
            ),
            child: Icon(item.icon, size: 20.sp, color: Consonants.iconInk),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowLabel().copyWith(fontSize: 16.sp),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            AppListRow(
              icon: items[i].icon,
              title: items[i].label,
              onTap: items[i].onTap,
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 22.sp,
                color: Consonants.textMuted,
              ),
            ),
            if (i < items.length - 1) const AppDivider(),
          ],
        ],
      ),
    );
  }

  // ─── Logout confirmation dialog ───────────────────────────
  /// Shows an "Are you sure you want to logout?" dialog. On confirm,
  /// clears the JWT + auth state and routes the user back to login via
  /// go_router (which also wipes the navigation stack so the back
  /// button can't return into the now-logged-out tab views).
  static Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Consonants.scrim,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Consonants.surface,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Consonants.rHero.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Consonants.dangerWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 26.sp,
                    color: Consonants.danger,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  "Are you sure?",
                  style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  "You'll be signed out and returned to the login screen.",
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.paragraph().copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: "Decline",
                        kind: AppButtonKind.neutral,
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                      ),
                    ),
                    SizedBox(width: Consonants.gapButtons.w),
                    Expanded(child: _dangerButton(
                      label: "Log out",
                      onTap: () => Navigator.of(dialogCtx).pop(true),
                    )),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;
    // Order matters: drop the auth token first so any concurrent
    // request that fires while we're invalidating doesn't accidentally
    // re-fetch with the still-valid old JWT and re-prime the caches.
    await ref.read(authControllerProvider.notifier).logout();
    // Then wipe every cached user-scoped provider (profile, stats,
    // rides, search criteria, navbar tab). Without this, the next
    // user to log in / sign up would see this user's stale cached
    // data on the profile tab + everywhere it's read from.
    clearUserSession(ref);
    if (!context.mounted) return;
    context.go(Approutes.login);
  }

  /// Destructive twin of [AppButton] — the system has no danger kind, and
  /// red is reserved for exactly this.
  static Widget _dangerButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: Consonants.danger,
          borderRadius: BorderRadius.circular(Consonants.rButton.r),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.button(color: Consonants.surface)
              .copyWith(fontSize: 17.5.sp),
        ),
      ),
    );
  }

  // ─── Logout button ────────────────────────────────────────
  static Widget logoutButton({required VoidCallback onTap}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 17.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Consonants.rButton.r),
            border: Border.all(color: Consonants.danger, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 19.sp,
                color: Consonants.danger,
              ),
              SizedBox(width: 10.w),
              Text(
                "Logout",
                style: AppText.button(color: Consonants.danger)
                    .copyWith(fontSize: 17.5.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
