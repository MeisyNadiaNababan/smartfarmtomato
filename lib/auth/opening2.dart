import 'package:flutter/material.dart';
import 'signin_screen.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // BACKGROUND IMAGE FULL
          Positioned.fill(
            child: Image.asset(
              'images/farm2.png', // ganti sesuai asset gambar kamu
              fit: BoxFit.cover,
            ),
          ),

          // BOTTOM WHITE PANEL
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // TITLE
                  const Text(
                    "Nurture Your Tomatoes the\nSmart Way.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // DESCRIPTION
                  const Text(
                    "Let intelligent care recommendations support your tomato plants’ growth and ensure a bountiful harvest.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NEXT BUTTON
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
                          MaterialPageRoute(
                            builder: (_) => const SignInScreen(),
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

                  // IOS HOME INDICATOR FAKE LINE (opsional, biar kayak screenshot)
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
