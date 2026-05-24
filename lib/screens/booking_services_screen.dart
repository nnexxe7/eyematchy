import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingServicesScreen extends StatelessWidget {
  final String salonId;
  final String salonName;

  const BookingServicesScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wybierz usługę - $salonName'),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Pobieramy usługi tylko z tego konkretnego salonu
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('salonId', isEqualTo: salonId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Ten salon nie dodał jeszcze żadnych usług do swojego cennika.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final service = doc.data() as Map<String, dynamic>;

              final String name = service['name'] ?? 'Usługa bez nazwy';
              final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
              final int duration = service['duration'] ?? 30;
              final String employeeName = service['employeeName'] ?? 'Salon';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Czas: $duration min • Wykonuje: $employeeName',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${price.toStringAsFixed(2)} zł',
                        style: const TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    // Tutaj w kolejnym kroku przejdziemy do wyboru daty i pracownika!
                    _goToNextStep(context, doc.id, service);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _goToNextStep(BuildContext context, String serviceId, Map<String, dynamic> serviceData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wybrano: ${serviceData['name']}. Czas na wybór daty!')),
    );
    // Tutaj zaraz podepniemy ekran wyboru daty i godziny
  }
}