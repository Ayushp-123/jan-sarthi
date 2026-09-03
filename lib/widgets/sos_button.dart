import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onPressed;

  const SOSButton({super.key, required this.onPressed});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // Continuous 360-degree radar wave ripple
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Subtle organic breathing scale
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  void _handleTap() {
    HapticFeedback.heavyImpact();
    widget.onPressed();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  Widget _buildRadarRing(double delay, double maxScale, double initialOpacity) {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        double progress = (_radarController.value + delay) % 1.0;
        double scale = 1.0 + (maxScale - 1.0) * progress;
        double opacity = (1.0 - progress) * initialOpacity;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 175,
            height: 175,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: opacity.clamp(0.0, 1.0)),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: (opacity * 0.4).clamp(0.0, 1.0)),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _handleTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Concentric Multi-Ring Radar Waves
            _buildRadarRing(0.0, 1.6, 0.45),
            _buildRadarRing(0.33, 1.85, 0.35),
            _buildRadarRing(0.66, 2.1, 0.25),

            // Main Interactive SOS Button with Breathing Animation & Touch Bounce
            AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                double baseScale = _isPressed ? 0.92 : _breathingAnimation.value;
                return Transform.scale(
                  scale: baseScale,
                  child: Container(
                    width: 165,
                    height: 165,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.emergencyGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryRed.withValues(alpha: _isPressed ? 0.65 : 0.4),
                          blurRadius: _isPressed ? 32 : 24,
                          spreadRadius: _isPressed ? 6 : 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 3.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner Subtle Radial Highlight
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.4),
                              radius: 0.8,
                              colors: [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        // Button Text & Icon
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'HELP',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'TAP TO SOS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.95),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
