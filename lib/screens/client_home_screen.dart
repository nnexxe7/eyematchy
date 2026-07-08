import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ClientHomeScreen({super.key, required this.userData});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentStep = 1;

  String? _selectedCityId;
  String? _selectedSalonId;
  String? _selectedSalonName;
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedTime;

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  // 🚀 NOWA FUNKCJA: Pobieranie i zapisywanie tokena powiadomień
  Future<void> _setupPushNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      // 1. Pobranie unikalnego tokena urządzenia
      String? token = await messaging.getToken();

      if (token != null) {
        // 2. Zapisanie tokena w profilu użytkownika w bazie Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true)); // merge: true nie nadpisuje reszty danych!
        print("Zapisano token FCM dla klientki: $token");
      }

      // 3. Nasłuchiwanie na ewentualną zmianę tokena przez system
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

    // 🚀 WYWOŁANIE FUNKCJI TOKENA PRZY UCHURUCHOMIENIU EKRANU
    _setupPushNotifications();

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
    _headerScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  // 🚀 OPTYMALIZACJA: Dodano parametry z wyliczoną już oceną z dokumentu salonu
  void _showReviewsBottomSheet(String salonId, String salonName, double overallAvgRating, int overallRatingCount) {
    String selectedEmpFilter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('Opinie o: $salonName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      // 🚀 OPTYMALIZACJA TWARDEGO LIMITU I SORTOWANIA Z POZIOMU BAZY
                      stream: selectedEmpFilter == 'all'
                          ? FirebaseFirestore.instance
                          .collection('appointments')
                          .where('salonId', isEqualTo: salonId)
                          .where('isRated', isEqualTo: true)
                          .orderBy('ratedAt', descending: true) // Ostatnie wizyty
                          .limit(15) // Blokada przed zżeraniem readsów!
                          .snapshots()
                          : FirebaseFirestore.instance
                          .collection('appointments')
                          .where('salonId', isEqualTo: salonId)
                          .where('employeeId', isEqualTo: selectedEmpFilter)
                          .where('isRated', isEqualTo: true)
                          .orderBy('ratedAt', descending: true)
                          .limit(15)
                          .snapshots(),
                      builder: (context, snapshot) {

                        // Zabezpieczenie przed błędem z brakiem Indeksu
                        if (snapshot.hasError) {
                          print("🚨 BŁĄD FIREBASE OPINIE: ${snapshot.error}");
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text('Wymagany indeks w Firebase.\nSprawdź konsolę i kliknij wygenerowany link.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          ));
                        }

                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                        // Otrzymujemy od razu gotową, posortowaną listę (max 15 elementów)
                        List<QueryDocumentSnapshot> reviewDocs = snapshot.data!.docs;

                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 40),
                                  const SizedBox(width: 12),
                                  // 🚀 Używamy od razu ogólnej oceny salonu (żadnego liczenia w pętli)
                                  Text(overallAvgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(width: 12),
                                  Text("/ 5.0\n($overallRatingCount opinii)", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: salonId).snapshots(),
                                builder: (context, empSnap) {
                                  return DropdownButtonFormField<String>(
                                    value: selectedEmpFilter,
                                    decoration: InputDecoration(labelText: "Filtruj po stylistce (Max 15 ostatnich)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text("Wszyscy pracownicy")),
                                      if (empSnap.hasData) ...empSnap.data!.docs.map((e) {
                                        final d = e.data() as Map<String, dynamic>;
                                        return DropdownMenuItem(value: e.id, child: Text("${d['firstName']} ${d['lastName']}"));
                                      })
                                    ],
                                    onChanged: (val) => setModalState(() => selectedEmpFilter = val!),
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 24),

                            Expanded(
                              child: reviewDocs.isEmpty
                                  ? const Center(child: Text("Brak opinii dla tego filtra."))
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
                                  final dateStr = (data['ratedAt'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? '';

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
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Użytkownik niezalogowany.')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> liveUserData = widget.userData;
        if (snapshot.hasData && snapshot.data!.exists) {
          liveUserData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final String firstName = liveUserData['firstName'] ?? 'Klient';

        String appBarTitle = 'Znajdź Salon';
        if (_currentStep == 2) appBarTitle = _selectedSalonName ?? 'Wybierz termin';
        if (_currentStep == 3) appBarTitle = 'Wybierz usługę - $_selectedEmployeeName';

        return PopScope(
          canPop: _currentStep == 1,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(appBarTitle),
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              leading: _currentStep > 1
                  ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack)
                  : null,
            ),
            drawer: _currentStep == 1 ? AppDrawer(userData: liveUserData, currentRole: 'client') : null,
            body: IndexedStack(
              index: _currentStep - 1,
              children: [
                _buildStep1SalonsList(firstName),
                _buildStep2CalendarGrid(),
                _buildStep3ServicesList(user.uid, firstName),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep1SalonsList(String firstName) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Witaj, $firstName! 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Najpierw wybierz swoje miasto:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
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
                  cityItems.add(DropdownMenuItem(value: doc.id, child: Text(data['name'] ?? doc.id)));
                }
              }
              return DropdownButtonFormField<String>(
                value: _selectedCityId,
                items: cityItems,
                onChanged: (value) => setState(() => _selectedCityId = value),
                decoration: InputDecoration(
                  hintText: 'Wybierz miasto z listy...',
                  prefixIcon: const Icon(Icons.location_city, color: Colors.pinkAccent),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Dostępne salony:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Expanded(
            child: _selectedCityId == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.maps_home_work_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Wskaż miasto powyżej,\naby wyświetlić dostępne salony.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                ],
              ),
            )
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('salons').where('cityId', isEqualTo: _selectedCityId).snapshots(),
              builder: (context, salonsSnapshot) {
                if (salonsSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                if (!salonsSnapshot.hasData || salonsSnapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Brak zarejestrowanych salonów w tym mieście.', style: TextStyle(color: Colors.grey[600], fontSize: 15)));
                }
                return ListView.builder(
                  itemCount: salonsSnapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = salonsSnapshot.data!.docs[index];
                    final salon = doc.data() as Map<String, dynamic>;
                    final String name = salon['salonName'] ?? 'Nieznany Salon';
                    final String address = salon['address'] ?? 'Brak adresu';
                    final List<dynamic> emps = salon['employees'] ?? [];

                    final int ratingCount = salon['ratingCount'] ?? 0;
                    final double avgRating = (salon['averageRating'] as num?)?.toDouble() ?? 0.0;

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
                                CircleAvatar(backgroundColor: Colors.pink.withOpacity(0.1), child: const Icon(Icons.content_cut, color: Colors.pinkAccent)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          if (ratingCount > 0)
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                                const SizedBox(width: 4),
                                                Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                Text(' ($ratingCount)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                              ],
                                            )
                                          else
                                            const Text('Nowy', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(address, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis))]),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('Zespół: ${emps.length} os.', style: const TextStyle(color: Colors.black54, fontSize: 13))),
                                if (ratingCount > 0) ...[
                                  TextButton(
                                    // 🚀 OPTYMALIZACJA: Przekazujemy statystyki od razu do funkcji!
                                    onPressed: () => _showReviewsBottomSheet(doc.id, name, avgRating, ratingCount),
                                    style: TextButton.styleFrom(foregroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                    child: const Text('Pokaż opinie', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSalonId = doc.id;
                                      _selectedSalonName = name;
                                      _currentStep = 2;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    );
  }

  Widget _buildStep2CalendarGrid() {
    if (_selectedSalonId == null) return const SizedBox();

    final DateTime now = DateTime.now();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('salons').doc(_selectedSalonId).snapshots(),
      builder: (context, salonSnapshot) {
        if (!salonSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

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
          stream: FirebaseFirestore.instance
              .collection('appointments')
              .where('salonId', isEqualTo: _selectedSalonId)
              .where('date', isEqualTo: formattedDateStr)
              .snapshots(),
          builder: (context, appointmentsSnapshot) {

            // 🚀 MĄDRE FILTROWANIE: Pobieramy dane z cache, ale odrzucamy "duchy" z poprzedniego dnia oraz ARCHIWALNE
            final List<QueryDocumentSnapshot> activeAppointments = appointmentsSnapshot.hasData
                ? appointmentsSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final bool isArchived = data['archived'] ?? false;
              return data['date'] == formattedDateStr && !isArchived;
            }).toList()
                : [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: _selectedSalonId).snapshots(),
              builder: (context, empSnapshot) {
                if (!empSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                final List<QueryDocumentSnapshot> employees = List.from(empSnapshot.data!.docs);
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
                    Container(
                      height: 90, color: Colors.white,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, itemCount: 30,
                        itemBuilder: (context, index) {
                          final date = DateTime.now().add(Duration(days: index));
                          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month && date.year == _selectedDate.year;
                          final daysOfWeek = ['Nie', 'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedDate = date),
                            child: Container(
                              width: 65, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(color: isSelected ? Colors.pinkAccent : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
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
                    ),

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
                                    Container(
                                      width: 60, height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), right: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _headerScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const NeverScrollableScrollPhysics(),
                                        child: Row(
                                          children: employees.map((emp) {
                                            final eData = emp.data() as Map<String, dynamic>;
                                            final String firstName = eData['firstName'] ?? 'Stylistka';
                                            final String lastName = eData['lastName'] ?? '';

                                            return Container(
                                              width: columnWidth, height: 50, padding: const EdgeInsets.symmetric(vertical: 6), alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), left: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent)),
                                                  if (lastName.isNotEmpty)
                                                    Text(lastName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w400, fontSize: 10, color: Colors.pinkAccent.withOpacity(0.8))),
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
                                                    Positioned(
                                                      left: 0, right: 0, top: -6,
                                                      child: Container(
                                                        alignment: Alignment.center,
                                                        child: Text(formattedTime, textAlign: TextAlign.center, style: TextStyle(fontWeight: isFullHour ? FontWeight.bold : FontWeight.w400, color: isSlotClosed ? Colors.grey[400] : Colors.black87, fontSize: 11, height: 1.0)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: _gridScrollController,
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: employees.map((emp) {
                                                final String empId = emp.id;
                                                final eData = emp.data() as Map<String, dynamic>;
                                                final String firstName = eData['firstName'] ?? 'Stylistka';

                                                return SizedBox(
                                                  width: columnWidth,
                                                  child: Column(
                                                    children: List.generate(68, (index) {
                                                      int currentMinutes = (7 * 60) + (index * 15);
                                                      int hour = currentMinutes ~/ 60;
                                                      int minute = currentMinutes % 60;
                                                      String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                                                      bool isSlotClosed = isDayClosed || currentMinutes < openInMinutes || currentMinutes >= closeInMinutes;
                                                      bool isFullHour = minute == 0;

                                                      DateTime slotDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
                                                      bool isPastSlot = slotDateTime.isBefore(now);

                                                      bool isAlreadyBooked = false;
                                                      bool isStartOfBooking = false;
                                                      bool isEndOfBooking = false;

                                                      for (var appDoc in activeAppointments) { // 🚀 Iterujemy po przefiltrowanej liscie (bez archiwalnych)
                                                        final d = appDoc.data() as Map<String, dynamic>;
                                                        if (d['employeeId'] != empId) continue;

                                                        List<String> timeParts = (d['time'] ?? '00:00').split(':');
                                                        int appStart = (int.tryParse(timeParts[0]) ?? 0) * 60 + (int.tryParse(timeParts[1]) ?? 0);
                                                        int duration = d['duration'] ?? 30;
                                                        int appEnd = appStart + duration;

                                                        if (currentMinutes >= appStart && currentMinutes < appEnd) {
                                                          isAlreadyBooked = true;
                                                          isStartOfBooking = (currentMinutes == appStart);
                                                          isEndOfBooking = (currentMinutes + 15 == appEnd);
                                                          break;
                                                        }
                                                      }

                                                      bool shouldBlock = isSlotClosed || isAlreadyBooked || isPastSlot;
                                                      bool drawBottomBorder = !isAlreadyBooked || isEndOfBooking;

                                                      Color? slotColor = isAlreadyBooked ? Colors.red[50] : ((isSlotClosed || isPastSlot) ? Colors.grey[200]! : Colors.white);

                                                      return Container(
                                                        height: 55,
                                                        decoration: BoxDecoration(
                                                          color: slotColor,
                                                          border: Border(left: BorderSide(color: Colors.grey[200]!, width: 0.5), bottom: drawBottomBorder ? BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.grey[200]!, width: isFullHour ? 0.8 : 0.5) : BorderSide.none),
                                                        ),
                                                        child: InkWell(
                                                          onTap: shouldBlock ? null : () {
                                                            setState(() {
                                                              _selectedEmployeeId = empId;
                                                              _selectedEmployeeName = firstName;
                                                              _selectedTime = formattedTime;
                                                              _currentStep = 3;
                                                            });
                                                          },
                                                          child: isAlreadyBooked
                                                              ? Center(child: isStartOfBooking ? const Text('Zajęte', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)) : const SizedBox.shrink())
                                                              : ((isSlotClosed || isPastSlot) && isFullHour ? const Center(child: Icon(Icons.lock_outline, size: 14, color: Colors.black26)) : const SizedBox.expand()),
                                                        ),
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
    );
  }

  Widget _buildStep3ServicesList(String clientUid, String clientName) {
    if (_selectedEmployeeId == null || _selectedSalonId == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.pinkAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Wybrany termin:\n${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year} r. godz. $_selectedTime',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Wybierz zabieg, aby potwierdzić rezerwację:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .where('salonId', isEqualTo: _selectedSalonId)
                  .where('employeeId', isEqualTo: _selectedEmployeeId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                // 🚀 Zabezpieczenie przed pokazaniem archiwalnych usług klientce
                final validServices = snapshot.hasData ? snapshot.data!.docs.where((doc) {
                  final bool isArch = (doc.data() as Map<String, dynamic>)['archived'] ?? false;
                  return !isArch;
                }).toList() : [];

                if (validServices.isEmpty) {
                  return const Center(child: Text('Ta pracownica nie ma przypisanych usług w cenniku.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: validServices.length,
                  itemBuilder: (context, index) {
                    final doc = validServices[index];
                    final service = doc.data() as Map<String, dynamic>;
                    final String serviceName = service['name'] ?? 'Zabieg';
                    final double price = (service['price'] as num?)?.toDouble() ?? 0.0;
                    final int duration = service['duration'] ?? 30;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Czas trwania: $duration min', style: const TextStyle(color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${price.toStringAsFixed(2)} zł', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                        onTap: () => _confirmAppointment(clientUid, clientName, serviceName, price, duration),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAppointment(String clientUid, String clientName, String sName, double sPrice, int sDuration) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
    );

    try {
      final String formattedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      List<String> newTimeParts = _selectedTime!.split(':');
      int newStartMin = (int.tryParse(newTimeParts[0]) ?? 0) * 60 + (int.tryParse(newTimeParts[1]) ?? 0);
      int newEndMin = newStartMin + sDuration;

      final salonDoc = await FirebaseFirestore.instance.collection('salons').doc(_selectedSalonId).get();
      if (salonDoc.exists) {
        final salonData = salonDoc.data() as Map<String, dynamic>;
        final openingHours = salonData['openingHours'] ?? {};
        final daysMapping = {1: '1_pon', 2: '2_wt', 3: '3_sr', 4: '4_czw', 5: '5_pt', 6: '6_sob', 7: '7_nd'};
        String currentDayKey = daysMapping[_selectedDate.weekday] ?? '1_pon';
        Map<String, dynamic> dayConfig = openingHours[currentDayKey] ?? {};

        bool isClosed = dayConfig['1_closed'] ?? false;
        if (!isClosed) {
          List<String> closeParts = (dayConfig['3_close'] ?? '16:00').split(':');
          int closeInMinutes = (int.tryParse(closeParts[0]) ?? 16) * 60 + (int.tryParse(closeParts[1]) ?? 0);

          if (newEndMin > closeInMinutes) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zabieg jest za długi i skończyłby się po godzinach otwarcia salonu! Wybierz inną godzinę.'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
            }
            return;
          }
        }
      }

      final existingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('salonId', isEqualTo: _selectedSalonId)
          .where('employeeId', isEqualTo: _selectedEmployeeId)
          .where('date', isEqualTo: formattedDateStr)
          .get();

      bool hasOverlap = false;
      for (var doc in existingAppointments.docs) {
        final data = doc.data();

        // 🚀 POMIJAMY ARCHIWALNE WIZYTY PRZY SPRAWDZANIU NAKŁADANIA SIĘ!
        final bool isArchived = data['archived'] ?? false;
        if (isArchived) continue;

        List<String> appTimeParts = (data['time'] ?? '00:00').split(':');
        int appStartMin = (int.tryParse(appTimeParts[0]) ?? 0) * 60 + (int.tryParse(appTimeParts[1]) ?? 0);
        int appDuration = data['duration'] ?? 30;
        int appEndMin = appStartMin + appDuration;

        if (newStartMin < appEndMin && newEndMin > appStartMin) {
          hasOverlap = true;
          break;
        }
      }

      if (hasOverlap) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Niestety, wybrany zabieg jest za długi na to "okienko" czasowe i nakłada się na inną wizytę. Wybierz inną godzinę!'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
        }
        return;
      }

      await FirebaseFirestore.instance.collection('appointments').add({
        'salonId': _selectedSalonId,
        'salonName': _selectedSalonName,
        'clientId': clientUid,
        'clientName': clientName,
        'employeeId': _selectedEmployeeId,
        'employeeName': _selectedEmployeeName,
        'date': formattedDateStr,
        'time': _selectedTime,
        'serviceName': sName,
        'price': sPrice,
        'duration': sDuration,
        'createdAt': FieldValue.serverTimestamp(),
        'isRated': false,
        'rating': 0,
        'review': '',
        'archived': false, // 🚀 FLAGA ARCHIWIZACJI: false (Gwarancja widoczności)
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rezerwacja udana! Zapisano Cię na $sName.'), backgroundColor: Colors.green));
        setState(() {
          _currentStep = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }
}