import 'package:flutter/material.dart';
import 'opening2.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  // --- FUNC: Custom Route Transition (Slide Left to Next Screen) ---
  Route _slideLeftTransition(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        
        // Posisi mulai dari kanan → menuju layar
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final curve = Curves.easeOut;

        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // --- PART 1: BACKGROUND IMAGE FULL SCREEN ---
          Positioned.fill(
            child: Image.asset(
              'images/farm.png',
              fit: BoxFit.cover,
            ),
          ),

          // --- PART 2: BOTTOM WHITE CONTENT PANEL ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.33,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 22,
              ),

              // --- PART 3: TEXT AND BUTTON CONTENT ---
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ---- TEXT TITLE ----
                  const Text(
                    "Monitor Your Plant’s\nGrowth in Real Time.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ---- TEXT SUB-DESCRIPTION ----
                  const Text(
                    "Get detailed, up-to-date insights about your plant’s growth, helping you understand its needs and keep it healthy every day.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---- NEXT BUTTON (Triggers Page Transition) ----
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF264E36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          _slideLeftTransition(
                            const Onboarding(), // Target Page: opening2.dart
                          ),
                        );
                      },
                      child: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // --- PART 4: iOS HOME SWIPE INDICATOR (Decoration) ---
                  Container(
                    width: 80,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
