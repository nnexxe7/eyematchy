import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class SalonHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SalonHomeScreen({super.key, required this.userData});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
}

class _SalonHomeScreenState extends State<SalonHomeScreen> with SingleTickerProviderStateMixin {
  String? _selectedCityId;
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _salonNameController = TextEditingController();
  final TextEditingController _salonStreetController = TextEditingController();
  final TextEditingController _salonNumberController = TextEditingController();
  final TextEditingController _salonCityController = TextEditingController();
  bool _isCreating = false;

  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDurationController = TextEditingController();

  String _selectedEmployeeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _salonNameController.dispose();
    _salonStreetController.dispose();
    _salonNumberController.dispose();
    _salonCityController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    super.dispose();
  }

  Future<void> _createSalon() async {
    final name = _salonNameController.text.trim();
    final street = _salonStreetController.text.trim();
    final number = _salonNumberController.text.trim();

    if (name.isEmpty || street.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wypełnij nazwę oraz pola ulicy i numeru!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proszę wybrać miasto z listy!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isCreating = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final cityDoc = await FirebaseFirestore.instance.collection('cities').doc(_selectedCityId).get();
      final String cityName = (cityDoc.data() as Map<String, dynamic>?)?['name'] ?? _selectedCityId!;

      final String fullAddress = "ul. $street $number, $cityName";

      final salonRef = FirebaseFirestore.instance.collection('salons').doc();
      final String generatedSalonId = salonRef.id;

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(salonRef, {
        'salonId': generatedSalonId,
        'salonName': name,
        'address': fullAddress,
        'cityId': _selectedCityId,
        'openingHours': {
          '1_pon': {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
          '2_wt':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
          '3_sr':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
          '4_czw': {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
          '5_pt':  {'1_closed': false, '2_open': '08:00', '3_close': '16:00'},
          '6_sob': {'1_closed': true,  '2_open': '09:00', '3_close': '14:00'},
          '7_nd':  {'1_closed': true,  '2_open': '08:00', '3_close': '16:00'},
        },
        'addressDetails': {
          'street': street,
          'number': number,
          'city': cityName,
        },
        'ownerId': user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'employees': [user.uid],
      });

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'salonId': generatedSalonId,
        'salonName': name,
        'salonRole': 'owner',
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salon został utworzony!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _saveService({String? serviceId}) async {
    final name = _serviceNameController.text.trim();
    final price = double.tryParse(_servicePriceController.text.trim()) ?? 0.0;
    final duration = int.tryParse(_serviceDurationController.text.trim()) ?? 30;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj poprawną nazwę i cenę!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final salonId = widget.userData['salonId'];

    try {
      if (serviceId == null) {
        await FirebaseFirestore.instance.collection('services').add({
          'salonId': salonId,
          'employeeId': user.uid,
          'employeeName': '${widget.userData['firstName'] ?? ''} ${widget.userData['lastName'] ?? ''}'.trim(),
          'name': name,
          'price': price,
          'duration': duration,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('services').doc(serviceId).update({
          'name': name,
          'price': price,
          'duration': duration,
        });
      }

      _serviceNameController.clear();
      _servicePriceController.clear();
      _serviceDurationController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zapisano usługę!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _deleteService(String serviceId) async {
    try {
      await FirebaseFirestore.instance.collection('services').doc(serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usługa została usunięta.'), backgroundColor: Colors.black87),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd usuwania: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showServiceForm({String? serviceId, String? currentName, double? currentPrice, int? currentDuration}) {
    if (serviceId != null) {
      _serviceNameController.text = currentName ?? '';
      _servicePriceController.text = currentPrice?.toString() ?? '';
      _serviceDurationController.text = currentDuration?.toString() ?? '';
    } else {
      _serviceNameController.clear();
      _servicePriceController.clear();
      _serviceDurationController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24, left: 24, right: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceId == null ? 'Dodaj nową usługę' : 'Edytuj usługę',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _serviceNameController,
                decoration: InputDecoration(
                    labelText: 'Nazwa usługi (np. Przedłużanie rzęs 1:1)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _servicePriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Cena (PLN)', prefixText: 'zł ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _serviceDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Czas (minuty)', suffixText: ' min', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _saveService(serviceId: serviceId),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Zapisz usługę', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalonCreator() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 100, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text('Stwórz profil swojego salonu', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Podaj nazwę oraz dokładny adres, aby wygenerować unikalny identyfikator i zacząć zapraszać pracownice.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            TextField(
                controller: _salonNameController,
                decoration: InputDecoration(labelText: 'Nazwa Salonu', prefixIcon: const Icon(Icons.edit_note, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cities').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                }

                List<DropdownMenuItem<String>> cityItems = [];
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    cityItems.add(DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id)));
                  }
                }

                return DropdownButtonFormField<String>(
                  value: _selectedCityId,
                  items: cityItems,
                  onChanged: (value) => setState(() => _selectedCityId = value),
                  decoration: InputDecoration(labelText: 'Wybierz Miasto', prefixIcon: const Icon(Icons.location_city_outlined, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  hint: const Text('Wybierz miasto z listy'),
                  validator: (value) => value == null ? 'To pole jest wymagane' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(controller: _salonStreetController, decoration: InputDecoration(labelText: 'Ulica', prefixIcon: const Icon(Icons.add_location_alt_outlined, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(controller: _salonNumberController, decoration: InputDecoration(labelText: 'Nr lokalu / bud.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createSalon,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('Stwórz i przejdź do panelu', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 90,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
          final daysOfWeek = ['Nie', 'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob'];
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(color: isSelected ? Colors.deepPurple : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(daysOfWeek[date.weekday % 7], style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(date.day.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendInvitation() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    final mySalonId = widget.userData['salonId'];
    final mySalonName = widget.userData['salonName'] ?? "Twój Salon";

    if (mySalonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd: Brak identyfikatora salonu.'), backgroundColor: Colors.redAccent));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)));

    try {
      final userCheckSnapshot = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();

      if (userCheckSnapshot.docs.isNotEmpty) {
        final existingUser = userCheckSnapshot.docs.first.data();
        final String? existingSalonId = existingUser['salonId'];

        if (existingSalonId != null && existingSalonId.isNotEmpty) {
          if (mounted) Navigator.pop(context);
          if (existingSalonId == mySalonId) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ta stylistka jest już w Twoim zespole!'), backgroundColor: Colors.blueAccent));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ta stylistka należy już do innego zespołu!'), backgroundColor: Colors.orange));
          }
          return;
        }
      }

      final existingInvites = await FirebaseFirestore.instance.collection('invitations').where('salonId', isEqualTo: mySalonId).where('email', isEqualTo: email).where('status', isEqualTo: 'pending').get();

      if (existingInvites.docs.isNotEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaproszenie do tej osoby zostało już wysłane i oczekuje na odpowiedź!'), backgroundColor: Colors.orangeAccent));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('invitations').add({
        'email': email,
        'salonId': mySalonId,
        'salonName': mySalonName,
        'roleInSalon': 'employee',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _emailController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaproszenie wysłane pomyślnie!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Użytkownik nie zalogowany.')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> liveUserData = widget.userData;
        if (snapshot.hasData && snapshot.data!.exists) {
          liveUserData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final bool hasSalon = liveUserData.containsKey('salonId') && liveUserData['salonId'] != null;

        if (!hasSalon) {
          return Scaffold(
            appBar: AppBar(title: const Text('Konfiguracja Salonu'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            drawer: AppDrawer(userData: liveUserData, currentRole: 'salon'),
            body: _buildSalonCreator(),
          );
        }

        final bool isOwner = liveUserData['salonRole'] == 'owner';
        final String currentSalonName = liveUserData['salonName'] ?? 'Panel Salonu';

        return Scaffold(
          appBar: AppBar(
            title: Text(currentSalonName),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month), text: "Kalendarz"),
                Tab(icon: Icon(Icons.people), text: "Zespół"),
                Tab(icon: Icon(Icons.sell_outlined), text: "Cennik")
              ],
            ),
          ),
          drawer: AppDrawer(userData: liveUserData, currentRole: 'salon'),
          floatingActionButton: _tabController.index == 2
              ? FloatingActionButton(onPressed: () => _showServiceForm(), backgroundColor: Colors.deepPurple, child: const Icon(Icons.add, color: Colors.white))
              : null,
          body: TabBarView(
            controller: _tabController,
            children: [
              // --- ZAKŁADKA 1: KALENDARZ WIELOKOLUMNOWY Z WYSZARZANIEM ---
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('salons')
                    .doc(liveUserData['salonId'])
                    .snapshots(),
                builder: (context, salonSnapshot) {
                  if (salonSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                  }

                  Map<String, dynamic> openingHours = {};
                  if (salonSnapshot.hasData && salonSnapshot.data!.exists) {
                    final salonData = salonSnapshot.data!.data() as Map<String, dynamic>;
                    openingHours = salonData['openingHours'] ?? {};
                  }

                  final daysMapping = {
                    1: '1_pon',
                    2: '2_wt',
                    3: '3_sr',
                    4: '4_czw',
                    5: '5_pt',
                    6: '6_sob',
                    7: '7_nd'
                  };
                  String currentDayKey = daysMapping[_selectedDate.weekday] ?? '1_pon';
                  Map<String, dynamic> dayConfig = openingHours[currentDayKey] ?? {
                    '1_closed': false,
                    '2_open': '08:00',
                    '3_close': '16:00'
                  };

                  bool isDayClosed = dayConfig['1_closed'] ?? false;
                  int openHour = int.tryParse(dayConfig['2_open']?.split(':')[0] ?? '08') ?? 8;
                  int closeHour = int.tryParse(dayConfig['3_close']?.split(':')[0] ?? '16') ?? 16;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('salonId', isEqualTo: liveUserData['salonId'])
                        .snapshots(),
                    builder: (context, empSnapshot) {
                      if (empSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                      }

                      final employees = empSnapshot.data?.docs ?? [];

                      return Column(
                        children: [
                          _buildDatePicker(),

                          if (employees.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 60),
                                  ...employees.map((emp) {
                                    final eData = emp.data() as Map<String, dynamic>;
                                    final String name = eData['firstName'] ?? 'Stylistka';
                                    return Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border(left: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                                        ),
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                          // 🕒 SIATKA 15 GODZIN (7:00 - 21:00) Z WYSZARZANIEM
                          Expanded(
                            child: ListView.builder(
                              itemCount: 15,
                              itemBuilder: (context, index) {
                                final hour = index + 7;
                                bool isSlotClosed = isDayClosed || hour < openHour || hour >= closeHour;

                                return Container(
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 65,
                                        alignment: Alignment.center,
                                        color: isSlotClosed ? Colors.grey[200] : Colors.white,
                                        child: Text(
                                          "$hour:00",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: isSlotClosed ? Colors.grey[500] : Colors.black87, // POPRAWIONE
                                              fontSize: 13
                                          ),
                                        ),
                                      ),

                                      ...employees.map((emp) {
                                        return Expanded(
                                          child: Container(
                                            height: 65,
                                            decoration: BoxDecoration(
                                              color: isSlotClosed
                                                  ? Colors.grey[150] ?? const Color(0xEFEFEFEF)
                                                  : (index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                                              border: Border(left: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                                            ),
                                            child: InkWell(
                                              onTap: isSlotClosed ? null : () {
                                                final eData = emp.data() as Map<String, dynamic>;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Wybrano godzinę $hour:00 u stylistki: ${eData['firstName']}'),
                                                    duration: const Duration(seconds: 1),
                                                  ),
                                                );
                                              },
                                              child: isSlotClosed
                                                  ? const Center(
                                                child: Icon(Icons.lock_outline, size: 16, color: Colors.black26), // POPRAWIONE
                                              )
                                                  : const SizedBox.expand(),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // TAB 2: ZESPÓŁ
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOwner) ...[
                      const Text("Zaproś nową stylistkę do zespołu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _emailController, decoration: InputDecoration(hintText: "Wpisz e-mail stylistki", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                          const SizedBox(width: 12),
                          ElevatedButton(onPressed: _sendInvitation, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)), child: const Icon(Icons.send)),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                    const Text("Pracownicy salonu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: liveUserData['salonId']).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("Brak przypisanych pracowników.");
                          return ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final employee = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                              final String firstName = employee['firstName'] ?? 'Nieznane';
                              final String lastName = employee['lastName'] ?? 'Imię';
                              final String email = employee['email'] ?? '';
                              final bool empIsOwner = employee['salonRole'] == 'owner';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(backgroundColor: empIsOwner ? Colors.deepPurple : Colors.purple[300], child: Icon(empIsOwner ? Icons.star : Icons.person, color: Colors.white)),
                                title: Text("$firstName $lastName"),
                                subtitle: Text(email),
                                trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: empIsOwner ? Colors.green : Colors.blue, borderRadius: BorderRadius.circular(8)),
                                    child: Text(empIsOwner ? 'Właściciel' : 'Stylistka', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // TAB 3: OFERTA I CENNIK
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Oferta i Cennik", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text("Wybierz pracownika z listy, aby zobaczyć jego indywidualny cennik:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: liveUserData['salonId']).snapshots(),
                      builder: (context, empSnapshot) {
                        if (!empSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                        String selectedLabel = "Cały Salon (Wszystkie usługi)";
                        if (_selectedEmployeeFilter != 'all') {
                          for (var doc in empSnapshot.data!.docs) {
                            if (doc.id == _selectedEmployeeFilter) {
                              final sData = doc.data() as Map<String, dynamic>;
                              selectedLabel = "${sData['firstName'] ?? ''} ${sData['lastName'] ?? ''}".trim();
                              break;
                            }
                          }
                        }

                        return InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                              backgroundColor: Colors.white,
                              builder: (bottomSheetContext) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Wybierz pracownika", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    ListTile(
                                      leading: const Icon(Icons.storefront, color: Colors.deepPurple),
                                      title: const Text('Cały Salon (Wszystkie usługi)', style: TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: _selectedEmployeeFilter == 'all' ? const Icon(Icons.check_circle, color: Colors.deepPurple) : null,
                                      onTap: () {
                                        setState(() => _selectedEmployeeFilter = 'all');
                                        Navigator.pop(bottomSheetContext);
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ...empSnapshot.data!.docs.map((doc) {
                                      final empData = doc.data() as Map<String, dynamic>;
                                      final String fullName = "${empData['firstName'] ?? 'Nieznane'} ${empData['lastName'] ?? 'Imię'}";
                                      final String empId = doc.id;
                                      final bool isSelected = _selectedEmployeeFilter == empId;

                                      return ListTile(
                                        leading: const Icon(Icons.person_outline, color: Colors.grey),
                                        title: Text(fullName),
                                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.deepPurple) : null,
                                        onTap: () {
                                          setState(() => _selectedEmployeeFilter = empId);
                                          Navigator.pop(bottomSheetContext);
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_selectedEmployeeFilter == 'all' ? Icons.storefront : Icons.person_outline, color: Colors.deepPurple),
                                    const SizedBox(width: 12),
                                    Text(selectedLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                                  ],
                                ),
                                const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.deepPurple, size: 22),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _selectedEmployeeFilter == 'all'
                            ? FirebaseFirestore.instance.collection('services').where('salonId', isEqualTo: liveUserData['salonId']).snapshots()
                            : FirebaseFirestore.instance.collection('services').where('salonId', isEqualTo: liveUserData['salonId']).where('employeeId', isEqualTo: _selectedEmployeeFilter).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("Brak zdefiniowanych usług dla wybranego filtra.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))));
                          }
                          return ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final doc = snapshot.data!.docs[index];
                              final service = doc.data() as Map<String, dynamic>;
                              final String sId = doc.id;
                              final String name = service['name'] ?? '';
                              final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
                              final int duration = service['duration'] ?? 30;
                              final String creatorId = service['employeeId'] ?? '';
                              final String creatorName = service['employeeName'] ?? 'Salon';
                              final bool canEdit = isOwner || (user != null && creatorId == user.uid);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Text("Czas: $duration min • Wykonuje: $creatorName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("${price.toStringAsFixed(2)} zł", style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (canEdit) ...[
                                        const SizedBox(width: 8),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showServiceForm(serviceId: sId, currentName: name, currentPrice: price, currentDuration: duration);
                                            } else if (value == 'delete') {
                                              _deleteService(sId);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.grey), SizedBox(width: 8), Text('Edytuj')])),
                                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Usuń', style: TextStyle(color: Colors.red))])),
                                          ],
                                        ),
                                      ],
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
            ],
          ),
        );
      },
    );
  }
}