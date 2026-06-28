import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LoginPortalScreen extends StatefulWidget {
  final bool isSomali;
  const LoginPortalScreen({super.key, required this.isSomali});

  @override
  State<LoginPortalScreen> createState() => _LoginPortalScreenState();
}

class _LoginPortalScreenState extends State<LoginPortalScreen> {
  String _selectedRole = 'Student'; // Doorashada rasmiga ah (Default)

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color textMadow = Color(0xFF1E293B);
    const Color textCirro = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Qaybta Sare: Dib u laabashada oo nadiif ah (No text label above)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textMadow, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Qaybta Dhexe: Koontada nooca ay tahay
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isSomali ? "Dooro Nooca Koontada" : "Choose Account Type",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textMadow),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isSomali 
                        ? "Fadlan dooro haddii aad tahay Arday baranaya casharrada ama Macallin bixinaya."
                        : "Please select whether you are a Student learning or a Teacher instructing.",
                    style: const TextStyle(fontSize: 14, color: textCirro, height: 1.4),
                  ),
                  const SizedBox(height: 35),

                  // CARD 1: STUDENT (ARDAY)
                  GestureDetector(
                    onTap: () => setState(() => _selectedRole = 'Student'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'Student' ? primaryBlue.withAlpha(15) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedRole == 'Student' ? primaryBlue : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'Student' ? primaryBlue : const Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isSomali ? "Arday" : "Student",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMadow),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isSomali ? "Waxaan rabaa inaan barto casharrada" : "I want to access offline courses",
                                style: const TextStyle(fontSize: 12, color: textCirro),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CARD 2: TEACHER (MACALLIN)
                  GestureDetector(
                    onTap: () => setState(() => _selectedRole = 'Teacher'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'Teacher' ? primaryBlue.withAlpha(15) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedRole == 'Teacher' ? primaryBlue : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'Teacher' ? primaryBlue : const Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isSomali ? "Macallin" : "Teacher",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMadow),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isSomali ? "Waxaan rabaa inaan cashar gudbiyo" : "I want to share local materials",
                                style: const TextStyle(fontSize: 12, color: textCirro),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Qaybta Hoose: Badhanka sii socoshada iyo Sign Up-ka linkiisa
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(
                              isSomali: widget.isSomali,
                              role: _selectedRole,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.isSomali ? "Sii soco" : "Continue",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.isSomali ? "Koonto ma haysatid? " : "Don't have an account? ",
                        style: const TextStyle(color: textCirro, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupScreen(
                                isSomali: widget.isSomali,
                                role: _selectedRole,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign up",
                          style: TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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