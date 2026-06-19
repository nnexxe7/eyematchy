import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientAppointmentsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const ClientAppointmentsScreen({super.key, required this.userData});

  // --- LOGIKA POMOCNICZA: Parsowanie daty i czasu do obiektu DateTime ---
  DateTime _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('-');
      final timeParts = time.split(':');
      return DateTime(
        int.parse(dateParts[0]), // Rok
        int.parse(dateParts[1]), // Miesiąc
        int.parse(dateParts[2]), // Dzień
        int.parse(timeParts[0]), // Godzina
        int.parse(timeParts[1]), // Minuta
      );
    } catch (e) {
      return DateTime(2000); // Awaryjna data w przypadku błędu formatu
    }
  }

  // --- KOMPONENT WIDOKU: Budowa listy dla konkretnej zakładki ---
  Widget _buildAppointmentsList(List<QueryDocumentSnapshot> docs, String emptyMessage) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final appointment = doc.data() as Map<String, dynamic>;

        final String salonName = appointment['salonName'] ?? 'Nieznany Salon';
        final String serviceName = appointment['serviceName'] ?? 'Usługa';
        final String employeeId = appointment['employeeId'] ?? ''; // ID pracownika do pobrania nazwiska
        final String fallbackEmployeeName = appointment['employeeName'] ?? 'Stylistka';
        final String date = appointment['date'] ?? '';
        final String time = appointment['time'] ?? '';
        final double price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
        final int duration = appointment['duration'] ?? 30;

        // Proste formatowanie daty (RRRR-MM-DD -> DD.MM.RRRR)
        String displayDate = date;
        try {
          final parts = date.split('-');
          if (parts.length == 3) {
            displayDate = "${parts[2]}.${parts[1]}.${parts[0]}";
          }
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        salonName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${price.toStringAsFixed(2)} zł',
                        style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  serviceName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.deepPurple),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('$time ($duration min)', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(width: 20),
                    Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(displayDate, style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),

                // 🚀 Pobieranie nazwiska pracownika z kolekcji 'users'
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(employeeId).get(),
                  builder: (context, empSnapshot) {
                    String finalEmployeeName = fallbackEmployeeName;

                    if (empSnapshot.hasData && empSnapshot.data!.exists) {
                      final empData = empSnapshot.data!.data() as Map<String, dynamic>;
                      final String firstName = empData['firstName'] ?? fallbackEmployeeName;
                      final String lastName = empData['lastName'] ?? '';

                      // Łączymy imię z nazwiskiem (jeśli nazwisko jest w bazie)
                      finalEmployeeName = lastName.isNotEmpty ? "$firstName $lastName" : firstName;
                    }

                    return Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text('Stylistka: $finalEmployeeName', style: TextStyle(color: Colors.grey[700])),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Użytkownik niezalogowany.')));

    // Opakowujemy Scaffold w DefaultTabController, aby obsłużyć 2 zakładki
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moje Wizyty'),
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: "Nadchodzące"),
              Tab(text: "Historia"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('clientId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Błąd pobierania danych:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              );
            }

            final List<QueryDocumentSnapshot> docs = snapshot.data?.docs.toList() ?? [];

            // 1. Sortowanie chronologiczne od najstarszych do najnowszych (podstawa)
            docs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;

              int dateComparison = (dataA['date'] ?? '').compareTo(dataB['date'] ?? '');
              if (dateComparison == 0) {
                return (dataA['time'] ?? '').compareTo(dataB['time'] ?? '');
              }
              return dateComparison;
            });

            // 2. Rozdzielenie na wizyty nadchodzące i przeszłe
            final DateTime now = DateTime.now();
            List<QueryDocumentSnapshot> upcomingAppointments = [];
            List<QueryDocumentSnapshot> pastAppointments = [];

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final DateTime appointmentTime = _parseDateTime(data['date'] ?? '', data['time'] ?? '');

              if (appointmentTime.isBefore(now)) {
                pastAppointments.add(doc);
              } else {
                upcomingAppointments.add(doc);
              }
            }

            // 3. Odwracamy historię, żeby najnowsze zakończone wizyty były na samej górze!
            pastAppointments = pastAppointments.reversed.toList();

            // Przekazanie gotowych list do widoku zakładek
            return TabBarView(
              children: [
                _buildAppointmentsList(upcomingAppointments, 'Nie masz jeszcze zaplanowanych wizyt.'),
                _buildAppointmentsList(pastAppointments, 'Brak historii wizyt.'),
              ],
            );
          },
        ),
      ),
    );
  }
}