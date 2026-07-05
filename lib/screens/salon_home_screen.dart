import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'eye_match_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚀 IMPORT POWIADOMIEŃ

class SalonHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const SalonHomeScreen({super.key, required this.userData});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
}

class _SalonHomeScreenState extends State<SalonHomeScreen> with SingleTickerProviderStateMixin {
  String? _selectedCityId;
  late TabController _tabController;
  int _currentTabIndex = 0;
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

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  String? _draggingAppId;

  // 🚀 Dodana metoda resetująca stan przeciągania
  void _resetDraggingState() {
    if (_draggingAppId != null) {
      setState(() {
        _draggingAppId = null;
      });
    }
  }

  // 🚀 FUNKCJA: Pobieranie i zapisywanie tokena powiadomień
  Future<void> _setupPushNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      String? token = await messaging.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        print("Zapisano token FCM dla stylistki: $token");
      }

      messaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      print("Błąd podczas pobierania tokena FCM: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    _gridScrollController.addListener(() {
      if (_headerScrollController.hasClients && _gridScrollController.hasClients) {
        if (_headerScrollController.offset != _gridScrollController.offset) {
          _headerScrollController.jumpTo(_gridScrollController.offset);
        }
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
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _showAppointmentDetails(String appointmentId, Map<String, dynamic> appointmentData) {
    final String fallbackName = appointmentData['clientName'] ?? 'Klient';
    final String serviceName = appointmentData['serviceName'] ?? 'Usługa';
    final String time = appointmentData['time'] ?? '00:00';
    final String date = appointmentData['date'] ?? '';
    final int duration = appointmentData['duration'] ?? 30;
    final double price = (appointmentData['price'] as num?)?.toDouble() ?? 0.0;
    final String? clientId = appointmentData['clientId'];

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwner = widget.userData['salonRole'] == 'owner';
    final String? appointmentEmployeeId = appointmentData['employeeId'];
    final bool canCancelThisAppointment = isOwner || (currentUserId == appointmentEmployeeId);

    String displayDate = date;
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        displayDate = "${parts[2]}.${parts[1]}.${parts[0]}";
      }
    } catch (_) {}

    List<String> timeParts = time.split(':');
    int startMin = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
    int endMin = startMin + duration;
    String endHour = (endMin ~/ 60).toString();
    String endMinute = (endMin % 60).toString().padLeft(2, '0');
    String formattedEndTime = "$endHour:$endMinute";

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24, top: 24, left: 24, right: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Szczegóły wizyty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(height: 24),
                  FutureBuilder<DocumentSnapshot>(
                      future: clientId != null ? FirebaseFirestore.instance.collection('users').doc(clientId).get() : null,
                      builder: (context, clientSnap) {
                        String finalName = fallbackName;
                        String phoneNumber = '';
                        if (clientSnap.hasData && clientSnap.data!.exists) {
                          final cData = clientSnap.data!.data() as Map<String, dynamic>;
                          final String fName = cData['firstName'] ?? fallbackName;
                          final String lName = cData['lastName'] ?? '';
                          finalName = lName.isNotEmpty ? "$fName $lName" : fName;
                          phoneNumber = cData['phoneNumber'] ?? cData['phone'] ?? 'Brak numeru w profilu';
                        }
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), child: const Icon(Icons.person, color: Colors.deepPurple)),
                          title: const Text('Klientka', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(finalName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                              if (phoneNumber.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: 4.0), child: Row(children: [const Icon(Icons.phone, size: 14, color: Colors.deepPurple), const SizedBox(width: 6), Text(phoneNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.deepPurple))])),
                            ],
                          ),
                        );
                      }
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Colors.pinkAccent.withOpacity(0.1), child: const Icon(Icons.spa, color: Colors.pinkAccent)),
                    title: const Text('Usługa', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    trailing: Text('${price.toStringAsFixed(2)} zł', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.access_time, color: Colors.blue)),
                    title: const Text('Termin', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text('$displayDate\n$time - $formattedEndTime ($duration min)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  const SizedBox(height: 24),
                  if (clientId != null && clientId.isNotEmpty)
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ClientHistoryScreen(clientId: clientId, salonId: widget.userData['salonId'], clientName: fallbackName)));
                        },
                        icon: const Icon(Icons.history, color: Colors.deepPurple),
                        label: const Text('Historyczne wizyty klientki', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple, side: const BorderSide(color: Colors.deepPurple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  if (canCancelThisAppointment) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                    SizedBox(width: 8),
                                    Text('Odwołaj wizytę'),
                                  ],
                                ),
                                content: const Text('Czy na pewno chcesz odwołać tę wizytę? Tej operacji nie można cofnąć, a klientka otrzyma powiadomienie.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('Nie, powrót', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      Navigator.pop(dialogContext);
                                      Navigator.pop(context);

                                      try {
                                        await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).delete();

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wizyta została odwołana.'), backgroundColor: Colors.black87));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
                                        }
                                      }
                                    },
                                    child: const Text('Tak, odwołaj'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                        label: const Text('Odwołaj wizytę', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      ),
                    ),
                  ], // <-- Koniec warunku if
                ],
              ),
            ),
          );
        }
    );
  }

  Future<void> _createSalon() async {
    final name = _salonNameController.text.trim();
    final street = _salonStreetController.text.trim();
    final number = _salonNumberController.text.trim();

    if (name.isEmpty || street.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypełnij nazwę oraz pola ulicy i numeru!'), backgroundColor: Colors.redAccent));
      return;
    }
    if (_selectedCityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać miasto z listy!'), backgroundColor: Colors.redAccent));
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
        'addressDetails': {'street': street, 'number': number, 'city': cityName},
        'ownerId': user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'employees': [user.uid],
        'averageRating': 0.0,
        'ratingCount': 0,
      });

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {'salonId': generatedSalonId, 'salonName': name, 'salonRole': 'owner'});

      await batch.commit();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salon został utworzony!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _saveService({String? serviceId}) async {
    final name = _serviceNameController.text.trim();
    final price = double.tryParse(_servicePriceController.text.trim()) ?? 0.0;
    final duration = int.tryParse(_serviceDurationController.text.trim()) ?? 30;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Podaj poprawną nazwę i cenę!'), backgroundColor: Colors.redAccent));
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
        await FirebaseFirestore.instance.collection('services').doc(serviceId).update({'name': name, 'price': price, 'duration': duration});
      }

      _serviceNameController.clear(); _servicePriceController.clear(); _serviceDurationController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano usługę!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _deleteService(String serviceId) async {
    try {
      await FirebaseFirestore.instance.collection('services').doc(serviceId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usługa została usunięta.'), backgroundColor: Colors.black87));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.redAccent));
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24, top: 24, left: 24, right: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceId == null ? 'Dodaj nową usługę' : 'Edytuj usługę', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: _serviceNameController, decoration: InputDecoration(labelText: 'Nazwa usługi (np. Przedłużanie rzęs 1:1)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _servicePriceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Cena (PLN)', prefixText: 'zł ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _serviceDurationController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Czas (minuty)', suffixText: ' min', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => _saveService(serviceId: serviceId), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Zapisz usługę', style: TextStyle(fontSize: 16)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalonCreator() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.storefront_outlined, size: 100, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text('Stwórz profil swojego salonu', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Podaj nazwę oraz dokładny adres, aby wygenerować unikalny identyfikator i zacząć zapraszać pracownice.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(controller: _salonNameController, decoration: InputDecoration(labelText: 'Nazwa Salonu', prefixIcon: const Icon(Icons.edit_note, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cities').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                  List<DropdownMenuItem<String>> cityItems = [];
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    cityItems.add(DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id)));
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedCityId, items: cityItems, onChanged: (value) => setState(() => _selectedCityId = value),
                    decoration: InputDecoration(labelText: 'Wybierz Miasto', prefixIcon: const Icon(Icons.location_city_outlined, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                    hint: const Text('Wybierz miasto z listy'),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: TextField(controller: _salonStreetController, decoration: InputDecoration(labelText: 'Ulica', prefixIcon: const Icon(Icons.add_location_alt_outlined, color: Colors.deepPurple), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: TextField(controller: _salonNumberController, decoration: InputDecoration(labelText: 'Nr lokalu', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))))),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isCreating ? null : _createSalon, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('Stwórz i przejdź do panelu', style: TextStyle(fontSize: 18)))),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 90, color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
          final daysOfWeek = ['Nie', 'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob'];
          return GestureDetector(
            onTap: () {
              // 🚀 Resetujemy stan przeciągania przy zmianie daty, by uniknąć zawieszonego "szarego kafelka"
              _resetDraggingState();
              setState(() => _selectedDate = date);
            },
            child: Container(
              width: 65, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wpisać adres e-mail.'), backgroundColor: Colors.redAccent));
      return;
    }

    final bool isEmailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
    if (!isEmailValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wpisany tekst nie wygląda na poprawny adres e-mail!'), backgroundColor: Colors.redAccent));
      return;
    }

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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaproszenie do tej osoby zostało już wysłane!'), backgroundColor: Colors.orangeAccent));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('invitations').add({
        'email': email, 'salonId': mySalonId, 'salonName': mySalonName, 'roleInSalon': 'employee', 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(),
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
            actions: [
              IconButton(icon: const Icon(Icons.face_retouching_natural), tooltip: 'Uruchom EyeMatch AI', onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const EyeMatchScreen())); }),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month), text: "Kalendarz"),
                Tab(icon: Icon(Icons.people), text: "Zespół"),
                Tab(icon: Icon(Icons.sell_outlined), text: "Cennik"),
                Tab(icon: Icon(Icons.star_outline), text: "Opinie"),
              ],
            ),
          ),
          drawer: AppDrawer(userData: liveUserData, currentRole: 'salon'),
          floatingActionButton: _currentTabIndex == 2
              ? FloatingActionButton(onPressed: () => _showServiceForm(), backgroundColor: Colors.deepPurple, child: const Icon(Icons.add, color: Colors.white))
              : null,
          body: TabBarView(
            controller: _tabController,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('salons').doc(liveUserData['salonId']).snapshots(),
                builder: (context, salonSnapshot) {
                  if (!salonSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                  Map<String, dynamic> openingHours = {};
                  if (salonSnapshot.data!.exists) {
                    final salonData = salonSnapshot.data!.data() as Map<String, dynamic>;
                    openingHours = salonData['openingHours'] ?? {};
                  }

                  final daysMapping = {1: '1_pon', 2: '2_wt', 3: '3_sr', 4: '4_czw', 5: '5_pt', 6: '6_sob', 7: '7_nd'};
                  String currentDayKey = daysMapping[_selectedDate.weekday] ?? '1_pon';
                  Map<String, dynamic> dayConfig = openingHours[currentDayKey] ?? {'1_closed': false, '2_open': '08:00', '3_close': '16:00'};

                  bool isDayClosed = dayConfig['1_closed'] ?? false;
                  List<String> openParts = (dayConfig['2_open'] ?? '08:00').split(':');
                  List<String> closeParts = (dayConfig['3_close'] ?? '16:00').split(':');

                  int openInMinutes = (int.tryParse(openParts[0]) ?? 8) * 60 + (int.tryParse(openParts[1]) ?? 0);
                  int closeInMinutes = (int.tryParse(closeParts[0]) ?? 16) * 60 + (int.tryParse(closeParts[1]) ?? 0);

                  final String formattedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('appointments').where('salonId', isEqualTo: liveUserData['salonId']).where('date', isEqualTo: formattedDateStr).snapshots(),
                    builder: (context, appointmentsSnapshot) {
                      if (!appointmentsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                      final List<QueryDocumentSnapshot> activeAppointments = appointmentsSnapshot.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: liveUserData['salonId']).snapshots(),
                        builder: (context, empSnapshot) {
                          if (!empSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                          final List<QueryDocumentSnapshot> employees = List.from(empSnapshot.data?.docs ?? []);
                          employees.sort((a, b) {
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

                          return Column(
                            children: [
                              _buildDatePicker(),
                              if (employees.isNotEmpty)
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      double availableWidth = constraints.maxWidth - 60;
                                      int displayCount = employees.length > 3 ? 3 : employees.length;
                                      double columnWidth = availableWidth / displayCount;

                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(width: 60, height: 50, decoration: BoxDecoration(color: Colors.grey[100], border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), right: BorderSide(color: Colors.grey[300]!, width: 0.5)))),
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  controller: _headerScrollController, scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(),
                                                  child: Row(
                                                    children: employees.map((emp) {
                                                      final eData = emp.data() as Map<String, dynamic>;
                                                      final String firstName = eData['firstName'] ?? 'Stylistka';
                                                      final String lastName = eData['lastName'] ?? '';

                                                      return Container(
                                                        width: columnWidth, height: 50, padding: const EdgeInsets.symmetric(vertical: 6), alignment: Alignment.center,
                                                        decoration: BoxDecoration(color: Colors.grey[100], border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), left: BorderSide(color: Colors.grey[300]!, width: 0.5))),
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple)),
                                                            if (lastName.isNotEmpty) Text(lastName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w400, fontSize: 10, color: Colors.deepPurple[400])),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 60,
                                                    child: Column(
                                                      children: List.generate(68, (index) {
                                                        int currentMinutesFromDayStart = (7 * 60) + (index * 15);
                                                        int hour = currentMinutesFromDayStart ~/ 60;
                                                        int minute = currentMinutesFromDayStart % 60;
                                                        String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                                                        bool isSlotClosed = isDayClosed || currentMinutesFromDayStart < openInMinutes || currentMinutesFromDayStart >= closeInMinutes;
                                                        bool isFullHour = minute == 0;

                                                        return Container(
                                                          width: 60, height: 55,
                                                          decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey[300]!, width: 0.5), bottom: BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.transparent, width: isFullHour ? 0.8 : 0.0))),
                                                          child: Stack(
                                                            clipBehavior: Clip.none,
                                                            children: [
                                                              Positioned(left: 0, right: 0, top: -6, child: Container(alignment: Alignment.center, child: Text(formattedTime, textAlign: TextAlign.center, style: TextStyle(fontWeight: isFullHour ? FontWeight.bold : FontWeight.w400, color: isSlotClosed ? Colors.grey[400] : Colors.black87, fontSize: 11, height: 1.0)))),
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: SingleChildScrollView(
                                                      controller: _gridScrollController, scrollDirection: Axis.horizontal,
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: employees.map((emp) {
                                                          final String empId = emp.id;
                                                          final eData = emp.data() as Map<String, dynamic>;
                                                          final String empFirstName = eData['firstName'] ?? 'Stylistka';

                                                          // 🚀 NOWE: Uprawnienia! Czy to właściciel salonu, czy to jest kolumna tej konkretnej stylistki?
                                                          final bool canManageThisColumn = isOwner || (user.uid == empId);

                                                          return SizedBox(
                                                            width: columnWidth,
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                                              children: List.generate(68, (index) {
                                                                int currentMinutesFromDayStart = (7 * 60) + (index * 15);
                                                                int hour = currentMinutesFromDayStart ~/ 60;
                                                                int minute = currentMinutesFromDayStart % 60;
                                                                String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                                                                bool isSlotClosed = isDayClosed || currentMinutesFromDayStart < openInMinutes || currentMinutesFromDayStart >= closeInMinutes;
                                                                bool isFullHour = minute == 0;

                                                                Map<String, dynamic>? appointmentData;
                                                                String? bookedAppId;
                                                                bool isStartOfBooking = false;
                                                                bool isEndOfBooking = false;

                                                                for (var appDoc in activeAppointments) {
                                                                  final d = appDoc.data() as Map<String, dynamic>;
                                                                  if (d['employeeId'] != empId) continue;
                                                                  List<String> timeParts = (d['time'] ?? '00:00').split(':');
                                                                  int appStart = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
                                                                  int duration = d['duration'] ?? 30;
                                                                  int appEnd = appStart + duration;

                                                                  if (currentMinutesFromDayStart >= appStart && currentMinutesFromDayStart < appEnd) {
                                                                    appointmentData = d;
                                                                    bookedAppId = appDoc.id;
                                                                    isStartOfBooking = (currentMinutesFromDayStart == appStart);
                                                                    isEndOfBooking = (currentMinutesFromDayStart + 15 == appEnd);
                                                                    break;
                                                                  }
                                                                }

                                                                bool hasBooking = appointmentData != null;
                                                                bool drawBottomLine = !hasBooking || isEndOfBooking;

                                                                return DragTarget<Map<String, dynamic>>(
                                                                  onWillAcceptWithDetails: (details) {
                                                                    // 1. Nie możemy upuszczać wizyt na cudzą kolumnę (chyba że jesteśmy szefową)
                                                                    if (!canManageThisColumn) return false;

                                                                    // 🚀 2. POPRAWKA: Blokujemy od razu tylko jeśli salon jest zamknięty (USUNIĘTO hasBooking!)
                                                                    if (isSlotClosed) return false;

                                                                    final draggedData = details.data;
                                                                    final int draggedDuration = draggedData['duration'] ?? 30;
                                                                    final String draggedAppId = draggedData['appId'];

                                                                    int newStart = currentMinutesFromDayStart;
                                                                    int newEnd = newStart + draggedDuration;

                                                                    // 3. Blokada wyjścia poza godziny otwarcia
                                                                    if (newEnd > closeInMinutes) return false;

                                                                    // 4. Zaawansowane sprawdzanie kolizji
                                                                    for (var appDoc in activeAppointments) {
                                                                      // Ignorujemy wizytę, którą właśnie przesuwamy (dzięki temu możemy najechać na jej własne stare miejsce!)
                                                                      if (appDoc.id == draggedAppId) continue;

                                                                      final d = appDoc.data() as Map<String, dynamic>;
                                                                      if (d['employeeId'] != empId) continue;

                                                                      List<String> timeParts = (d['time'] ?? '00:00').split(':');
                                                                      int appStart = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
                                                                      int appDuration = d['duration'] ?? 30;
                                                                      int appEnd = appStart + appDuration;

                                                                      // Sprawdzamy, czy w tym samym czasie nie ma INNEJ wizyty
                                                                      if (newStart < appEnd && newEnd > appStart) {
                                                                        return false; // Wykryto kolizję z obcą wizytą!
                                                                      }
                                                                    }

                                                                    return true; // Droga wolna!
                                                                  },
                                                                  onAcceptWithDetails: (details) async {
                                                                    final draggedData = details.data;
                                                                    final String draggedAppId = draggedData['appId'];

                                                                    try {
                                                                      await FirebaseFirestore.instance
                                                                          .collection('appointments')
                                                                          .doc(draggedAppId)
                                                                          .update({
                                                                        'time': formattedTime,
                                                                        'date': formattedDateStr,
                                                                        'employeeId': empId,
                                                                        'employeeName': empFirstName,
                                                                      });
                                                                      if (context.mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Przesunięto wizytę!'), backgroundColor: Colors.green));
                                                                      }
                                                                    } catch (e) {
                                                                      if (context.mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd podczas przesuwania!'), backgroundColor: Colors.redAccent));
                                                                      }
                                                                    } finally {
                                                                      _resetDraggingState();
                                                                    }
                                                                  },
                                                                  builder: (context, candidateData, rejectedData) {
                                                                    bool isHovered = candidateData.isNotEmpty;
                                                                    Color baseColor = isSlotClosed ? Colors.grey[200]! : Colors.white;
                                                                    Color containerColor = isHovered ? Colors.green[100]! : baseColor;

                                                                    return Container(
                                                                      height: 55,
                                                                      decoration: BoxDecoration(
                                                                          color: containerColor,
                                                                          border: Border(
                                                                              left: BorderSide(color: Colors.grey[200]!, width: 0.5),
                                                                              bottom: drawBottomLine ? BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.grey[200]!, width: isFullHour ? 0.8 : 0.5) : BorderSide.none
                                                                          )
                                                                      ),
                                                                      child: hasBooking
                                                                          ? Builder(builder: (context) {
                                                                        final appData = appointmentData!;
                                                                        bool isBeingDragged = bookedAppId == _draggingAppId;
                                                                        int duration = appData['duration'] ?? 30;
                                                                        double fullHeight = (duration / 15) * 55.0;

                                                                        Widget bookingTile = GestureDetector(
                                                                          onTap: () => _showAppointmentDetails(bookedAppId!, appData),
                                                                          child: Container(
                                                                            width: double.infinity,
                                                                            margin: EdgeInsets.only(left: 3, right: 3, top: isStartOfBooking ? 3 : 0, bottom: isEndOfBooking ? 3 : 0),
                                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                                            decoration: BoxDecoration(
                                                                                color: Colors.deepPurple,
                                                                                borderRadius: BorderRadius.vertical(
                                                                                    top: isStartOfBooking ? const Radius.circular(8) : Radius.zero,
                                                                                    bottom: isEndOfBooking ? const Radius.circular(8) : Radius.zero
                                                                                )
                                                                            ),
                                                                            child: isStartOfBooking
                                                                                ? Column(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Builder(
                                                                                  builder: (context) {
                                                                                    List<String> timeParts = (appData['time'] ?? '00:00').split(':');
                                                                                    int startMin = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
                                                                                    int endMin = startMin + duration;
                                                                                    String endHour = (endMin ~/ 60).toString();
                                                                                    String endMinute = (endMin % 60).toString().padLeft(2, '0');
                                                                                    return Text("${appData['time']} - $endHour:$endMinute", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w400));
                                                                                  },
                                                                                ),
                                                                                const SizedBox(height: 1),
                                                                                Expanded(child: Container(alignment: Alignment.centerLeft, child: Text(appData['clientName'] ?? 'Klient', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))),
                                                                                Text(appData['serviceName'] ?? 'Usługa', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                                                                              ],
                                                                            )
                                                                                : const SizedBox.shrink(),
                                                                          ),
                                                                        );

                                                                        if (isBeingDragged) {
                                                                          bookingTile = Opacity(opacity: 0.3, child: bookingTile);
                                                                        }

                                                                        // 🚀 BLOKADA NR 2: Jeśli to nie jest Twoja kolumna (i nie jesteś szefem),
                                                                        // to zwracamy zwykły kafelek bez opcji przeciągania (LongPressDraggable).
                                                                        if (!canManageThisColumn) {
                                                                          return bookingTile;
                                                                        }

                                                                        return LongPressDraggable<Map<String, dynamic>>(
                                                                          data: {...appData, 'appId': bookedAppId},
                                                                          delay: const Duration(milliseconds: 300),
                                                                          dragAnchorStrategy: pointerDragAnchorStrategy,
                                                                          onDragStarted: () => setState(() => _draggingAppId = bookedAppId),
                                                                          onDraggableCanceled: (_, __) => _resetDraggingState(),
                                                                          feedback: Material(
                                                                            color: Colors.transparent,
                                                                            child: Container(
                                                                              width: columnWidth,
                                                                              height: fullHeight,
                                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                                              decoration: BoxDecoration(
                                                                                  color: Colors.deepPurple.withOpacity(0.95),
                                                                                  borderRadius: BorderRadius.circular(8),
                                                                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)]
                                                                              ),
                                                                              child: Column(
                                                                                mainAxisAlignment: MainAxisAlignment.start,
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                  Text("${appData['time']}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                                                                  const SizedBox(height: 4),
                                                                                  Text(appData['clientName'] ?? 'Klient', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                                                  const SizedBox(height: 2),
                                                                                  Text(appData['serviceName'] ?? 'Usługa', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          childWhenDragging: bookingTile,
                                                                          child: bookingTile,
                                                                        );
                                                                      })
                                                                          : InkWell(
                                                                        onTap: isSlotClosed ? null : () {},
                                                                        child: isSlotClosed ? Center(child: isFullHour ? const Icon(Icons.lock_outline, size: 14, color: Colors.black26) : const SizedBox()) : const SizedBox.expand(),
                                                                      ),
                                                                    );
                                                                  },
                                                                );
                                                              }),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),

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
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                          if (snapshot.data!.docs.isEmpty) return const Text("Brak przypisanych pracowników.");

                          List<QueryDocumentSnapshot> employeeDocs = List.from(snapshot.data!.docs);
                          employeeDocs.sort((a, b) {
                            final dataA = a.data() as Map<String, dynamic>;
                            final dataB = b.data() as Map<String, dynamic>;
                            bool isOwnerA = dataA['salonRole'] == 'owner';
                            bool isOwnerB = dataB['salonRole'] == 'owner';
                            if (isOwnerA && !isOwnerB) return -1;
                            if (!isOwnerA && isOwnerB) return 1;
                            int compareNames = (dataA['firstName'] ?? '').toString().toLowerCase().compareTo((dataB['firstName'] ?? '').toString().toLowerCase());
                            if (compareNames != 0) return compareNames;
                            return (dataA['lastName'] ?? '').toString().toLowerCase().compareTo((dataB['lastName'] ?? '').toString().toLowerCase());
                          });

                          return ListView.builder(
                            itemCount: employeeDocs.length,
                            itemBuilder: (context, index) {
                              final employee = employeeDocs[index].data() as Map<String, dynamic>;
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
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                          if (snapshot.data!.docs.isEmpty) {
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

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('salonId', isEqualTo: liveUserData['salonId'])
                    .snapshots(),
                builder: (context, empSnapshot) {
                  if (!empSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                  final employees = empSnapshot.data!.docs;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointments')
                        .where('salonId', isEqualTo: liveUserData['salonId'])
                        .where('isRated', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));

                      List<QueryDocumentSnapshot> reviewDocs = snapshot.data!.docs.where((doc) {
                        if (_selectedEmployeeFilter == 'all') return true;
                        return (doc.data() as Map<String, dynamic>)['employeeId'] == _selectedEmployeeFilter;
                      }).toList();

                      double avgRating = 0.0;
                      if (reviewDocs.isNotEmpty) {
                        avgRating = reviewDocs.map((d) => (d.data() as Map<String, dynamic>)['rating'] as num).reduce((a, b) => a + b) / reviewDocs.length;
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: DropdownButtonFormField<String>(
                              value: _selectedEmployeeFilter,
                              decoration: InputDecoration(labelText: "Wybierz stylistkę", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text("Cały Salon")),
                                ...employees.map((e) {
                                  final d = e.data() as Map<String, dynamic>;
                                  return DropdownMenuItem(value: e.id, child: Text("${d['firstName']} ${d['lastName']}"));
                                })
                              ],
                              onChanged: (val) => setState(() => _selectedEmployeeFilter = val!),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(24.0),
                            width: double.infinity,
                            color: Colors.deepPurple[50],
                            child: Column(
                              children: [
                                Text(_selectedEmployeeFilter == 'all' ? "Średnia ocena salonu" : "Średnia ocena stylistki", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.deepPurple)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 40),
                                    const SizedBox(width: 8),
                                    Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ],
                                ),
                                Text("Na podstawie ${reviewDocs.length} opinii", style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),

                          Expanded(
                            child: reviewDocs.isEmpty
                                ? Center(child: Text("Brak opinii dla tego filtra.", style: TextStyle(color: Colors.grey[600])))
                                : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: reviewDocs.length,
                              itemBuilder: (context, index) {
                                final data = reviewDocs[index].data() as Map<String, dynamic>;
                                final int rating = data['rating'] ?? 5;
                                final String review = data['review'] ?? '';
                                final String clientName = data['clientNameForReview'] ?? 'Anonim';
                                final String serviceName = data['serviceName'] ?? 'Usługa';
                                final String empName = data['employeeName'] ?? 'Stylistka';
                                final Timestamp? ratedAt = data['ratedAt'] as Timestamp?;
                                final dateStr = ratedAt != null ? "${ratedAt.toDate().day.toString().padLeft(2, '0')}.${ratedAt.toDate().month.toString().padLeft(2, '0')}.${ratedAt.toDate().year}" : '';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)), Text(dateStr, style: TextStyle(color: Colors.grey[500]))]),
                                        const SizedBox(height: 6),
                                        Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 18))),
                                        const SizedBox(height: 6),
                                        Text("Stylistka: $empName", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.deepPurple)),
                                        Text("Usługa: $serviceName", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                        if (review.isNotEmpty) ...[const SizedBox(height: 8), Text(review, style: const TextStyle(fontSize: 14))],
                                      ],
                                    ),
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
            ],
          ),
        );
      },
    );
  }
}

class ClientHistoryScreen extends StatelessWidget {
  final String clientId;
  final String salonId;
  final String clientName;

  const ClientHistoryScreen({
    super.key,
    required this.clientId,
    required this.salonId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(clientId).get(),
          builder: (context, snapshot) {
            String fullName = clientName;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final fName = data['firstName'] ?? clientName;
              final lName = data['lastName'] ?? '';
              fullName = lName.isNotEmpty ? "$fName $lName" : fName;
            }
            return Text('Historia (10): $fullName');
          },
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🚀 TWARDY LIMIT W BAZIE DANYCH: Pobieramy tylko 10 najnowszych wizyt
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('salonId', isEqualTo: salonId)
            .where('clientId', isEqualTo: clientId)
            .orderBy('date', descending: true) // Wymaga indeksu w Firebase!
            .limit(10) // <-- BLOKADA (Zabezpiecza przed kosztami)
            .snapshots(),
        builder: (context, snapshot) {
          // Obsługa błędu braku indeksu
          if (snapshot.hasError) {
            print("🚨 BŁĄD FIREBASE: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Błąd bazy danych (prawdopodobnie brak indeksu).\nSprawdź konsolę w środowisku programistycznym i kliknij w wygenerowany link, aby utworzyć indeks Firebase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Brak historii wizyt dla tej klientki.', style: TextStyle(color: Colors.grey, fontSize: 16)));

          final docs = snapshot.data!.docs.toList();

          // Lokalne sortowanie czasowe dla wizyt z tego samego dnia
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            int dateComparison = (dataB['date'] ?? '').compareTo(dataA['date'] ?? '');
            if (dateComparison == 0) return (dataB['time'] ?? '').compareTo(dataA['time'] ?? '');
            return dateComparison;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = data['date'] ?? '';
              final time = data['time'] ?? '';
              final serviceName = data['serviceName'] ?? 'Usługa';
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final employeeName = data['employeeName'] ?? 'Stylistka';

              String displayDate = date;
              try {
                final parts = date.split('-');
                if (parts.length == 3) displayDate = "${parts[2]}.${parts[1]}.${parts[0]}";
              } catch (_) {}

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), child: const Icon(Icons.check_circle_outline, color: Colors.deepPurple)),
                  title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('$displayDate godz. $time\nWykonuje: $employeeName'),
                  ),
                  trailing: Text('${price.toStringAsFixed(2)} zł', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 15)),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}