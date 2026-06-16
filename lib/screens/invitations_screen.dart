import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const InvitationsScreen({super.key, required this.userData});

  Future<void> _acceptInvitation(BuildContext context, String inviteId, String salonId, String salonName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🚀 NAPRAWA: Zapisujemy nawigator i messengera do zmiennych ZANIM kontekst zostanie zniszczony!
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Pokazanie paska ładowania
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Aktualizacja profilu użytkownika (dodanie roli salonu i przełączenie widoku)
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      List<String> currentRoles = List<String>.from(userData['roles'] ?? []);
      if (!currentRoles.contains('salon')) {
        currentRoles.add('salon');
      }

      batch.update(userRef, {
        'salonId': salonId,
        'salonName': salonName,
        'salonRole': 'employee',
        'roles': currentRoles,
        'currentView': 'salon',
      });

      // 2. Dodanie pracownika do listy w salonie
      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
      batch.update(salonRef, {
        'employees': FieldValue.arrayUnion([user.uid])
      });

      // 3. Usunięcie zaproszenia
      final inviteRef = FirebaseFirestore.instance.collection('invitations').doc(inviteId);
      batch.delete(inviteRef);

      await batch.commit();

      // Wykorzystujemy bezpieczne zmienne zapisane na górze do usunięcia loadera i powrotu!
      navigator.pop(); // Zdejmuje kółko ładowania (Dialog)
      navigator.pop(); // Wraca do głównego ekranu (który w międzyczasie sam zmieni się na kalendarz)

      messenger.showSnackBar(
        const SnackBar(content: Text('Gratulacje! Dołączyłaś do zespołu.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      navigator.pop(); // Nawet przy błędzie zdejmujemy loader
      messenger.showSnackBar(
        SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _declineInvitation(BuildContext context, String inviteId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odrzuć zaproszenie'),
        content: const Text('Czy na pewno chcesz odrzucić to zaproszenie do pracy?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odrzuć', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    // 🚀 Dla odrzucenia robimy to samo - łapiemy messengera
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('invitations').doc(inviteId).delete();
      messenger.showSnackBar(
        const SnackBar(content: Text('Zaproszenie zostało odrzucone.'), backgroundColor: Colors.black87),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String myEmail = userData['email'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zaproszenia do zespołu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invitations')
            .where('email', isEqualTo: myEmail)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak nowych zaproszeń.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final invites = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final inviteDoc = invites[index];
              final inviteData = inviteDoc.data() as Map<String, dynamic>;
              final String salonId = inviteData['salonId'] ?? '';
              final String inviteId = inviteDoc.id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('salons').doc(salonId).get(),
                builder: (context, salonSnapshot) {
                  if (salonSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
                      ),
                    );
                  }

                  String displaySalonName = inviteData['salonName'] ?? 'Nieznany salon';
                  String displayAddress = 'Brak danych adresowych';

                  if (salonSnapshot.hasData && salonSnapshot.data!.exists) {
                    final salonData = salonSnapshot.data!.data() as Map<String, dynamic>;
                    displaySalonName = salonData['salonName'] ?? displaySalonName;
                    displayAddress = salonData['address'] ?? displayAddress;
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront, color: Colors.deepPurple, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Zaproszenie do pracy', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      displaySalonName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 20, color: Colors.pinkAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  displayAddress,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _declineInvitation(context, inviteId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Odrzuć'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _acceptInvitation(context, inviteId, salonId, displaySalonName),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Akceptuj'),
                                ),
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
          );
        },
      ),
    );
  }
}