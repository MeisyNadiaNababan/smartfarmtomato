import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_user.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../navigation/farmer_navigation.dart';
import '../navigation/admin_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool loading = false;
  bool hidePass = true;
  bool rememberMe = false; // Variabel untuk checkbox Remember Me

  @override
  void initState() {
    super.initState();
    // Load saved email saat screen pertama dibuka
    _loadSavedEmail();
  }

  // Fungsi untuk memuat email yang tersimpan
  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRememberMe = prefs.getBool('rememberMe') ?? false;
      final savedEmail = prefs.getString('savedEmail') ?? '';

      if (savedRememberMe && savedEmail.isNotEmpty) {
        setState(() {
          rememberMe = savedRememberMe;
          _email.text = savedEmail;
        });
      }
    } catch (e) {
      print("Error loading saved email: $e");
    }
  }

  // Fungsi untuk menyimpan email jika Remember Me dicentang
  Future<void> _saveLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (rememberMe) {
      // Simpan email dan status Remember Me
      await prefs.setString('savedEmail', _email.text.trim());
      await prefs.setBool('rememberMe', true);
    } else {
      // Hapus data jika Remember Me tidak dicentang
      await prefs.remove('savedEmail');
      await prefs.setBool('rememberMe', false);
    }
  }

  // Fungsi untuk menghapus data login yang tersimpan
  Future<void> _clearSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedEmail');
    await prefs.setBool('rememberMe', false);
  }

  // ================= LOGIN FUNCTION BACKEND =================
  Future<void> _login() async {
    if (!_form.currentState!.validate()) {
      // Field kosong akan ditangani oleh validator
      return;
    }

    setState(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      if (cred.user != null) {
        await AppUser.preloadUser(cred.user!.uid);
        final userData = await AppUser.getUserRole(cred.user!.uid);

        if (mounted) {
          // SIMPAN EMAIL JIKA REMEMBER ME DICENTANG
          await _saveLoginData();

          // Pesan sukses untuk Login Valid
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login berhasil"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Akses ke Dashboard sesuai role
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => userData['role'] == 'admin'
                  ? const AdminNavigation()
                  : const FarmerNavigation(),
            ),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Terjadi kesalahan";

      // Sesuaikan pesan error sesuai test case
      switch (e.code) {
        case "user-not-found":
          msg = "Email tidak ditemukan"; // Untuk Email Tidak Terdaftar
          break;
        case "wrong-password":
          msg = "Password salah. Coba lagi."; // Untuk Password Salah
          break;
        case "invalid-email":
          msg = "Format email salah";
          break;
        case "invalid-credential":
          msg = "Email atau password salah";
          break;
        case "network-request-failed":
          msg = "Koneksi bermasalah. Periksa jaringan Anda.";
          break;
        case "too-many-requests":
          msg = "Terlalu banyak percobaan. Coba lagi nanti.";
          break;
        case "user-disabled":
          msg = "Akun dinonaktifkan. Hubungi administrator.";
          break;
        default:
          msg = "Login gagal: ${e.message}";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ========================== UI ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 100),

                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 10),

                // Logo
                Image.asset(
                  'images/tomato.png',
                  height: 250,
                ),

                const SizedBox(height: 20),

                // TITLE
                const Text(
                  "Selamat Datang",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF264E36),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Masuk untuk melanjutkan aplikasi TomaFarm",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 30),

                // Email Field
                TextFormField(
                  controller: _email,
                  decoration:
                      _inputDecoration("Email Address", Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Email tidak boleh kosong"; // Field Kosong
                    }
                    if (!v.contains("@") || !v.contains(".")) {
                      return "Email tidak valid";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _pass,
                  obscureText: hidePass,
                  decoration:
                      _inputDecoration("Enter Password", Icons.lock_outline)
                          .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          hidePass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => hidePass = !hidePass),
                      tooltip: hidePass ? "Show Password" : "Hide Password",
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Password tidak boleh kosong"; // Field Kosong
                    }
                    if (v.length < 6) {
                      return "Minimal 6 karakter";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // Remember Me & Forgot Password Row
                Row(
                  children: [
                    // Checkbox Remember Me
                    Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                      activeColor: Colors.red.shade800,
                    ),
                    const Text(
                      "Remember Me",
                      style: TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    
                    // Tombol Forgot Password
                    TextButton(
                      onPressed: () {
                        // Navigate ke Forgot Password Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Lupa Password?",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : const Text(
                            "Masuk",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Register Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Belum punya akun? "),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                      child: const Text(
                        "Daftar di sini",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Tombol Reset Saved Data (untuk testing, opsional)
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    await _clearSavedData();
                    _email.clear();
                    setState(() => rememberMe = false);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Data login direset'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'Reset Saved Data',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Input Styling Reusable
  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }
}