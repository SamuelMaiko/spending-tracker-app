import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';

/// Animated splash screen with SpendTracker branding
///
/// This screen displays the app logo, name, and subtitle with animations
/// and a beautiful gradient background matching the design mockup
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _loadingRotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Loading animation controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Logo scale animation (bounce effect)
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Logo opacity animation
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    // Text opacity animation
    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Loading rotation animation
    _loadingRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );
  }

  void _startAnimations() async {
    // Start logo animation
    await _logoController.forward();

    // Start text animation after logo
    await _textController.forward();

    // Start loading animation
    _loadingController.repeat();

    // Navigate to main app after splash duration
    Future.delayed(AppConstants.splashDuration, () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScaleAnimation.value,
                  child: Opacity(
                    opacity: _logoOpacityAnimation.value,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            // const SizedBox(height: 32),

            // // Animated text
            // AnimatedBuilder(
            //   animation: _textController,
            //   builder: (context, child) {
            //     return Opacity(
            //       opacity: _textOpacityAnimation.value,
            //       child: Text(
            //         'Spending Tracker',
            //         style: TextStyle(
            //           fontSize: 32,
            //           fontWeight: FontWeight.w700,
            //           color: Colors.grey.shade800,
            //           letterSpacing: 1.2,
            //         ),
            //       ),
            //     );
            //   },
            // ),

            // const SizedBox(height: 60),

            // Simple loading indicator
            // AnimatedBuilder(
            //   animation: _loadingController,
            //   builder: (context, child) {
            //     return Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: List.generate(3, (index) {
            //         final delay = index * 0.3;
            //         final animValue =
            //             (_loadingRotationAnimation.value + delay) % 1.0;
            //         final scale =
            //             0.5 + (0.5 * math.sin(animValue * 2 * 3.14159));

            //         return Container(
            //           margin: const EdgeInsets.symmetric(horizontal: 4),
            //           child: Transform.scale(
            //             scale: scale,
            //             child: Container(
            //               width: 8,
            //               height: 8,
            //               decoration: BoxDecoration(
            //                 color: Colors.grey.shade400,
            //                 shape: BoxShape.circle,
            //               ),
            //             ),
            //           ),
            //         );
            //       }),
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
