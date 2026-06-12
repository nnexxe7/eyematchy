import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientAppointmentsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const ClientAppointmentsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Użytkownik niezalogowany.')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Wizyty'),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('clientId', isEqualTo: user.uid)
        // 🚀 USUNIĘTO .orderBy() - omijamy błąd brakującego indeksu w Firebase
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
          }

          // 🚀 DODANO OBSŁUGĘ BŁĘDÓW - jeśli Firebase coś zablokuje, pokaże się komunikat na ekranie
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Wystąpił błąd pobierania danych:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nie masz jeszcze zaplanowanych wizyt.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // 🚀 DODANO LOKALNE SORTOWANIE W DARCIE (najpierw po dacie, potem po godzinie)
          final docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final dateA = dataA['date'] ?? '';
            final dateB = dataB['date'] ?? '';

            int dateComparison = dateA.compareTo(dateB);

            // Jeśli wizyty są tego samego dnia, posortuj je po godzinie
            if (dateComparison == 0) {
              final timeA = dataA['time'] ?? '';
              final timeB = dataB['time'] ?? '';
              return timeA.compareTo(timeB);
            }
            return dateComparison;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final appointment = doc.data() as Map<String, dynamic>;

              final String salonName = appointment['salonName'] ?? 'Nieznany Salon';
              final String serviceName = appointment['serviceName'] ?? 'Usługa';
              final String employeeName = appointment['employeeName'] ?? 'Stylistka';
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
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('Stylistka: $employeeName', style: TextStyle(color: Colors.grey[700])),
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
    );
  }
}