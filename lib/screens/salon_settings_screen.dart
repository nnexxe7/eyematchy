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
  late TextEditingController _streetController;
  late TextEditingController _numberController;
  String? _selectedCityId;

  bool _isLoading = false;
  bool _isInitialDataLoaded = false;

  Map<String, dynamic> _openingHours = {
    '1_pon': {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
    '2_wt':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
    '3_sr':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
    '4_czw': {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
    '5_pt':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
    '6_sob': {'1_closed': true,  '2_open': '09:00', '3_close': '14:00'},
    '7_nd':  {'1_closed': true,  '2_open': '08:00', '3_close': '16:00'},
  };

  final Map<String, String> _dayLabels = {
    '1_pon': 'Poniedziałek',
    '2_wt': 'Wtorek',
    '3_sr': 'Środa',
    '4_czw': 'Czwartek',
    '5_pt': 'Piątek',
    '6_sob': 'Sobota',
    '7_nd': 'Niedziela',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _nameController = TextEditingController();
    _streetController = TextEditingController();
    _numberController = TextEditingController();
    _loadCurrentSalonData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
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
          _streetController.text = addressDetails['street'] ?? '';
          _numberController.text = addressDetails['number'] ?? '';
          _selectedCityId = data['cityId'] ?? (addressDetails['city'] as String?)?.toLowerCase().replaceAll(' ', '-');

          if (data['openingHours'] != null) {
            _openingHours = Map<String, dynamic>.from(data['openingHours']);
          }

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
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proszę wybrać miasto z listy!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final currentFullUserData = userDoc.data() as Map<String, dynamic>;
      final String? salonId = currentFullUserData['salonId'];

      if (salonId == null || salonId.isEmpty) throw 'Brak przypisanego salonId.';

      final cityDoc = await FirebaseFirestore.instance.collection('cities').doc(_selectedCityId).get();
      final String cityName = (cityDoc.data() as Map<String, dynamic>?)?['name'] ?? _selectedCityId!;

      final name = _nameController.text.trim();
      final street = _streetController.text.trim();
      final number = _numberController.text.trim();
      final fullAddress = "ul. $street $number, $cityName";

      final usersSnapshot = await FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: salonId).get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);

      batch.update(salonRef, {
        'salonName': name,
        'address': fullAddress,
        'cityId': _selectedCityId,
        'addressDetails': {
          'city': cityName,
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
          const SnackBar(content: Text('Zaktualizowano dane wizytówki!'), backgroundColor: Colors.green),
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

  Future<void> _saveOpeningHours() async {
    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final String? salonId = (userDoc.data() as Map<String, dynamic>?)?['salonId'];

      if (salonId == null || salonId.isEmpty) throw 'Brak przypisanego salonId.';

      await FirebaseFirestore.instance.collection('salons').doc(salonId).update({
        'openingHours': _openingHours,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Godziny pracy zostały pomyślnie zapisane!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu godzin: $e'), backgroundColor: Colors.redAccent),
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
        title: const Text('Usuń z zespołu'),
        content: Text('Czy na pewno chcesz usunąć użytkownika $employeeName z zespołu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usuń', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(employeeId).get();
      String employeeEmail = '';
      if (userDoc.exists && userDoc.data() != null) {
        employeeEmail = userDoc.data()!['email'] ?? '';
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(employeeId);
      batch.update(userRef, {
        'salonId': FieldValue.delete(),
        'salonName': FieldValue.delete(),
        'salonRole': FieldValue.delete(),
        'employeeRole': FieldValue.delete(),
        'roles': ['client'],
        'currentView': 'client',
      });

      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
      batch.update(salonRef, {
        'employees': FieldValue.arrayRemove([employeeId])
      });

      if (employeeEmail.isNotEmpty) {
        final inviteSnapshotByEmail = await FirebaseFirestore.instance.collection('invitations').where('salonId', isEqualTo: salonId).where('email', isEqualTo: employeeEmail).get();
        for (var doc in inviteSnapshotByEmail.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Użytkownik $employeeName został usunięty.'), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas usuwania: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // 🚀 NOWA METODA: Głębokie usuwanie salonu i powiązanych struktur w Firebase
  Future<void> _deleteSalonPermanently() async {
    final salonId = widget.userData['salonId'];
    final String targetSalonName = _nameController.text.trim();
    if (salonId == null || salonId.isEmpty) return;

    final TextEditingController confirmController = TextEditingController();
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    // 1. Wyświetlenie okna potwierdzenia z przepisywaniem nazwy
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('USUWANIE SALONU'),
          ],
        ),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ta operacja jest nieodwracalna. Spowoduje usunięcie cennika, harmonogramu oraz odpięcie wszystkich pracowników.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Aby potwierdzić, wpisz poniżej nazwę swojego salonu: '),
                    TextSpan(text: targetSalonName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                decoration: InputDecoration(
                  hintText: 'Wpisz nazwę salonu',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim() != targetSalonName) {
                    return 'Wpisana nazwa jest niepoprawna';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
          ElevatedButton(
            onPressed: () {
              if (dialogFormKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Usuń bezpowrotnie'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    // Pobranie instancji nawigatora i messengera przed wyczyszczeniem kontekstu
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // A. Pobranie wszystkich powiązanych usług (services)
      final servicesQuery = await FirebaseFirestore.instance.collection('services').where('salonId', isEqualTo: salonId).get();
      for (var doc in servicesQuery.docs) {
        batch.delete(doc.reference);
      }

      // B. Pobranie wszystkich powiązanych zaproszeń (invitations)
      final invitesQuery = await FirebaseFirestore.instance.collection('invitations').where('salonId', isEqualTo: salonId).get();
      for (var doc in invitesQuery.docs) {
        batch.delete(doc.reference);
      }

      // C. Pobranie wszystkich pracowników należących do salonu i usunięcie im ról
      final usersQuery = await FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: salonId).get();
      for (var doc in usersQuery.docs) {
        final uData = doc.data();
        List<String> userRoles = List<String>.from(uData['roles'] ?? ['client']);
        userRoles.remove('salon'); // Usunięcie uprawnienia wejścia do panelu salonu

        batch.update(doc.reference, {
          'salonId': FieldValue.delete(),
          'salonName': FieldValue.delete(),
          'salonRole': FieldValue.delete(),
          'employeeRole': FieldValue.delete(),
          'roles': userRoles.isEmpty ? ['client'] : userRoles,
          'currentView': 'client', // Cofnięcie do domyślnego widoku klientki
        });
      }

      // D. Usunięcie samego głównego dokumentu salonu
      final salonRef = FirebaseFirestore.instance.collection('salons').doc(salonId);
      batch.delete(salonRef);

      // E. Wysłanie paczki danych do chmury Firebase
      await batch.commit();

      navigator.pop(); // Zamknięcie okna ładowania
      navigator.pop(); // Zamknięcie ustawień i powrót do odświeżonego AuthGate

      messenger.showSnackBar(
        const SnackBar(content: Text('Salon oraz wszystkie powiązane dane zostały pomyślnie usunięte.'), backgroundColor: Colors.black87),
      );

    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Błąd podczas usuwania salonu: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      confirmController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.userData['salonRole'] == 'owner';

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brak dostępu'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
        body: const Center(child: Text('Tylko właściciel salonu ma dostęp do ustawień.')),
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
            Tab(icon: Icon(Icons.storefront), text: "Dane"),
            Tab(icon: Icon(Icons.access_time), text: "Godziny pracy"),
            Tab(icon: Icon(Icons.person_remove_outlined), text: "Zespół"),
          ],
        ),
      ),
      body: !_isInitialDataLoaded
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: DANE WIZYTÓWKI
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Wizytówka salonu", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Nazwa Salonu', prefixIcon: const Icon(Icons.storefront, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Podaj nazwę' : null,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('cities').orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator(color: Colors.deepPurple);
                        List<DropdownMenuItem<String>> cityItems = [];
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          cityItems.add(DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id)));
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedCityId,
                          items: cityItems,
                          onChanged: (value) => setState(() => _selectedCityId = value),
                          decoration: InputDecoration(labelText: 'Miejscowość', prefixIcon: const Icon(Icons.location_city, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          validator: (val) => val == null ? 'Wybierz miasto' : null,
                        );
                      },
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
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Zapisz wizytówkę', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // TAB 2: PANEL USTAWIEŃ GODZIN PRACY
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Godziny otwarcia", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Zdefiniuj ramy czasowe działania Twojego salonu dla każdego dnia tygodnia.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: (() {
                      final sortedKeys = _openingHours.keys.toList()..sort();
                      return sortedKeys.map((key) {
                        return BusinessDayRow(
                          dayName: _dayLabels[key] ?? key,
                          dayData: _openingHours[key],
                          onChanged: (newData) {
                            setState(() {
                              _openingHours[key] = newData;
                            });
                          },
                        );
                      }).toList();
                    })(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveOpeningHours,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Zapisz godziny pracy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // TAB 3: ZESPÓŁ + 🔴 SEKCCJA USUWANIA SALONU NA SAMYM DOLE
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Zarządzanie uprawnieniami", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: widget.userData['salonId']).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                      List<QueryDocumentSnapshot> employeesDocs = List.from(snapshot.data!.docs);

                      employeesDocs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;

                        bool isOwnerA = dataA['salonRole'] == 'owner';
                        bool isOwnerB = dataB['salonRole'] == 'owner';

                        if (isOwnerA && !isOwnerB) return -1;
                        if (!isOwnerA && isOwnerB) return 1;

                        String nameA = (dataA['firstName'] ?? '').toString().toLowerCase();
                        String nameB = (dataB['firstName'] ?? '').toString().toLowerCase();

                        int compareNames = nameA.compareTo(nameB);
                        if (compareNames != 0) return compareNames;

                        String lastNameA = (dataA['lastName'] ?? '').toString().toLowerCase();
                        String lastNameB = (dataB['lastName'] ?? '').toString().toLowerCase();
                        return lastNameA.compareTo(lastNameB);
                      });

                      return ListView.builder(
                        itemCount: employeesDocs.length,
                        itemBuilder: (context, index) {
                          final doc = employeesDocs[index];
                          final employee = doc.data() as Map<String, dynamic>;
                          final String fullName = "${employee['firstName'] ?? ''} ${employee['lastName'] ?? ''}".trim();
                          final bool isMeOwner = employee['salonRole'] == 'owner';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: isMeOwner ? Colors.amber[100] : Colors.red[50],
                                  child: Icon(isMeOwner ? Icons.star : Icons.person, color: isMeOwner ? Colors.amber[800] : Colors.redAccent)
                              ),
                              title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(isMeOwner ? "Właściciel (Ty)" : (employee['email'] ?? '')),
                              trailing: isMeOwner ? const SizedBox() : IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: () => _fireEmployee(doc.id, fullName)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // --- 🔴 PRZYCISK KASOWANIA SALONU (ZAWSZE NA SAMYM DOLE LISTY ZESPOŁU) ---
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _deleteSalonPermanently,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Skasuj profil salonu', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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

class BusinessDayRow extends StatelessWidget {
  final String dayName;
  final Map<String, dynamic> dayData;
  final Function(Map<String, dynamic>) onChanged;

  const BusinessDayRow({
    super.key,
    required this.dayName,
    required this.dayData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    bool isClosed = dayData['1_closed'] ?? false;
    String openTime = dayData['2_open'] ?? '08:00';
    String closeTime = dayData['3_close'] ?? '16:00';

    Future<void> pickTime(BuildContext context, bool isOpenTime) async {
      final currentStr = isOpenTime ? openTime : closeTime;
      final parts = currentStr.split(':');
      final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

      final picked = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );

      if (picked != null) {
        final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        final newData = Map<String, dynamic>.from(dayData);
        if (isOpenTime) {
          newData['2_open'] = formatted;
        } else {
          newData['3_close'] = formatted;
        }
        onChanged(newData);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isClosed ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isClosed ? Colors.grey[600] : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                !isClosed ? 'Otwarte' : 'Zamknięte',
                style: TextStyle(
                  color: !isClosed ? Colors.green[700] : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isClosed) ...[
            TextButton(
              onPressed: () => pickTime(context, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.deepPurple[50],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                openTime,
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text('do', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
            TextButton(
              onPressed: () => pickTime(context, false),
              style: TextButton.styleFrom(
                backgroundColor: Colors.deepPurple[50],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                closeTime,
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Checkbox(
            value: !isClosed,
            activeColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              final newData = Map<String, dynamic>.from(dayData);
              newData['1_closed'] = val == false;
              onChanged(newData);
            },
          ),
        ],
      ),
    );
  }
}