import 'package:flutter/material.dart';
import '../main.dart'; // Importujemy AppDrawer z pliku main.dart

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const HomeScreen({super.key, required final this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EyeMatchy'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      drawer: AppDrawer(userData: userData, currentRole: 'client'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_border_rounded, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              Text(
                'Witaj, ${userData['firstName'] ?? 'Klientko'}!',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Przeglądaj salony i umawiaj się na rzęsy. Otwórz menu boczne, aby zarządzać profilem.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}