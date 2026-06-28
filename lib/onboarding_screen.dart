import 'package:flutter/material.dart';
import 'login_portal_screen.dart';

class OnboardingScreen extends StatelessWidget {
  final bool isSomali;
  const OnboardingScreen({super.key, required this.isSomali});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Qaybta Sare: Kaliya badhanka dib u laabashada (No text label)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Qaybta Dhexe: Qoraalka iyo Labada Talefon
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSomali ? "Baro. Wadaag. Kor u qaad." : "Learn. Share. Elevate.",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSomali 
                        ? "Baro offline, la wadaag asxaabtaada adigoo isticmaalaya xiriirka tooska ah ee Bluetooth-ka."
                        : "Learn offline, share with your friends using a direct Bluetooth peer link.",
                    style: TextStyle(fontSize: 15, color: Colors.white.withAlpha(220), height: 1.5),
                  ),
                  const SizedBox(height: 40),

                  // NAQSHADDA LABADA TELEFON IYO BLUETOOTH-KA
                  Center(
                    child: SizedBox(
                      width: 280,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Taleefanka Bidix
                          Positioned(
                            left: 10,
                            child: Container(
                              width: 65,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(150), width: 2),
                              ),
                              child: const Icon(Icons.person_outline, color: Colors.white),
                            ),
                          ),
                          // Taleefanka Midig
                          Positioned(
                            right: 10,
                            child: Container(
                              width: 65,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(150), width: 2),
                              ),
                              child: const Icon(Icons.person_outline, color: Colors.white),
                            ),
                          ),
                          // Mowjadaha Xiriirka dhexda ah (P2P Wireless Link)
                          Positioned(
                            child: Container(
                              width: 100,
                              height: 2,
                              color: Colors.white.withAlpha(100),
                            ),
                          ),
                          // Astaanta Bluetooth-ka ee Dhexda taagan
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bluetooth_audio_rounded, color: primaryBlue, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      isSomali ? "100% Offline. 100% Adiga." : "100% Offline. 100% You.",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),

              // Qaybta Hoose: Indicators iyo Next Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white.withAlpha(100), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white.withAlpha(100), shape: BoxShape.circle)),
                    ],
                  ),
                  FloatingActionButton(
                    heroTag: "btn_onboarding_new",
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginPortalScreen(isSomali: isSomali),
                        ),
                      );
                    },
                    child: const Icon(Icons.arrow_forward_rounded, color: primaryBlue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}