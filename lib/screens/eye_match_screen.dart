import 'dart:io';
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
  // 5 - Ekran końcowy / Podsumowanie

  XFile? _frontPhotoFile;
  XFile? _sidePhotoFile;

  List<Face> _frontDetectedFaces = [];
  List<Face> _sideDetectedFaces = [];

  Size? _frontImageSize;
  Size? _sideImageSize;

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

  void _toggleCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = _selectedCameraIndex == 1 ? 0 : 1;
    _disposeCamera();
    _initializeCamera();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      // 1. Wykonanie ostrego zdjęcia
      final XFile photo = await _cameraController!.takePicture();

      // 2. Dekodowanie wymiarów pliku graficznego
      final File imageFile = File(photo.path);
      final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
      final Size photoSize = Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

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

      _disposeCamera();
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
    setState(() {
      _currentStep = 5;
    });
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photo.path),
            fit: BoxFit.cover,
          ),

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
      return _buildPhotoResultView(_sidePhotoFile!, _sideDetectedFaces, _sideImageSize, _goToStep5, 'Zobacz podsumowanie');
    }

    if (_currentStep == 5) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analiza EyeMatch AI'), backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, automaticallyImplyLeading: false),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text('Analiza ukończona!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Zapisaliśmy geometrię oka z frontu i profilu.\nW tym miejscu w kolejnym etapie wejdzie algorytm dopasowujący długość, skręt i układ rzęs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _resetWizard,
                icon: const Icon(Icons.refresh),
                label: const Text('Rozpocznij analizę od nowa'),
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
}

// =========================================================================
// PAINTER: LOGIKA JEOMETRYCZNEGO DOPASOWANIA I MAPOWANIA NA FOTOGRAFII
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

    // --- 📐 MATEMATYCZNE OBLICZENIA PROPORCJI BOXFIT.COVER ---
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
          // 1. Skalowanie z układu współrzędnych zdjęcia do skali ekranu
          double dx = point.x.toDouble() * finalScale;
          double dy = point.y.toDouble() * finalScale;

          // 2. Korekta przesunięcia wycentrowania obrazu (offset)
          dx += offsetX;
          dy += offsetY;

          // 3. 🔄 UKŁAD LUSTRZANY (MIRRORING FIX DLA APARATÓW SELFIE)
          if (isFrontCamera && Platform.isAndroid) {
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