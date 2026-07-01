import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ── SuperSonicAura ───────────────────────────────────────────────────────────

/// Wraps [child] with an animated golden aura, upward-rising sparks, and wispy
/// tendrils when [active] is true.
///
/// The glow is drawn as a squircle (rounded-rect) ring that hugs the art edge
/// and blooms outward — it never covers the child itself, and all overflow
/// painting is handled via a [Stack] with [Clip.none] so nothing escapes its
/// layout bounds unexpectedly from the perspective of parent widgets.
///
/// When [active] is false the widget renders [child] directly with no overhead.
class SuperSonicAura extends StatefulWidget {
  final Widget child;
  final bool active;

  /// Width of the glow band drawn around [child].
  final double glowPadding;

  /// Corner radius of the art (should match the child's own border radius).
  final double artRadius;

  /// How far the canvas layer bleeds outside the layout box in every direction.
  /// Reducing this constrains how far sparks and tendrils can wander outside
  /// the widget boundary. Default 44; use a smaller value in tight spaces like
  /// the mini-player.
  final double canvasOverflow;

  const SuperSonicAura({
    super.key,
    required this.child,
    required this.active,
    this.glowPadding = 14,
    this.artRadius = 16,
    this.canvasOverflow = 44,
  });

  @override
  State<SuperSonicAura> createState() => _SuperSonicAuraState();
}

