import 'dart:io';
import 'dart:math' as math; // 🚀 DODANY IMPORT (wymagany do obrotu lustrzanego)
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class EyeMatchScreen extends StatefulWidget {
  const EyeMatchScreen({super.key});

  @override
  State<EyeMatchScreen> createState() => _EyeMatchScreenState();
}

class _EyeMatchScreenState extends State<EyeMatchScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 1; // Domyślnie przód (selfie)

  late FaceDetector _faceDetector;
  bool _isCameraInitializing = false;

  // --- 🧠 ZMIENNE OBSŁUGI KROKÓW KREATORA ---
  int _currentStep = 1;
  // 1 - Zdjęcie z przodu (Live)
  // 2 - Wynik z przodu (Podgląd foto + punkty)
  // 3 - Zdjęcie z boku (Live)
  // 4 - Wynik z boku (Podgląd foto + punkty)
  // 5 - Ekran końcowy / Podsumowanie AI

  XFile? _frontPhotoFile;
  XFile? _sidePhotoFile;

  List<Face> _frontDetectedFaces = [];
  List<Face> _sideDetectedFaces = [];

  Size? _frontImageSize;
  Size? _sideImageSize;

  EyeAnalysisResult? _analysisResult; // Przechowuje wynik diagnozy

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        performanceMode: FaceDetectorMode.accurate, // Precyzyjny pod analizę zdjęć
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitializing) return;
    setState(() => _isCameraInitializing = true);

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      if (_selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.max, // Pełna rozdzielczość sensora foto
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Błąd kamery: $e");
    } finally {
      if (mounted) setState(() => _isCameraInitializing = false);
    }
  }

  // 🚀 POPRAWIONA METODA - ZAPOBIEGA CZERWONEMU EKRANOWI
  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _isCameraInitializing) return;

    final oldController = _cameraController;

    // Natychmiast informujemy UI, że kamera jest niedostępna (pokazuje loader)
    setState(() {
      _cameraController = null;
    });

    // Bezpiecznie zamykamy starą kamerę w tle
    if (oldController != null) {
      await oldController.dispose();
    }

    _selectedCameraIndex = _selectedCameraIndex == 1 ? 0 : 1;
    await _initializeCamera();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      // 1. Wykonanie ostrego zdjęcia
      final XFile photo = await _cameraController!.takePicture();

      // 2. Dekodowanie wymiarów pliku graficznego
      final File imageFile = File(photo.path);
      final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

      // 🚀 ROZWIĄZANIE PROBLEMU Z PROPORCJAMI (EXIF BUG):
      // Aparaty w telefonach (nawet przy pionowym zdjęciu) zapisują na matrycy szerokość > wysokość.
      // Aby nasza maska ML Kit i BoxFit nakładały się poprawnie, wymuszamy tu orientację pionową.
      double imgW = decodedImage.width.toDouble();
      double imgH = decodedImage.height.toDouble();
      if (imgW > imgH) {
        final temp = imgW;
        imgW = imgH;
        imgH = temp;
      }
      final Size photoSize = Size(imgW, imgH);

      // 3. Detekcja rysów twarzy przez Google ML Kit
      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await _faceDetector.processImage(inputImage);

      setState(() {
        if (_currentStep == 1) {
          _frontPhotoFile = photo;
          _frontDetectedFaces = faces;
          _frontImageSize = photoSize;
          _currentStep = 2;
        } else if (_currentStep == 3) {
          _sidePhotoFile = photo;
          _sideDetectedFaces = faces;
          _sideImageSize = photoSize;
          _currentStep = 4;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu zdjęcia: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _goToStep3() {
    setState(() {
      _currentStep = 3;
    });
    _initializeCamera();
  }

  void _goToStep5() {
    if (_frontDetectedFaces.isNotEmpty && _sideDetectedFaces.isNotEmpty) {
      _runAIAnalysis();
    }
    setState(() {
      _currentStep = 5;
    });
  }

  void _runAIAnalysis() {
    final frontFace = _frontDetectedFaces.first;
    final sideFace = _sideDetectedFaces.first;

    Offset getMinX(FaceContour? c) => c == null || c.points.isEmpty ? const Offset(0,0) : Offset(c.points.map((p) => p.x).reduce(math.min).toDouble(), c.points.map((p) => p.y).reduce(math.min).toDouble());
    Offset getMaxX(FaceContour? c) => c == null || c.points.isEmpty ? const Offset(0,0) : Offset(c.points.map((p) => p.x).reduce(math.max).toDouble(), c.points.map((p) => p.y).reduce(math.min).toDouble());
    Offset getMinY(FaceContour? c) => c == null || c.points.isEmpty ? const Offset(0,0) : Offset(c.points.first.x.toDouble(), c.points.map((p) => p.y).reduce(math.min).toDouble());
    Offset getMaxY(FaceContour? c) => c == null || c.points.isEmpty ? const Offset(0,0) : Offset(c.points.first.x.toDouble(), c.points.map((p) => p.y).reduce(math.max).toDouble());
    Offset getCenter(FaceContour? c) {
      if (c == null || c.points.isEmpty) return const Offset(0,0);
      double sumX = c.points.fold(0, (sum, p) => sum + p.x);
      double sumY = c.points.fold(0, (sum, p) => sum + p.y);
      return Offset(sumX / c.points.length, sumY / c.points.length);
    }

    final leftEyeFront = frontFace.contours[FaceContourType.leftEye];
    final rightEyeFront = frontFace.contours[FaceContourType.rightEye];

    final profileBrow = sideFace.contours[FaceContourType.leftEyebrowTop] ?? sideFace.contours[FaceContourType.rightEyebrowTop];
    final profileEye = sideFace.contours[FaceContourType.leftEye] ?? sideFace.contours[FaceContourType.rightEye];
    final profileCheek = sideFace.contours[FaceContourType.leftCheek] ?? sideFace.contours[FaceContourType.rightCheek];

    _analysisResult = EyeMatchAnalyzer.analyze(
      leftInnerCorner: getMinX(leftEyeFront),
      leftOuterCorner: getMaxX(leftEyeFront),
      leftTopPupil: getMinY(leftEyeFront),
      leftBottomPupil: getMaxY(leftEyeFront),

      rightInnerCorner: getMaxX(rightEyeFront),
      rightOuterCorner: getMinX(rightEyeFront),

      profileBrowRidge: getCenter(profileBrow),
      profileEyeCenter: getCenter(profileEye),
      profileCheekbone: getCenter(profileCheek),
    );
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 1;
      _frontPhotoFile = null;
      _sidePhotoFile = null;
      _frontDetectedFaces = [];
      _sideDetectedFaces = [];
      _frontImageSize = null;
      _sideImageSize = null;
      _analysisResult = null;
    });
    _initializeCamera();
  }

  void _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    _faceDetector.close();
    super.dispose();
  }

  // =========================================================================
  // KOMPONENTY INTERFEJSU WIDOKU (UI WIDGETS)
  // =========================================================================

  Widget _buildCameraOverlay(String title, String subtitle, bool isProfile) {
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Center(
                  child: Container(
                    width: isProfile ? 240 : 260,
                    height: 340,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.elliptical(isProfile ? 240 : 260, 340)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: isProfile ? 240 : 260,
              height: 340,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.pinkAccent, width: 2.5),
                borderRadius: BorderRadius.all(Radius.elliptical(isProfile ? 240 : 260, 340)),
              ),
            ),
          ),
          Positioned(
            top: 100, left: 24, right: 24,
            child: Column(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoResultView(XFile photo, List<Face> faces, Size? originalPhotoSize, VoidCallback onNextPressed, String buttonText) {
    // 🚀 ROZWIĄZANIE LUSTRZANEGO ODBICIA
    // Zbudowanie fizycznego widżetu obrazka.
    Widget imageWidget = Image.file(
      File(photo.path),
      fit: BoxFit.cover,
    );

    // Jeśli używamy przedniej kamery (selfie), obracamy zdjęcie wizualnie (Transform)
    // żebyś widział na zdjęciu zrobionym dokładnie to samo, co widziałeś w podglądzie (lustro).
    if (_selectedCameraIndex == 1) {
      imageWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Renderuje obraz z nałożonym lustrem (jeśli to selfie)
          imageWidget,

          if (faces.isNotEmpty && originalPhotoSize != null)
            Positioned.fill(
              child: CustomPaint(
                painter: StaticPhotoFacePainter(
                    faces,
                    originalPhotoSize,
                    _selectedCameraIndex == 1
                ),
              ),
            ),

          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    faces.isNotEmpty ? '✅ Pomyślnie zmapowano punkty powiek' : '⚠️ Nie wykryto twarzy. Spróbuj ponownie',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetWizard,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Powtórz'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: faces.isNotEmpty ? onNextPressed : null,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text(buttonText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 2 && _frontPhotoFile != null) {
      return _buildPhotoResultView(_frontPhotoFile!, _frontDetectedFaces, _frontImageSize, _goToStep3, 'Dalej (Profil)');
    }

    if (_currentStep == 4 && _sidePhotoFile != null) {
      return _buildPhotoResultView(_sidePhotoFile!, _sideDetectedFaces, _sideImageSize, _goToStep5, 'Analizuj twarz');
    }

    if (_currentStep == 5) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wynik EyeMatch AI'), backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, automaticallyImplyLeading: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.auto_awesome, size: 64, color: Colors.pinkAccent),
              const SizedBox(height: 16),
              const Text('Diagnoza geometrii twarzy', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              if (_analysisResult != null) ...[
                Card(
                  elevation: 0,
                  color: Colors.grey[100],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildResultRow(Icons.remove_red_eye, "Kształt oka:", _analysisResult!.shape),
                        const Divider(),
                        _buildResultRow(Icons.compare_arrows, "Rozstaw:", _analysisResult!.spacing),
                        const Divider(),
                        _buildResultRow(Icons.rotate_right, "Kierunek (kąt):", _analysisResult!.tilt),
                        const Divider(),
                        _buildResultRow(Icons.line_weight, "Osadzenie:", _analysisResult!.depth),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Idealny dobór rzęs:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('STYLIZACJA', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(_analysisResult!.lashStyle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                              ],
                            ),
                            Container(width: 1, height: 40, color: Colors.grey[300]),
                            Column(
                              children: [
                                const Text('SKRĘT', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(_analysisResult!.lashCurl, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.pink.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                          child: Text(_analysisResult!.lashDescription, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87), textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Center(child: Text("Nie udało się przeprowadzić dokładnej analizy ze względu na niewyraźne rysy twarzy. Spróbuj ponownie.", textAlign: TextAlign.center)),
              ],

              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _resetWizard,
                icon: const Icon(Icons.refresh),
                label: const Text('Zrób nowe zdjęcia'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Wróć do menu głównego', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
      );
    }

    bool isProfileStep = _currentStep == 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),

          _buildCameraOverlay(
            isProfileStep ? 'Krok 2: Profil z boku' : 'Krok 1: Zdjęcie z przodu',
            isProfileStep ? 'Ustaw oko wewnątrz owalu obracając głowę o 90°' : 'Ustaw całą twarz symetrycznie wewnątrz owalu',
            isProfileStep,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 26),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: _toggleCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _captureAndAnalyze,
                child: Container(
                  width: 76, height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        ],
      ),
    );
  }
}

// =========================================================================
// PAINTER: LOGIKA GEOMETRYCZNEGO DOPASOWANIA I MAPOWANIA NA FOTOGRAFII
// =========================================================================
class StaticPhotoFacePainter extends CustomPainter {
  final List<Face> faces;
  final Size originalPhotoSize;
  final bool isFrontCamera;

  StaticPhotoFacePainter(this.faces, this.originalPhotoSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.pinkAccent
      ..strokeWidth = 3.0;

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.5;

    final double screenAspectRatio = size.width / size.height;
    final double photoAspectRatio = originalPhotoSize.width / originalPhotoSize.height;

    double finalScale;
    double offsetX = 0;
    double offsetY = 0;

    if (screenAspectRatio > photoAspectRatio) {
      finalScale = size.width / originalPhotoSize.width;
      offsetY = (size.height - originalPhotoSize.height * finalScale) / 2;
    } else {
      finalScale = size.height / originalPhotoSize.height;
      offsetX = (size.width - originalPhotoSize.width * finalScale) / 2;
    }

    for (final Face face in faces) {
      final leftEyeContour = face.contours[FaceContourType.leftEye];
      final rightEyeContour = face.contours[FaceContourType.rightEye];

      void drawContour(FaceContour? contour) {
        if (contour == null) return;

        List<Offset> transformedPoints = [];
        for (final point in contour.points) {
          double dx = point.x.toDouble() * finalScale;
          double dy = point.y.toDouble() * finalScale;

          dx += offsetX;
          dy += offsetY;

          // 🚀 Ponieważ obróciliśmy wyżej zdjęcie w kontenerze Image (żeby było jak lustro),
          // tutaj też lustrzanie musimy odwrócić współrzędną X dla punktów maski, żeby nałożyły się idealnie w punkt!
          if (isFrontCamera) {
            dx = size.width - dx;
          }

          transformedPoints.add(Offset(dx, dy));
        }

        for (int i = 0; i < transformedPoints.length; i++) {
          final current = transformedPoints[i];
          final next = transformedPoints[(i + 1) % transformedPoints.length];
          canvas.drawLine(current, next, linePaint);
          canvas.drawCircle(current, 3.0, pointPaint);
        }
      }

      drawContour(leftEyeContour);
      drawContour(rightEyeContour);
    }
  }

  @override
  bool shouldRepaint(StaticPhotoFacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}

// =========================================================================
// EYE MATCH ANALYZER - MODEL DANYCH I LOGIKA ALGORYTMU
// =========================================================================
class EyeAnalysisResult {
  final String spacing;
  final String tilt;
  final String shape;
  final String depth;
  final String lashStyle;
  final String lashCurl;
  final String lashDescription;

  EyeAnalysisResult({
    required this.spacing,
    required this.tilt,
    required this.shape,
    required this.depth,
    required this.lashStyle,
    required this.lashCurl,
    required this.lashDescription,
  });
}

class EyeMatchAnalyzer {
  static EyeAnalysisResult analyze({
    required Offset leftInnerCorner,
    required Offset leftOuterCorner,
    required Offset leftTopPupil,
    required Offset leftBottomPupil,
    required Offset rightInnerCorner,
    required Offset rightOuterCorner,
    required Offset profileBrowRidge,
    required Offset profileEyeCenter,
    required Offset profileCheekbone,
  }) {

    double leftEyeWidth = (leftOuterCorner.dx - leftInnerCorner.dx).abs();
    double interOcularDistance = (rightInnerCorner.dx - leftInnerCorner.dx).abs();

    String spacingResult = "Proporcjonalne";
    if (leftEyeWidth > 0 && interOcularDistance > 0) {
      if (interOcularDistance < leftEyeWidth * 0.9) {
        spacingResult = "Blisko osadzone";
      } else if (interOcularDistance > leftEyeWidth * 1.1) {
        spacingResult = "Szeroko rozstawione";
      }
    }

    double tiltDelta = leftOuterCorner.dy - leftInnerCorner.dy;

    String tiltResult = "Klasyczne";
    if (tiltDelta > 3.0) {
      tiltResult = "Opadające (Smutne)";
    } else if (tiltDelta < -3.0) {
      tiltResult = "Uniesione (Kocie)";
    }

    double leftEyeHeight = (leftBottomPupil.dy - leftTopPupil.dy).abs();
    double opennessRatio = leftEyeWidth > 0 ? (leftEyeHeight / leftEyeWidth) : 0;

    String shapeResult = "Migdałowe";
    if (opennessRatio > 0.38) {
      shapeResult = "Okrągłe";
    }

    double browToCheekAverageX = (profileBrowRidge.dx + profileCheekbone.dx) / 2;
    double depthDelta = profileEyeCenter.dx - browToCheekAverageX;

    String depthResult = "Normalnie osadzone";
    if (profileBrowRidge.dx > 0 && profileCheekbone.dx > 0) {
      if (depthDelta < -8.0) {
        depthResult = "Głęboko osadzone";
      } else if (depthDelta > 8.0) {
        depthResult = "Wypukłe / Płytkie";
      }
    }

    String recommendedStyle = "Naturalny Accent";
    String recommendedCurl = "C";
    String description = "Klasyczna stylizacja podkreślająca naturalną anatomię oka.";

    if (shapeResult == "Okrągłe") {
      recommendedStyle = "Kocie Oko (Cat Eye)";
      recommendedCurl = "C przechodzące w B";
      description = "Wydłużamy oko optycznie na zewnątrz, stosując krótsze rzęsy w centrum i dłuższe w kąciku zewnętrznym, aby zniwelować okrągły kształt.";
    }

    if (tiltResult == "Opadające (Smutne)") {
      recommendedStyle = "Wiewiórka (Squirrel)";
      recommendedCurl = "D / CC";
      description = "Mocny lifting kącika zewnętrznego! Najdłuższy punkt aplikacji znajduje się tuż przed końcem oka. Na samym brzegu drastycznie skracamy rzęsy i podbijamy skręt do D.";
    }

    if (spacingResult == "Blisko osadzone" && shapeResult != "Okrągłe") {
      recommendedStyle = "Lisi (Fox Eye)";
      recommendedCurl = "C / M";
      description = "Skupiamy gęstość i długość na zewnętrznej krawędzi, aby optycznie odsunąć oczy od siebie.";
    }

    if (spacingResult == "Szeroko rozstawione") {
      recommendedStyle = "Lalka (Doll Eye)";
      recommendedCurl = "C / D";
      description = "Najdłuższe rzęsy aplikujemy w centralnej części oka (nad źrenicą), aby optycznie przybliżyć oczy do siebie i otworzyć spojrzenie.";
    }

    if (depthResult == "Głęboko osadzone") {
      recommendedCurl = "L / M";
      description += " Użyto skrętu L/M, który ma prostą nasadę i ostry kąt, dzięki czemu rzęsy wychodzą poza linię mocnego łuku brwiowego.";
    } else if (depthResult == "Wypukłe / Płytkie") {
      recommendedCurl = "B / C";
      description += " Zastosowano łagodniejszy skręt i krótsze długości, aby nie przerysować naturalnie dużego oka.";
    }

    return EyeAnalysisResult(
      spacing: spacingResult,
      tilt: tiltResult,
      shape: shapeResult,
      depth: depthResult,
      lashStyle: recommendedStyle,
      lashCurl: recommendedCurl,
      lashDescription: description,
    );
  }
}