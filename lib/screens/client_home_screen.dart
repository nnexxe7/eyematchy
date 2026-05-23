import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ClientHomeScreen({super.key, required this.userData});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String? _selectedCityId; // Przechowa identyfikator wybranego miasta (np. 'warszawa')

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Użytkownik niezalogowany.')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> liveUserData = widget.userData;

        if (snapshot.hasData && snapshot.data!.exists) {
          liveUserData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final String firstName = liveUserData['firstName'] ?? 'Klient';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Znajdź Salon'),
            backgroundColor: Colors.pinkAccent,
            foregroundColor: Colors.white,
          ),
          drawer: AppDrawer(userData: liveUserData, currentRole: 'client'),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Witaj, $firstName! 👋',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // --- DROPDOWN WYBORU MIASTA NA SAMEJ GÓRZE ---
                const Text(
                  'Najpierw wybierz swoje miasto:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('cities').orderBy('name').snapshots(),
                  builder: (context, citiesSnapshot) {
                    if (citiesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: LinearProgressIndicator(color: Colors.pinkAccent));
                    }

                    List<DropdownMenuItem<String>> cityItems = [];
                    if (citiesSnapshot.hasData) {
                      for (var doc in citiesSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        cityItems.add(
                          DropdownMenuItem(
                            value: doc.id, // ID dokumentu np. 'warszawa'
                            child: Text(data['name'] ?? doc.id), // Ładna nazwa np. 'Warszawa'
                          ),
                        );
                      }
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedCityId,
                      items: cityItems,
                      onChanged: (value) {
                        setState(() {
                          _selectedCityId = value; // Aktualizacja wybranego miasta i przebudowa widoku
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Wybierz miasto z listy...',
                        prefixIcon: const Icon(Icons.location_city, color: Colors.pinkAccent),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                        ),
                      ),
                    );
                  },
                ),
                // ---------------------------------------------

                const SizedBox(height: 24),
                const Text(
                  'Dostępne salony:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                Expanded(
                  // Logika warunkowa: Jeśli miasto nie jest wybrane, nie odpytujemy bazy o salony
                  child: _selectedCityId == null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.maps_home_work_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Wskaż miasto powyżej,\naby wyświetlić dostępne salony.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
                      ],
                    ),
                  )
                      : StreamBuilder<QuerySnapshot>(
                    // Kluczowy moment: Filtrowanie salonów po wybranym cityId w Firestore
                    stream: FirebaseFirestore.instance
                        .collection('salons')
                        .where('cityId', isEqualTo: _selectedCityId)
                        .snapshots(),
                    builder: (context, salonsSnapshot) {
                      if (salonsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                      }

                      if (!salonsSnapshot.hasData || salonsSnapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'Brak zarejestrowanych salonów w tym mieście.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 15),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: salonsSnapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = salonsSnapshot.data!.docs[index];
                          final salon = doc.data() as Map<String, dynamic>;
                          final String salonId = doc.id;

                          // Bezpieczne wyciąganie nazwy salonu z bazy danych
                          final String name = salon['salonName'] ?? salon['name'] ?? 'Nieznany Salon';
                          final String address = salon['address'] ?? 'Brak adresu';
                          final List<dynamic> employees = salon['employees'] ?? [];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.pink.withOpacity(0.1),
                                        child: const Icon(Icons.content_cut, color: Colors.pinkAccent),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    address,
                                                    style: const TextStyle(color: Colors.grey),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Zespół: ${employees.length} os.',
                                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          _startBookingWizard(salonId, name);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.pinkAccent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Zarezerwuj'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startBookingWizard(String salonId, String salonName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rozpoczynam rezerwację w: $salonName')),
    );
  }
}