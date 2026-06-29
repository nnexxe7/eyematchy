import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart'; // 🚀 Import ekranu resetowania hasła

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // 🚀 NOWE: Zmienne do obsługi przypiętego powiadomienia
  String? _bannerMessage;
  bool _isBannerError = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🚀 NOWE: Własna funkcja pokazująca baner na samej górze
  void _showCustomTopBanner(String message, {bool isError = true}) {
    setState(() {
      _bannerMessage = message;
      _isBannerError = isError;
    });

    // Baner znika automatycznie po 4 sekundach
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _bannerMessage == message) {
        setState(() {
          _bannerMessage = null;
        });
      }
    });
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showCustomTopBanner('Uzupełnij e-mail i hasło!', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        _showCustomTopBanner('Zalogowano pomyślnie!', isError: false);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Wystąpił błąd logowania.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Błędny e-mail lub hasło.';
      } else if (e.code == 'invalid-email') {
        message = 'Format adresu e-mail jest niepoprawny.';
      }

      if (mounted) {
        _showCustomTopBanner(message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        _showCustomTopBanner('Witaj ${googleUser.displayName}! (Zalogowano przez Google)', isError: false);
      }
    } catch (error) {
      if (mounted) {
        _showCustomTopBanner('Wystąpił błąd podczas logowania przez Google.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 🚀 WARSTWA 1 (Pod spodem): Przewijany formularz
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60), // Margines, żeby baner nie zasłaniał logo na start
                      const Text(
                        'EyeMatchy',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Zaloguj się, aby dopasować idealne rzęsy',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 48),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Hasło',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.key_off : Icons.key,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Nie pamiętasz hasła?',
                            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text('Zaloguj się', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('lub', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                        label: const Text('Zaloguj przez Google', style: TextStyle(fontSize: 16, color: Colors.black87)),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Nie masz konta? '),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              'Zarejestruj się',
                              style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), // Dodatkowy margines na dole klawiatury
                    ],
                  ),
                ),
              ),
            ),

            // 🚀 WARSTWA 2 (Na wierzchu): Pływający komunikat odporny na klawiaturę
            if (_bannerMessage != null)
              Positioned(
                top: 16,
                left: 24,
                right: 24,
                child: Material(
                  elevation: 6, // Dodaje ładny cień
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isBannerError ? Colors.redAccent : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(_isBannerError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _bannerMessage!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _bannerMessage = null),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}