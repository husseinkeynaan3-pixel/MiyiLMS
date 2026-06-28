import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database_helper.dart';
import 'onboarding_screen.dart';
import 'student_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final dbHelper = DatabaseHelper();
  Map<String, String>? activeSession = await dbHelper.getCurrentUserSession();

  runApp(MiyiLMS(activeSession: activeSession));
}

class MiyiLMS extends StatelessWidget {
  final Map<String, String>? activeSession;

  const MiyiLMS({super.key, this.activeSession});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);

    Widget initialHomeScreen;

    if (activeSession != null) {
      String role = activeSession!['role'] ?? 'Student';
      String email = activeSession!['email'] ?? '';
      String name = activeSession!['name'] ?? email;

      if (role == 'Teacher') {
        initialHomeScreen = TeacherDashboardScreen(
          isSomali: true,
          username: email,
          displayName: name,
        );
      } else {
        initialHomeScreen = StudentDashboardScreen(
          isSomali: true,
          username: email,
          displayName: name,
          isNewUser: false,
        );
      }
    } else {
      initialHomeScreen = const LanguageSelectionScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Miyi LMS',
      theme: ThemeData(
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      home: initialHomeScreen,
    );
  }
}

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 10),

              Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.school_rounded, size: 42, color: primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  const Text('Ku soo dhawow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 10),
                  const Text('Dooro luqaddaada\nChoose your language', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w500, height: 1.4)),
                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingScreen(isSomali: true))),
                    child: _buildLanguageButton("Somali", "🇸🇴", primaryBlue, true),
                  ),
                  const SizedBox(height: 14),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingScreen(isSomali: false))),
                    child: _buildLanguageButton("English", "🇬🇧", const Color(0xFFF1F5F9), false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(String text, String flag, Color color, bool isSomali) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isSomali ? color : color,
        borderRadius: BorderRadius.circular(14),
        border: isSomali ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: isSomali ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSomali ? Colors.white : const Color(0xFF1E293B))),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: isSomali ? Colors.white : const Color(0xFF94A3B8), size: 14),
        ],
      ),
    );
  }
}