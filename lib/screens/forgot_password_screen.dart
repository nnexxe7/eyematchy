import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj adres e-mail!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link do resetu hasła został wysłany! Sprawdź skrzynkę (i folder SPAM).'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context); // Wróć do ekranu logowania po sukcesie
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Wystąpił błąd: ${e.message}';

        // Tłumaczymy najczęstsze błędy Firebase na polski
        if (e.code == 'user-not-found') {
          errorMessage = 'Nie znaleziono konta powiązanego z tym adresem e-mail.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Niepoprawny format adresu e-mail.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset hasła'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.deepPurple,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.lock_reset_outlined, size: 100, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'Nie pamiętasz hasła?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Wpisz adres e-mail powiązany z Twoim kontem. Wyślemy Ci link, dzięki któremu w bezpieczny sposób utworzysz nowe hasło.',
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Twój adres e-mail',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Wyślij link do resetu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}