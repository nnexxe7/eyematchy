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
                  Text('Wskaż miasto powyżej,\nababy wyświetlić dostępne salony.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
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
  // KROK 2: DYNAMICZNY KALENDARZ WIELOKOLUMNOWY Z WYSZARZANIEM
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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('salonId', isEqualTo: _selectedSalonId).snapshots(),
          builder: (context, empSnapshot) {
            if (!empSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
            final employees = empSnapshot.data!.docs;

            return Column(
              children: [
                // Suwak daty (Lokalny widżet skopiowany funkcjonalnie)
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

                // Lista imion stylistek
                if (employees.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1))),
                    child: Row(
                      children: [
                        const SizedBox(width: 60),
                        ...employees.map((emp) {
                          final eData = emp.data() as Map<String, dynamic>;
                          return Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[300]!, width: 0.5))),
                              child: Text(eData['firstName'] ?? 'Stylistka', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent), overflow: TextOverflow.ellipsis),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Siatka 15-minutowych slotów
                Expanded(
                  child: ListView.builder(
                    itemCount: 56,
                    itemBuilder: (context, index) {
                      int currentMinutes = (7 * 60) + (index * 15);
                      int hour = currentMinutes ~/ 60;
                      int minute = currentMinutes % 60;
                      String formattedTime = "$hour:${minute.toString().padLeft(2, '0')}";
                      bool isSlotClosed = isDayClosed || currentMinutes < openInMinutes || currentMinutes >= closeInMinutes;
                      bool isFullHour = minute == 0;

                      return Container(
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isFullHour ? Colors.grey[300]! : Colors.grey[200]!, width: isFullHour ? 0.8 : 0.5))),
                        child: Row(
                          children: [
                            Container(
                              width: 60, height: 50, alignment: Alignment.center,
                              color: isSlotClosed ? Colors.grey[200] : Colors.white,
                              child: Text(formattedTime, style: TextStyle(fontWeight: isFullHour ? FontWeight.bold : FontWeight.w400, color: isSlotClosed ? Colors.grey[400] : Colors.black87, fontSize: 12)),
                            ),
                            ...employees.map((emp) {
                              return Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(color: isSlotClosed ? Colors.grey[150] : Colors.white, border: Border(left: BorderSide(color: Colors.grey[200]!, width: 0.5))),
                                  child: InkWell(
                                    onTap: isSlotClosed
                                        ? null
                                        : () {
                                      final eData = emp.data() as Map<String, dynamic>;
                                      setState(() {
                                        _selectedEmployeeId = emp.id;
                                        _selectedEmployeeName = eData['firstName'] ?? 'Stylistka';
                                        _selectedTime = formattedTime;
                                        _currentStep = 3; // Przerzucamy do wyboru usługi
                                      });
                                    },
                                    child: isSlotClosed && isFullHour ? const Center(child: Icon(Icons.lock_outline, size: 14, color: Colors.black26)) : const SizedBox.expand(),
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
          // Podsumowanie wybranego terminu
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

  // OSTATECZNY ZAPIS WIZYTY DO BAZY FIRESTORE
  Future<void> _confirmAppointment(String clientUid, String clientName, String sName, double sPrice, int sDuration) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
    );

    try {
      final String formattedDateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      // Tworzymy dokument rezerwacji
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
        Navigator.pop(context); // Zamknij kręciołek ładowania

        // Wyświetlenie sukcesu i całkowity reset kreatora do kroku 1
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rezerwacja udana! Zapisaną Cię na $sName.'), backgroundColor: Colors.green),
        );
        setState(() {
          _currentStep = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu wizyty: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }
}