class _SuperSonicAuraState extends State<SuperSonicAura>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Ticker? _ticker;
  double _elapsed = 0.0;
  late List<_Spark> _sparks;
  late List<_Tendril> _tendrils;
  final math.Random _rng = math.Random();

  static const int _sparkCount = 22;
  static const int _tendrilCount = 6;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _sparks = List.generate(_sparkCount, (_) => _Spark.spawn(_rng));
    _tendrils = List.generate(
      _tendrilCount,
      (i) => _Tendril.spawn(_rng, i, _tendrilCount),
    );
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(SuperSonicAura old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _start();
    } else if (!widget.active && old.active) {
      _stop();
    }
  }

  void _start() {
    _pulseController.repeat(reverse: true);
    _ticker ??= createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      final dt = t - _elapsed;
      _elapsed = t;
      setState(() {
        for (final s in _sparks) {
          s.update(dt, _rng);
        }
        for (final t in _tendrils) {
          t.update(dt, _rng);
        }
      });
    });
    _ticker!.start();
  }

  void _stop() {
    _pulseController.stop();
    _ticker?.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    final pad = widget.glowPadding;
    // Extra bleed so sparks can travel outside the widget boundary.
    final overflow = widget.canvasOverflow;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Drives layout size — padded child.
            Padding(padding: EdgeInsets.all(pad), child: widget.child),
            // Paint layer inflated outward; does not contribute to layout.
            Positioned(
              left: -overflow,
              top: -overflow,
              right: -overflow,
              bottom: -overflow,
              child: CustomPaint(
                isComplex: true,
                willChange: true,
                painter: _AuraPainter(
                  pulse: _pulseController.value,
                  sparks: _sparks,
                  tendrils: _tendrils,
                  glowPadding: pad + overflow,
                  artRadius: widget.artRadius,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Spark ─────────────────────────────────────────────────────────────────────

/// A small glowing particle that spawns along the art border and drifts upward.
class _Spark {
  /// Edge: 0=bottom, 1=left, 2=right.
  int edge;
  double edgeT; // normalised position along the edge [0..1]
  double outward; // distance into padding band, normalised [0..1]
  double progress; // life [0..1]
  double speed;
  double radius;
  double opacity;
  double sinePhase;
  double sineFreq;
  double sineAmp;

  _Spark({
    required this.edge,
    required this.edgeT,
    required this.outward,
    required this.progress,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.sinePhase,
    required this.sineFreq,
    required this.sineAmp,
  });

  factory _Spark.spawn(math.Random rng, {double? initialProgress}) {
    final edgeRoll = rng.nextDouble();
    final int edge;
    if (edgeRoll < 0.55) {
      edge = 0; // bottom — most sparks rise upward
    } else if (edgeRoll < 0.775) {
      edge = 1; // left
    } else {
      edge = 2; // right
    }
    return _Spark(
      edge: edge,
      edgeT: rng.nextDouble(),
      outward: rng.nextDouble() * 0.4,
      progress: initialProgress ?? rng.nextDouble(),
      speed: 0.14 + rng.nextDouble() * 0.18,
      radius: 1.2 + rng.nextDouble() * 2.2,
      opacity: 0.0,
      sinePhase: rng.nextDouble() * math.pi * 2,
      sineFreq: 1.0 + rng.nextDouble() * 1.5,
      sineAmp: 0.015 + rng.nextDouble() * 0.03,
    );
  }

  void update(double dt, math.Random rng) {
    progress += speed * dt;
    outward = (outward + dt * 0.06).clamp(0.0, 1.0);
    sinePhase += sineFreq * dt;

    opacity =
        progress < 0.12
            ? progress / 0.12
            : progress > 0.70
            ? (1.0 - progress) / 0.30
            : 1.0;
    opacity *= 0.75;

    if (progress >= 1.0) {
      final fresh = _Spark.spawn(rng, initialProgress: 0.0);
      edge = fresh.edge;
      edgeT = fresh.edgeT;
      outward = fresh.outward;
      progress = 0.0;
      speed = fresh.speed;
      radius = fresh.radius;
      sinePhase = fresh.sinePhase;
      sineFreq = fresh.sineFreq;
      sineAmp = fresh.sineAmp;
    }
  }

  Offset toOffset(Rect artRect, double pad) {
    final wiggle = sineAmp * math.sin(sinePhase) * pad;
    switch (edge) {
      case 0:
        final x = artRect.left + edgeT * artRect.width + wiggle;
        final y =
            artRect.bottom +
            outward * pad * 0.5 -
            progress * (artRect.height + pad * 1.4);
        return Offset(x, y);
      case 1:
        final y =
            artRect.bottom -
            edgeT * artRect.height -
            progress * artRect.height * 0.6 +
            wiggle;
        final x = artRect.left - outward * pad * 0.9;
        return Offset(x, y);
      case 2:
        final y =
            artRect.bottom -
            edgeT * artRect.height -
            progress * artRect.height * 0.6 +
            wiggle;
        final x = artRect.right + outward * pad * 0.9;
        return Offset(x, y);
      default:
        return artRect.center;
    }
  }
}

// ── Tendril ───────────────────────────────────────────────────────────────────

class _Tendril {
  double angle;
  double angleSpeed;
  double reach;

  // Two independent wobble oscillators for chaotic control-point motion.
  double wobblePhase1;
  double wobbleSpeed1;
  double wobblePhase2;
  double wobbleSpeed2;

  // Each control point has its own reach multiplier so the curve is asymmetric.
  double cp1Reach;
  double cp2Reach;

  double length;
  double strokeWidth;

  double opacity;
  double opacityPhase;
  double opacitySpeed;

  _Tendril({
    required this.angle,
    required this.angleSpeed,
    required this.reach,
    required this.wobblePhase1,
    required this.wobbleSpeed1,
    required this.wobblePhase2,
    required this.wobbleSpeed2,
    required this.cp1Reach,
    required this.cp2Reach,
    required this.length,
    required this.strokeWidth,
    required this.opacity,
    required this.opacityPhase,
    required this.opacitySpeed,
  });

  factory _Tendril.spawn(math.Random rng, int index, int total) {
    return _Tendril(
      angle: (index / total) * math.pi * 2 + rng.nextDouble() * 0.9,
      angleSpeed: (0.20 + rng.nextDouble() * 0.35) * (rng.nextBool() ? 1 : -1),
      reach: 0.25 + rng.nextDouble() * 0.65,
      wobblePhase1: rng.nextDouble() * math.pi * 2,
      wobbleSpeed1: 1.2 + rng.nextDouble() * 2.2,
      wobblePhase2: rng.nextDouble() * math.pi * 2,
      wobbleSpeed2: 0.7 + rng.nextDouble() * 1.8,
      cp1Reach: 0.3 + rng.nextDouble() * 0.9,
      cp2Reach: 0.3 + rng.nextDouble() * 0.9,
      length: 0.3 + rng.nextDouble() * 1.1,
      strokeWidth: 0.8 + rng.nextDouble() * 1.4,
      opacity: 0.0,
      opacityPhase: rng.nextDouble() * math.pi * 2,
      opacitySpeed: 0.6 + rng.nextDouble() * 1.0,
    );
  }

  void update(double dt, math.Random rng) {
    angle += angleSpeed * dt;
    wobblePhase1 += wobbleSpeed1 * dt;
    wobblePhase2 += wobbleSpeed2 * dt;
    opacityPhase += opacitySpeed * dt;
    // Flicker more aggressively than before.
    opacity = (0.15 +
            0.20 * math.sin(opacityPhase) +
            0.08 * math.sin(opacityPhase * 2.3))
        .clamp(0.0, 1.0);
  }

  void draw(Canvas canvas, Rect artRect, double pad, Paint paint) {
    final rx = artRect.width / 2 + pad * reach;
    final ry = artRect.height / 2 + pad * reach;
    final cx = artRect.center.dx;
    final cy = artRect.center.dy;

    final a0 = angle;
    final a1 = angle + length;

    Offset pt(double a, double extraR) => Offset(
      cx + (rx + extraR) * math.cos(a),
      cy + (ry + extraR) * math.sin(a),
    );

    final p0 = pt(a0, 0);
    final p3 = pt(a1, 0);

    // Each control point wobbles independently on its own oscillator so the
    // curve can twist and fold back on itself.
    final w1 = math.sin(wobblePhase1) * pad * cp1Reach;
    final w2 = math.cos(wobblePhase2) * pad * cp2Reach;
    final cp1 = pt(a0 + length * 0.30, w1);
    final cp2 = pt(a0 + length * 0.70, w2);

    final path =
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p3.dx, p3.dy);

    paint
      ..color = const Color(0xFFFFE033).withValues(alpha: opacity)
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, paint);
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AuraPainter extends CustomPainter {
  final double pulse;
  final List<_Spark> sparks;
  final List<_Tendril> tendrils;
  final double glowPadding;
  final double artRadius;

  const _AuraPainter({
    required this.pulse,
    required this.sparks,
    required this.tendrils,
    required this.glowPadding,
    required this.artRadius,
  });

  static const Color _gold = Color(0xFFFFE033);
  static const Color _amber = Color(0xFFFFB300);
  static const Color _paleGold = Color(0xFFFFF176);

  @override
  void paint(Canvas canvas, Size size) {
    final pad = glowPadding;
    final artRect = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );

    // ── Clip: cut out the art so we never paint over the child ───────────────
    final artCutout =
        Path()
          ..addRect(const Rect.fromLTWH(-4096, -4096, 8192, 8192))
          ..addRRect(
            RRect.fromRectAndRadius(artRect, Radius.circular(artRadius)),
          )
          ..fillType = PathFillType.evenOdd;
    canvas.save();
    canvas.clipPath(artCutout);

    // ── Squircle glow ────────────────────────────────────────────────────────
    // A single wide blurred stroke following the art's rounded-rect silhouette.
    // The large blur radius spreads it into a smooth halo with no visible rings.
    final glowAlpha = 0.55 + pulse * 0.30;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        artRect.inflate(2.0),
        Radius.circular(artRadius + 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pad * 2.4
        ..color = _amber.withValues(alpha: glowAlpha * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pad * 1.8),
    );
    // Brighter, tighter inner bloom layered on top for a hot-edge feel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        artRect.inflate(1.0),
        Radius.circular(artRadius + 1),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pad * 0.9
        ..color = _gold.withValues(alpha: glowAlpha * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pad * 0.6),
    );
    // Crisp bright rim right at the art edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        artRect.inflate(0.5),
        Radius.circular(artRadius + 1),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + pulse * 1.0
        ..color = _paleGold.withValues(alpha: 0.75 + pulse * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // ── Tendrils ─────────────────────────────────────────────────────────────
    final tendrilPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final t in tendrils) {
      t.draw(canvas, artRect, pad, tendrilPaint);
    }

    // ── Sparks ───────────────────────────────────────────────────────────────
    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (final s in sparks) {
      final offset = s.toOffset(artRect, pad);
      if (artRect.contains(offset)) continue;
      final alpha = s.opacity.clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;
      final color = Color.lerp(
        _amber,
        _paleGold,
        s.edgeT,
      )!.withValues(alpha: alpha);
      sparkPaint
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.radius * 0.8);
      canvas.drawCircle(offset, s.radius, sparkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) => true;
}
