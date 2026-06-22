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
  // Zmienne nawigacji wewnętrznej (Kreator rezerwacji)
  int _currentStep = 1; // 1: Lista salonów, 2: Kalendarz, 3: Usługi

  // Dane wybrane w trakcie procesu
  String? _selectedCityId;
  String? _selectedSalonId;
  String? _selectedSalonName;
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedTime;

  // 🚀 DODANE: Kontrolery do synchronizacji przewijania nagłówka z siatką
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Synchronizacja przesuwania w poziomie (nagłówek podąża za siatką)
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

  // --- OBSŁUGA COFANIA (PRZYCISK SYSTEMOWY I STRZAŁKA) ---
  void _handleBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
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

        // Tytuły paska AppBar zależne od aktualnego kroku
        String appBarTitle = 'Znajdź Salon';
        if (_currentStep == 2) appBarTitle = _selectedSalonName ?? 'Wybierz termin';
        if (_currentStep == 3) appBarTitle = 'Wybierz usługę - $_selectedEmployeeName';

        return PopScope(
          canPop: _currentStep == 1, // Pozwól wyjść z ekranu tylko na kroku 1
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
                  : null, // Na kroku 1 standardowo pokaże się menu Drawer
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

  // =========================================================================
  // KROK 1: WYBÓR MIASTA I LISTA SALONÓW
  // =========================================================================
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
                                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                Text('Zespół: ${emps.length} os.', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSalonId = doc.id;
                                      _selectedSalonName = name;
                                      _currentStep = 2; // Przepychamy do kroku kalendarza
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

  // =========================================================================
  // KROK 2: DYNAMICZNY KALENDARZ Z PRZYKLEJONYM NAGŁÓWKIEM (STICKY HEADER)
  // =========================================================================
  Widget _buildStep2CalendarGrid() {
    if (_selectedSalonId == null) return const SizedBox();

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
            if (!appointmentsSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

            final List<QueryDocumentSnapshot> activeAppointments = appointmentsSnapshot.data!.docs;

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
                    // --- WYBIERAK DATY (Zawsze na górze) ---
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
                                // 🚀 1. STICKY HEADER: Wiersz z nazwiskami, przyklejony do góry
                                Row(
                                  children: [
                                    // Puste miejsce nad kolumną z czasem
                                    Container(
                                      width: 60,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                          right: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                        ),
                                      ),
                                    ),
                                    // Przewijana lista nazwisk pracowników
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _headerScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const NeverScrollableScrollPhysics(), // Scrolluje się automatycznie razem z siatką
                                        child: Row(
                                          children: employees.map((emp) {
                                            final eData = emp.data() as Map<String, dynamic>;
                                            final String firstName = eData['firstName'] ?? 'Stylistka';
                                            final String lastName = eData['lastName'] ?? '';

                                            return Container(
                                              width: columnWidth,
                                              height: 50,
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                border: Border(
                                                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                                                  left: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    firstName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent),
                                                  ),
                                                  if (lastName.isNotEmpty)
                                                    Text(
                                                      lastName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontWeight: FontWeight.w400, fontSize: 10, color: Colors.pinkAccent.withOpacity(0.8)),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 🚀 2. GŁÓWNA SIATKA (WIZYTY I GODZINY): Przewijana w dół
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Zamrożona kolumna z godzinami (Scrolluje się tylko góra-dół)
                                        SizedBox(
                                          width: 60,
                                          child: Column(
                                            children: List.generate(56, (index) {
                                              int currentMinutesFromDayStart = (7 * 60) + (index * 15);
                                              int hour = currentMinutesFromDayStart ~/ 60;
                                              int minute = currentMinutesFromDayStart % 60;
                                              String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                                              bool isSlotClosed = isDayClosed || currentMinutesFromDayStart < openInMinutes || currentMinutesFromDayStart >= closeInMinutes;
                                              bool isFullHour = minute == 0;

                                              return Container(
                                                width: 60,
                                                height: 55,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border(
                                                    right: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                                    bottom: BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.transparent, width: isFullHour ? 0.8 : 0.0),
                                                  ),
                                                ),
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Positioned(
                                                      left: 0,
                                                      right: 0,
                                                      top: -6,
                                                      child: Container(
                                                        alignment: Alignment.center,
                                                        child: Text(
                                                          formattedTime,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontWeight: isFullHour ? FontWeight.bold : FontWeight.w400,
                                                            color: isSlotClosed ? Colors.grey[400] : Colors.black87,
                                                            fontSize: 11,
                                                            height: 1.0,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ),
                                        ),

                                        // Przewijana siatka wizyt (Scrolluje się góra-dół oraz na boki)
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
                                                    children: List.generate(56, (index) {
                                                      int currentMinutes = (7 * 60) + (index * 15);
                                                      int hour = currentMinutes ~/ 60;
                                                      int minute = currentMinutes % 60;
                                                      String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                                                      bool isSlotClosed = isDayClosed || currentMinutes < openInMinutes || currentMinutes >= closeInMinutes;
                                                      bool isFullHour = minute == 0;

                                                      bool isAlreadyBooked = false;
                                                      bool isStartOfBooking = false;
                                                      bool isEndOfBooking = false;

                                                      for (var appDoc in activeAppointments) {
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

                                                      bool shouldBlock = isSlotClosed || isAlreadyBooked;
                                                      bool drawBottomBorder = !isAlreadyBooked || isEndOfBooking;

                                                      return Container(
                                                        height: 55,
                                                        decoration: BoxDecoration(
                                                          color: isAlreadyBooked
                                                              ? Colors.red[50]
                                                              : (isSlotClosed ? Colors.grey[200]! : Colors.white),
                                                          border: Border(
                                                            left: BorderSide(color: Colors.grey[200]!, width: 0.5),
                                                            bottom: drawBottomBorder
                                                                ? BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.grey[200]!, width: isFullHour ? 0.8 : 0.5)
                                                                : BorderSide.none,
                                                          ),
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
                                                              ? Center(
                                                            child: isStartOfBooking
                                                                ? const Text(
                                                              'Zajęte',
                                                              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                                            )
                                                                : const SizedBox.shrink(),
                                                          )
                                                              : (isSlotClosed && isFullHour
                                                              ? const Center(child: Icon(Icons.lock_outline, size: 14, color: Colors.black26))
                                                              : const SizedBox.expand()),
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

  // =========================================================================
  // KROK 3: WYBÓR USŁUGI I FINALIZACJA ZAPISU (FIRESTORE APPOINTMENTS)
  // =========================================================================
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Ta pracownica nie ma przypisanych usług w cenniku.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
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
              Navigator.pop(context); // Zamknij loader
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Zabieg jest za długi i skończyłby się po godzinach otwarcia salonu! Wybierz inną godzinę.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 4),
                ),
              );
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
          Navigator.pop(context); // Zamknij loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Niestety, wybrany zabieg jest za długi na to "okienko" czasowe i nakłada się na inną wizytę. Wybierz inną godzinę!'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
          );
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
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rezerwacja udana! Zapisano Cię na $sName.'), backgroundColor: Colors.green),
        );
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