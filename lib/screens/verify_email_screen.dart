import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // Wysyłamy e-mail weryfikacyjny przy pierwszym otwarciu ekranu
    sendVerificationEmail();

    // Uruchamiamy timer, który co 3 sekundy odświeża stan użytkownika
    timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => checkEmailVerified(),
    );
  }

  @override
  void dispose() {
    timer?.cancel(); // Zawsze sprzątamy timer, żeby nie wyciekała pamięć!
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    // reload() odświeża dane użytkownika prosto z serwerów Firebase.
    // Jeśli e-mail został potwierdzony, główny Stream (userChanges) w pliku main.dart
    // automatycznie to wyłapie i zdejmie ten ekran!
    await FirebaseAuth.instance.currentUser?.reload();
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      setState(() => canResendEmail = false);

      // Blokujemy przycisk na 30 sekund (Firebase jest bardzo czuły na spam)
      await Future.delayed(const Duration(seconds: 30));

      if (mounted) {
        setState(() => canResendEmail = true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Wystąpił błąd: ${e.message}';

        // 🚀 Tłumaczymy chamski błąd Firebase na ładny komunikat dla użytkownika
        if (e.code == 'too-many-requests') {
          errorMessage = 'Zbyt wiele prób. Ze względów bezpieczeństwa system tymczasowo zablokował wysyłanie. Spróbuj ponownie za kilkanaście minut.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd wysyłania e-maila: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // 🚀 Pobieramy usera

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weryfikacja konta'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
                'Potwierdź swój adres e-mail',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center
            ),
            const SizedBox(height: 16),
            // 🚀 Wyświetlamy DOKŁADNY ADRES, na jaki poszedł mail
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                children: [
                  const TextSpan(text: 'Wysłaliśmy link weryfikacyjny na adres:\n'),
                  TextSpan(
                      text: '${user?.email}\n\n',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)
                  ),
                  const TextSpan(text: 'Kliknij w niego, aby aktywować konto. Aplikacja automatycznie przepuści Cię dalej po zatwierdzeniu!'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: canResendEmail ? sendVerificationEmail : null,
              icon: const Icon(Icons.email),
              label: const Text('Wyślij e-mail ponownie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Anuluj i wyloguj się', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}