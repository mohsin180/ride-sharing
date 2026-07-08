import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/sessionRouter.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// Animated brand splash. Plays the entrance animation for a short fixed hold,
/// then auto-routes: a stored, unexpired session goes straight into the app
/// (like inDrive/Uber — no re-login after closing the app); otherwise it hands
/// off to the login screen.
class Splashscreen extends ConsumerStatefulWidget {
  const Splashscreen({super.key});

  @override
  ConsumerState<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends ConsumerState<Splashscreen>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 1400);
  static const _minHoldOnSplash = Duration(milliseconds: 1700);

  late final AnimationController _entrance;
  late final AnimationController _ambient;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _ringScale;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(vsync: this, duration: _entranceDuration);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ).drive(Tween(begin: 0.6, end: 1.0));

    _logoFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _ringScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: 0.85, end: 1.0));

    _titleSlide = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: 18.0, end: 0.0));

    _titleFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );

    _taglineFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.65, 0.95, curve: Curves.easeOut),
    );

    _dotsFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );

    _entrance.forward();
    _scheduleHandoff();
  }

  /// Holds on the splash for [_minHoldOnSplash] so the brand animation always
  /// finishes, then decides where to go. A valid stored session skips the
  /// login screen entirely (persistent login); anything missing/expired falls
  /// back to login.
  Future<void> _scheduleHandoff() async {
    // Resolve the destination while the animation plays, so there's no extra
    // wait after the hold.
    final destination = _resolveDestination();
    final results = await Future.wait([
      Future.delayed(_minHoldOnSplash),
      destination,
    ]);
    if (!mounted) return;
    context.go(results[1] as String);
  }

  /// Where to send the user based on their stored session.
  Future<String> _resolveDestination() async {
    try {
      final token = await Tokenstorage.getToken();
      // No session, or a clearly-dead one → log in (and clean up a stale token).
      if (token == null || token.isEmpty || JwtUtils.isExpired(token)) {
        if (token != null && token.isNotEmpty) {
          await Tokenstorage.deleteToken();
        }
        return Approutes.login;
      }
      final role = JwtUtils.extractRole(token);
      // Authenticated but no role yet (rare) → let login drive role selection
      // with a fresh auth state.
      if (role != "DRIVER" && role != "PASSENGER") {
        return Approutes.login;
      }
      // Valid session → straight into the app (or profile setup if incomplete).
      return await resolveHomeRouteForRole(ref, role!);
    } catch (_) {
      return Approutes.login;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _ambient]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _GradientBackdrop(),
              _AmbientBlobs(progress: _ambient.value),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    _Logo(
                      scale: _logoScale.value,
                      fade: _logoFade.value,
                      ringScale: _ringScale.value,
                      ringPulse: _ambient.value,
                    ),
                    SizedBox(height: 28.h),
                    _Title(
                      slide: _titleSlide.value,
                      fade: _titleFade.value,
                    ),
                    SizedBox(height: 10.h),
                    _Tagline(fade: _taglineFade.value),
                    const Spacer(flex: 5),
                    _LoadingDots(
                      fade: _dotsFade.value,
                      progress: _ambient.value,
                    ),
                    SizedBox(height: 28.h),
                    _Footer(fade: _taglineFade.value),
                    SizedBox(height: 18.h),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────── Background ───────────────────────

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff0596D1),
            Consonants.primaryColor,
            Color(0xff5AC8FA),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

/// Two large softly-glowing blobs that drift on a sine wave to give
/// the background a sense of depth and motion. Cheap to render — just
/// gradient-filled circles painted onto a CustomPaint.
class _AmbientBlobs extends StatelessWidget {
  final double progress;
  const _AmbientBlobs({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BlobsPainter(progress: progress),
      ),
    );
  }
}

class _BlobsPainter extends CustomPainter {
  final double progress;
  _BlobsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    void drawBlob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    drawBlob(
      Offset(
        size.width * (0.18 + 0.04 * math.sin(t)),
        size.height * (0.22 + 0.03 * math.cos(t)),
      ),
      size.width * 0.55,
      const Color(0xffB7E8FF),
    );
    drawBlob(
      Offset(
        size.width * (0.85 + 0.04 * math.cos(t * 0.8)),
        size.height * (0.78 + 0.03 * math.sin(t * 0.8)),
      ),
      size.width * 0.55,
      const Color(0xff6FCBFF),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) => old.progress != progress;
}

// ─────────────────────── Logo ───────────────────────

class _Logo extends StatelessWidget {
  final double scale;
  final double fade;
  final double ringScale;
  final double ringPulse;

  const _Logo({
    required this.scale,
    required this.fade,
    required this.ringScale,
    required this.ringPulse,
  });

  @override
  Widget build(BuildContext context) {
    final pulse = 0.5 + 0.5 * math.sin(ringPulse * 2 * math.pi);

    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: 200.w,
          height: 200.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer breathing halo.
              Transform.scale(
                scale: ringScale + 0.05 * pulse,
                child: Container(
                  width: 200.w,
                  height: 200.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              // Mid ring.
              Transform.scale(
                scale: ringScale - 0.05 + 0.04 * pulse,
                child: Container(
                  width: 160.w,
                  height: 160.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              // Solid logo badge.
              Container(
                width: 110.w,
                height: 110.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff0596D1).withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.30),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xff0596D1),
                      Consonants.primaryColor,
                      Color(0xff5AC8FA),
                    ],
                  ).createShader(rect),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 60.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Title + tagline ───────────────────────

class _Title extends StatelessWidget {
  final double slide;
  final double fade;

  const _Title({required this.slide, required this.fade});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(0, slide),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontFamily: Consonants.fontFamily,
              fontSize: 34.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: const Color(0xff0596D1).withValues(alpha: 0.40),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            children: [
              const TextSpan(text: "Safe"),
              TextSpan(
                text: "Ride",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  final double fade;
  const _Tagline({required this.fade});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 36.w),
        child: Text(
          "Share the ride. Save the day.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Consonants.fontFamily,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Loading dots ───────────────────────

class _LoadingDots extends StatelessWidget {
  final double fade;
  final double progress;

  const _LoadingDots({required this.fade, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = (progress * 2 * math.pi) - (i * 0.6);
          final t = (math.sin(phase) + 1) / 2;
          final dotOpacity = 0.35 + 0.65 * t;
          final dotScale = 0.85 + 0.30 * t;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Transform.scale(
              scale: dotScale,
              child: Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: dotOpacity),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────── Footer ───────────────────────

class _Footer extends StatelessWidget {
  final double fade;
  const _Footer({required this.fade});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade,
      child: Text(
        "v1.0  ·  © SafeRide",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: Consonants.fontFamily,
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
