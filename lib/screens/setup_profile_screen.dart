import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Niezbędne do formatowania tekstu
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedRole = 'client';
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- FUNKCJA FORMATUJĄCA (Zawsze pierwsza litera duża, reszta małe) ---
  String _capitalize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  // --- LOGIKA ZAPISU DO BAZY ---
  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final phone = _phoneController.text;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': _capitalize(firstName),
          'lastName': _capitalize(lastName),
          'phone': phone.trim(),
          'email': user.email?.toLowerCase().trim(),
          'roles': _selectedRole == 'salon' ? ['client', 'salon'] : ['client'],
          'currentView': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'profileSetupComplete': true,
        });
      }
    } catch (e) {
      _showTopSnackBar('Błąd podczas zapisywania danych.');
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
      appBar: AppBar(
        title: const Text('Uzupełnij swój profil'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Witaj w EyeMatch!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Podaj swoje podstawowe dane, aby móc korzystać z aplikacji.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // 🚀 POLE IMIĘ (Obowiązkowe, bez cyfr)
                TextFormField(
                  controller: _firstNameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')), // BLOKUJE WPISYWANIE CYFR
                  ],
                  decoration: InputDecoration(
                    labelText: 'Imię',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Wpisz imię' : null,
                ),
                const SizedBox(height: 16),

                // 🚀 POLE NAZWISKO (Obowiązkowe, bez cyfr)
                TextFormField(
                  controller: _lastNameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[0-9]')), // BLOKUJE WPISYWANIE CYFR
                  ],
                  decoration: InputDecoration(
                    labelText: 'Nazwisko',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Wpisz nazwisko' : null,
                ),
                const SizedBox(height: 16),

                // 🚀 POLE TELEFON (Obowiązkowe, tylko cyfry, min 9 znaków)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // BLOKUJE WPISYWANIE LITER I ZNAKÓW
                  ],
                  decoration: InputDecoration(
                    labelText: 'Numer telefonu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Wpisz numer telefonu';
                    }
                    if (val.trim().length < 9) {
                      return 'Numer musi składać się z przynajmniej 9 cyfr';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // WYBÓR ROLI
                const Text(
                  'Kim jesteś?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Klientką')),
                        selected: _selectedRole == 'client',
                        selectedColor: Colors.deepPurple.withOpacity(0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = 'client');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Stylistką')),
                        selected: _selectedRole == 'salon',
                        selectedColor: Colors.deepPurple.withOpacity(0.2),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = 'salon');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // PRZYCISK ZAPISZ
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfileData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Zapisz i przejdź dalej', style: TextStyle(fontSize: 16)),
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