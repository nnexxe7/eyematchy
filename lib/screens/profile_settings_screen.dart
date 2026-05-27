import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Upewnij się, że masz ten pakiet w pubspec.yaml

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ProfileSettingsScreen({super.key, required this.userData});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.userData['firstName'] ?? '');
    _lastNameController = TextEditingController(text: widget.userData['lastName'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phoneNumber'] ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil zaktualizowany pomyślnie!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- DYNAMICZNE OKNO POTWIERDZENIA ---
  Future<void> _showDeleteConfirmationDialog() async {
    _passwordController.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String providerId = user.providerData.isNotEmpty ? user.providerData.first.providerId : '';
    final bool isGoogleUser = providerId == 'google.com';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Usuń konto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Czy na pewno chcesz bezpowrotnie usunąć swoje konto? Wszystkie Twoje dane zostaną skasowane.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),

            if (isGoogleUser)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.g_mobiledata, color: Colors.blue, size: 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jesteś zalogowany przez Google. Klikając przycisk poniżej, aplikacja poprosi Cię o ponowne zalogowanie w celu weryfikacji tożsamości.',
                        style: TextStyle(fontSize: 13, color: Colors.blue[900], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const Text(
                'Wpisz swoje aktualne hasło, aby potwierdzić operację:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Hasło',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (!isGoogleUser && _passwordController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Musisz podać hasło!'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Usuń konto', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _executeAccountDeletion(isGoogleUser);
    }
  }

  // --- WYKONANIE USUWANIA Z REAUTENTYKACJĄ GOOGLE/EMAIL ---
  Future<void> _executeAccountDeletion(bool isGoogleUser) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Reautentykacja na podstawie dostawcy logowania
      if (!isGoogleUser) {
        // Konta tradycyjne (Email + Hasło)
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        // Konta społecznościowe (Google Sign In)
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signInSilently() ?? await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(code: 'reauthentication-failed', message: 'Anulowano logowanie Google.');
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // 2. Czyszczenie bazy Firestore (Salon, Pracownicy, Zaproszenia)
      final String? salonId = widget.userData['salonId'];
      final String? salonRole = widget.userData['salonRole'];

      WriteBatch batch = FirebaseFirestore.instance.batch();

      if (salonRole == 'owner' && salonId != null && salonId.isNotEmpty) {
        final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
        batch.delete(salonRef);

        final employeesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('salonId', isEqualTo: salonId)
            .get();

        for (var doc in employeesSnapshot.docs) {
          if (doc.id == user.uid) continue;

          batch.update(doc.reference, {
            'salonId': FieldValue.delete(),
            'salonName': FieldValue.delete(),
            'salonRole': FieldValue.delete(),
            'employeeRole': FieldValue.delete(),
            'roles': ['client'],
            'currentView': 'client',
          });
        }

        final invitationsSnapshot = await FirebaseFirestore.instance
            .collection('invitations')
            .where('salonId', isEqualTo: salonId)
            .get();

        for (var doc in invitationsSnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      // Usuwamy dokument aktualnego użytkownika z Firestore
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.delete(userRef);

      // Zapisujemy zmiany w Firestore
      await batch.commit();

      // 3. Bezpieczne usunięcie użytkownika z systemu Auth
      await user.delete();

      // Wylogowanie z Google Sign In, aby nie zapamiętywało starej sesji
      if (isGoogleUser) {
        await GoogleSignIn().signOut();
      }

// --- ZNAJDŹ TEN FRAGMENT NA SAMYM DOLE METODY _executeAccountDeletion:
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Konto usunięte'),
            content: const Text('Twoje konto oraz powiązane dane zostały pomyślnie wykasowane z systemu.'),
            actions: [
              TextButton(
                onPressed: () {
                  // POPRAWKA DLA STRUKTURY Z AUTHGATE:
                  Navigator.pop(context); // 1. Zamyka okienko AlertDialog
                  Navigator.pop(context); // 2. Zamyka ProfileSettingsScreen i odsłania czysty LoginScreen z AuthGate!
                },
                child: const Text('Żegnaj', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Wystąpił błąd podczas autoryzacji.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Podane hasło jest niepoprawne. Spróbuj ponownie.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Nie znaleziono takiego użytkownika.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Sesja wygasła. Zaloguj się ponownie przed usunięciem konta.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas usuwania konta: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String email = widget.userData['email'] ?? '';
    final String initialLetter = _firstNameController.text.isNotEmpty ? _firstNameController.text[0].toUpperCase() : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia Profilu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Stack(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                    child: Text(
                      initialLetter,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepPurple,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Funkcja wyboru zdjęcia z galerii zostanie dodana w kolejnym kroku!')),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                email,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Imię',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Wprowadź imię' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Nazwisko',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Wprowadź nazwisko' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numer telefonu',
                  prefixIcon: const Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Zapisz zmiany', style: TextStyle(fontSize: 18)),
                ),
              ),

              const SizedBox(height: 24),

              TextButton.icon(
                onPressed: _showDeleteConfirmationDialog,
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text(
                  'Usuń konto na stałe',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}