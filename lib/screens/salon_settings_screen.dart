import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalonSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SalonSettingsScreen({super.key, required this.userData});

  @override
  State<SalonSettingsScreen> createState() => _SalonSettingsScreenState();
}

class _SalonSettingsScreenState extends State<SalonSettingsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _streetController;
  late TextEditingController _numberController;

  bool _isLoading = false;
  bool _isInitialDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController();
    _cityController = TextEditingController();
    _streetController = TextEditingController();
    _numberController = TextEditingController();
    _loadCurrentSalonData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSalonData() async {
    final salonId = widget.userData['salonId'];
    if (salonId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('salons').doc(salonId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final addressDetails = data['addressDetails'] as Map<String, dynamic>? ?? {};

        setState(() {
          _nameController.text = data['salonName'] ?? '';
          _cityController.text = addressDetails['city'] ?? '';
          _streetController.text = addressDetails['street'] ?? '';
          _numberController.text = addressDetails['number'] ?? '';
          _isInitialDataLoaded = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania danych: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _updateSalonData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw 'Nie znaleziono profilu użytkownika w bazie.';
      }

      final currentFullUserData = userDoc.data() as Map<String, dynamic>;
      final String? salonId = currentFullUserData['salonId'];

      if (salonId == null || salonId.isEmpty) {
        throw 'Twój profil nie jest przypisany do żadnego salonu (brak salonId).';
      }

      final name = _nameController.text.trim();
      final city = _cityController.text.trim();
      final street = _streetController.text.trim();
      final number = _numberController.text.trim();
      final fullAddress = "ul. $street $number, $city";

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('salonId', isEqualTo: salonId)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
      batch.update(salonRef, {
        'salonName': name,
        'address': fullAddress,
        'addressDetails': {
          'city': city,
          'street': street,
          'number': number,
        }
      });

      for (var doc in usersSnapshot.docs) {
        batch.update(doc.reference, {'salonName': name});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dane salonu oraz nazwa u wszystkich pracowników zostały zaktualizowane!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fireEmployee(String employeeId, String employeeName) async {
    final salonId = widget.userData['salonId'];
    if (salonId == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zwolnij pracownika'),
        content: Text('Czy na pewno chcesz usunąć stylistkę $employeeName z zespołu? Straci ona całkowicie uprawnienia biznesowe w aplikacji.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zwolnij', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      final userRef = FirebaseFirestore.instance.collection('users').doc(employeeId);
      batch.update(userRef, {
        'salonId': FieldValue.delete(),
        'salonName': FieldValue.delete(),
        'salonRole': FieldValue.delete(),
        'roles': ['client'],
        'currentView': 'client',
      });

      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
      batch.update(salonRef, {
        'employees': FieldValue.arrayRemove([employeeId])
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pracownik $employeeName został usunięty z zespołu.'), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas zwalniania: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.userData['salonRole'] == 'owner';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Brak dostępu'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.redAccent),
                SizedBox(height: 16),
                Text('Brak uprawnień', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Tylko właściciel salonu ma dostęp do ustawień zarządzania placówką i zespołem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia Salonu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: "Dane salonu"),
            Tab(icon: Icon(Icons.person_remove_outlined), text: "Zwolnij ludzi"),
          ],
        ),
      ),
      body: !_isInitialDataLoaded
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Wizytówka salonu", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text("Tutaj zmienisz nazwę oraz adres swojej placówki.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Nazwa Salonu', prefixIcon: const Icon(Icons.storefront, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Podaj nazwę' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(labelText: 'Miasto', prefixIcon: const Icon(Icons.location_city, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Podaj miasto' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _streetController,
                            decoration: InputDecoration(labelText: 'Ulica', prefixIcon: const Icon(Icons.map_outlined, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Podaj ulicę' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _numberController,
                            decoration: InputDecoration(labelText: 'Nr lokalu', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Podaj nr' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateSalonData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Zapisz zmiany', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Zarządzanie uprawnieniami", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Kliknij przycisk kosza obok pracownika, aby bezpowrotnie usunąć go ze struktur Twojego salonu.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('salonId', isEqualTo: widget.userData['salonId'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Brak pracowników w salonie."));

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final employee = doc.data() as Map<String, dynamic>;

                          final String fName = employee['firstName'] ?? '';
                          final String lName = employee['lastName'] ?? '';
                          final String fullName = "$fName $lName".trim();
                          final String email = employee['email'] ?? '';
                          final String role = employee['salonRole'] ?? 'employee';
                          final String empId = doc.id;

                          final bool isMeOwner = role == 'owner';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isMeOwner ? Colors.amber[100] : Colors.red[50],
                                child: Icon(isMeOwner ? Icons.star : Icons.person, color: isMeOwner ? Colors.amber[800] : Colors.redAccent),
                              ),
                              title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(isMeOwner ? "Właściciel (Ty)" : email, style: TextStyle(color: isMeOwner ? Colors.amber[900] : Colors.grey)),
                              trailing: isMeOwner
                                  ? const SizedBox()
                                  : IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                onPressed: () => _fireEmployee(empId, fullName),
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
        ],
      ),
    );
  }
}