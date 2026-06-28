import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'student_dashboard_screen.dart';
import 'teacher_dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  final bool isSomali;
  final String role;

  const SignupScreen({super.key, required this.isSomali, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]{3,}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim().toLowerCase());
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      bool hasInternet = await _checkInternetConnection();
      if (!mounted) return;

      if (!hasInternet) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isSomali
                  ? "Fadlan is-diiwaangelintu waxay u baahan tahay internet! Shid khadka."
                  : "Sign up requires an internet connection! Please check your network.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      bool isRegistered = await DatabaseHelper().registerUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
        role: widget.role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!isRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isSomali
                  ? "Iimaylkan horay ayaa loo isticmaalay! Isku day mid kale."
                  : "This email is already registered! Try another one.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String savedEmail = _emailController.text.trim().toLowerCase();
      // ✅ Magaca dhabta ah ee user-ku geliyay — la tusi doona profile-ka
      String savedName = _nameController.text.trim();

      if (widget.role == 'Student') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDashboardScreen(
              isSomali: widget.isSomali,
              username: savedEmail,
              displayName: savedName,
              isNewUser: true,
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    const Color textMadow = Color(0xFF1E293B);

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
                  widget.isSomali ? "Abuur Akoon Cusub" : "Create Account",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textMadow),
                ),
                const SizedBox(height: 30),

                Text(widget.isSomali ? "Magacaaga Buuxa" : "Full Name",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? (widget.isSomali ? "Geli magacaaga" : "Enter your name")
                      : null,
                ),
                const SizedBox(height: 18),

                Text(widget.isSomali ? "Iimaylka" : "Email Address",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return widget.isSomali ? "Geli iimaylka" : "Enter email";
                    }
                    if (!_isValidEmail(value)) {
                      return widget.isSomali
                          ? "Iimaylka waa khaldan yahay (tusaale: magac@domain.com)"
                          : "Invalid email (example: name@domain.com)";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                Text(widget.isSomali ? "Erreyga Sirta ah" : "Password",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return widget.isSomali ? "Geli password-ka" : "Enter password";
                    }
                    if (value.length < 6) {
                      return widget.isSomali
                          ? "Password-ku ma ka yaraan karo 6 xaraf"
                          : "Password must be at least 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 35),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            widget.isSomali ? "Dhammaystir" : "Sign Up",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
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