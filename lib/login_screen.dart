import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'student_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isSomali;
  final String role;

  const LoginScreen({super.key, required this.isSomali, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]{3,}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim().toLowerCase());
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      Map<String, String>? userData = await DatabaseHelper().authenticateUser(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        role: widget.role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isSomali
                  ? "Xogta aad gelisay waa khaldan tahay ama koontada ma jirto!"
                  : "Invalid credentials or account does not exist!",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      String savedEmail = userData['email'] ?? _emailController.text.trim().toLowerCase();
      // ✅ Magaca dhabta ah ee DB-ga ku kaydsan — la tusi doona profile-ka
      String savedName = userData['name'] ?? savedEmail;

      if (widget.role == 'Student') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDashboardScreen(
              isSomali: widget.isSomali,
              username: savedEmail,
              displayName: savedName,
              isNewUser: false,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherDashboardScreen(
              isSomali: widget.isSomali,
              username: savedEmail,
              displayName: savedName,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color textMadow = Color(0xFF1E293B);
    const Color textCirro = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textMadow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSomali ? "Ku soo laabo koontadaada" : "Welcome Back",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textMadow),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isSomali ? "Geli faahfaahintaada si aad u gasho" : "Enter your details to sign in",
                  style: const TextStyle(fontSize: 14, color: textCirro),
                ),
                const SizedBox(height: 35),

                Text(
                  widget.isSomali ? "Iimaylka" : "Email Address",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMadow),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "",
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return widget.isSomali ? "Fadlan geli iimaylkaaga" : "Please enter your email";
                    }
                    if (!_isValidEmail(value)) {
                      return widget.isSomali
                          ? "Iimaylka waa khaldan yahay (tusaale: magac@domain.com)"
                          : "Invalid email (example: name@domain.com)";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text(
                  widget.isSomali ? "Erreyga Sirta ah" : "Password",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMadow),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: textCirro),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return widget.isSomali ? "Fadlan geli password-ka" : "Please enter your password";
                    }
                    if (value.length < 6) {
                      return widget.isSomali
                          ? "Password-ku ma ka yaraan karo 6 xaraf"
                          : "Password cannot be less than 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            widget.isSomali ? "Soo gal" : "Sign In",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}