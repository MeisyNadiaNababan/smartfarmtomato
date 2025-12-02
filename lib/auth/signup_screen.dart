import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _formKey = GlobalKey<FormState>();

  /// ================= BACKEND =================
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack("Password tidak cocok", true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCred.user;

      if (user != null) {
        String role = "farmer";

        // Auto assign admin jika email mengandung kata admin
        final email = _emailController.text.toLowerCase();
        if (email.contains('admin')) role = 'admin';

        final ref = FirebaseDatabase.instance.ref("users/${user.uid}");

        await ref.set({
          "email": user.email,
          "role": role,
          "createdAt": DateTime.now().millisecondsSinceEpoch,
          "lastLogin": DateTime.now().millisecondsSinceEpoch,
          "status": "active",
          "displayName": user.email?.split("@").first ?? "User",
        });

        _showSnack("🎉 Akun berhasil dibuat! Silakan login.", false);

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SignInScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_firebaseMessage(e.code), true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case "email-already-in-use":
        return "Email sudah digunakan";
      case "weak-password":
        return "Password minimal 6 karakter";
      case "invalid-email":
        return "Format email salah";
      case "network-request-failed":
        return "Koneksi internet bermasalah";
      default:
        return "Terjadi kesalahan";
    }
  }

  void _showSnack(String text, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  Image.asset('images/tomato.png', height: 300),
                  const SizedBox(height: 10),

                  const Text(
                    "Daftar TomaFarm",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF264E36),
                    ),
                  ),

                  const SizedBox(height: 6),
                  const Text(
                    "Daftar untuk melanjutkan aplikasi TomaFarm",
                    style: TextStyle(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  _buildTextField(
                    controller: _emailController,
                    hint: "Email",
                    icon: Icons.email,
                    validator: (v) =>
                        v!.contains("@") ? null : "Email tidak valid",
                  ),
                  const SizedBox(height: 15),

                  _buildTextField(
                    controller: _passwordController,
                    hint: "Password",
                    icon: Icons.lock,
                    isPassword: true,
                    obscureValue: _obscurePassword,
                    toggle: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                    }),
                    validator: (v) => v!.length < 6
                        ? "Password minimal 6 karakter"
                        : null,
                  ),
                  const SizedBox(height: 15),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: "Konfirmasi Password",
                    icon: Icons.lock,
                    isPassword: true,
                    obscureValue: _obscureConfirmPassword,
                    toggle: () => setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }),
                    validator: (v) => v != _passwordController.text
                        ? "Password tidak cocok"
                        : null,
                  ),

                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: _isLoading ? null : _signUp,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Daftar Akun",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  RichText(
                    text: TextSpan(
                      text: "Sudah punya akun? ",
                      style: const TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Masuk di sini",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SignInScreen()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureValue = false,
    VoidCallback? toggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureValue : false,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscureValue ? Icons.visibility_off : Icons.visibility),
                onPressed: toggle,
              )
            : null,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.black26),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
