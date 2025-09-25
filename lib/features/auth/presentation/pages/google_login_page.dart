import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Simple login page with animated text and Google Sign-In
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _textAnimation;

  final List<Map<String, dynamic>> _texts = [
    {
      "text": "Let's track",
      "textColor": const Color(0xFF2196F3), // Blue
      "dotColor": const Color(0xFF4CAF50), // Green
    },
    {
      "text": "Let's save",
      "textColor": const Color(0xFF9C27B0), // Purple
      "dotColor": const Color(0xFFFF9800), // Orange
    },
    {
      "text": "Let's grow",
      "textColor": const Color(0xFF4CAF50), // Green
      "dotColor": const Color(0xFFE91E63), // Pink
    },
    {
      "text": "Let's invest",
      "textColor": const Color(0xFFFF5722), // Deep Orange
      "dotColor": const Color(0xFF2196F3), // Blue
    },
  ];

  int _currentTextIndex = 0;
  bool _isErasing = false;

  void _signInWithGoogle() {
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create animation
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start the animation cycle
    _startAnimationCycle();
  }

  void _startAnimationCycle() async {
    while (mounted) {
      // Show text
      _isErasing = false;
      await _animationController.forward();

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 1500));

      // Erase text
      _isErasing = true;
      await _animationController.reverse();

      // Move to next text
      if (mounted) {
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % _texts.length;
        });
      }

      // Wait a bit before next cycle
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushReplacementNamed('/main');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return SafeArea(
              child: Column(
                children: [
                  // Main content area with animated text
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _textAnimation,
                        builder: (context, child) {
                          final currentTextData = _texts[_currentTextIndex];
                          final currentText = currentTextData['text'] as String;
                          final textColor =
                              currentTextData['textColor'] as Color;
                          final dotColor = currentTextData['dotColor'] as Color;

                          final visibleLength =
                              (_textAnimation.value * currentText.length)
                                  .round();
                          final displayText = _isErasing
                              ? currentText.substring(
                                  0,
                                  currentText.length - visibleLength,
                                )
                              : currentText.substring(0, visibleLength);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              // Animated dot - larger size (half the height of text)
                              Container(
                                width: 16, // Larger dot
                                height: 16, // Larger dot
                                margin: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom button area
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: state is AuthLoading
                            ? null
                            : _signInWithGoogle,
                        icon: state is AuthLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.grey,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.login,
                                color: Colors.grey,
                                size: 20,
                              ),
                        label: Text(
                          state is AuthLoading
                              ? 'Signing in...'
                              : 'Continue with Google',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: const BorderSide(
                              color: Colors.grey,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
