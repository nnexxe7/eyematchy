import 'dart:io';
import 'dart:math' as math;
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
  // 5 - Krótki wywiad uzupełniający
  // 6 - Podsumowanie 7 punktów AI

  XFile? _frontPhotoFile;
  XFile? _sidePhotoFile;

  List<Face> _frontDetectedFaces = [];
  List<Face> _sideDetectedFaces = [];

  Size? _frontImageSize;
  Size? _sideImageSize;

  EyeAnalysisResult? _analysisResult;

  // 🚀 ZMIENNE DO WYWIADU Z UŻYTKOWNIKIEM (Krok 5)
  String _surveyLashAnatomy = 'Proste / rosnące w dół';
  String _surveyEyelid = 'Normalna';
  String _surveyEyeSize = 'Normalne';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        performanceMode: FaceDetectorMode.accurate,
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
        ResolutionPreset.max,
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

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _isCameraInitializing) return;
    final oldController = _cameraController;

    setState(() => _cameraController = null);

    if (oldController != null) await oldController.dispose();

    _selectedCameraIndex = _selectedCameraIndex == 1 ? 0 : 1;
    await _initializeCamera();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      final File imageFile = File(photo.path);
      final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

      double imgW = decodedImage.width.toDouble();
      double imgH = decodedImage.height.toDouble();
      if (imgW > imgH) {
        final temp = imgW;
        imgW = imgH;
        imgH = temp;
      }
      final Size photoSize = Size(imgW, imgH);

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
          SnackBar(content: Text('Błąd zapisu zdjęcia: $e'), backgroundColor: Colors.redAccent)
      );
    }
  }

  void _goToStep3() {
    setState(() => _currentStep = 3);
    _initializeCamera();
  }

  void _goToStep5Survey() {
    setState(() => _currentStep = 5);
  }

  void _generateFinalReport() {
    if (_frontDetectedFaces.isNotEmpty && _sideDetectedFaces.isNotEmpty) {
      _runAIAnalysis();
    }
    setState(() => _currentStep = 6);
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
      surveyLashAnatomy: _surveyLashAnatomy,
      surveyEyelid: _surveyEyelid,
      surveyEyeSize: _surveyEyeSize,
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

  @override
  void dispose() {
    if (_cameraController != null) _cameraController!.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // =========================================================================
  // LOGIKA BUDOWANIA WIDOKÓW
  // =========================================================================

  Widget _buildSurveyStep() {
    return Scaffold(
      appBar: AppBar(title: const Text('Wywiad uzupełniający'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: Colors.pinkAccent),
            const SizedBox(height: 16),
            const Text('Ostatni krok!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Sztuczna inteligencja potrzebuje jeszcze 3 informacji, których nie widać na zdjęciach, aby wygenerować pełen raport.', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 32),

            const Text('1. Cechy anatomiczne rzęs naturalnych:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _surveyLashAnatomy,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Proste / rosnące w dół', 'Podkręcone'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _surveyLashAnatomy = val!),
            ),
            const SizedBox(height: 24),

            const Text('4. Stan górnej powieki:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _surveyEyelid,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Normalna', 'Opadająca na środku', 'Opadająca w zewn. kąciku', 'Opadająca po całości', 'W wewn. kąciku'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _surveyEyelid = val!),
            ),
            const SizedBox(height: 24),

            const Text('7. Rozmiar oka pacjentki:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _surveyEyeSize,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Małe', 'Normalne', 'Duże'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _surveyEyeSize = val!),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.memory),
                label: const Text('Generuj Raport EyeMatch AI', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: _generateFinalReport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalReport() {
    if (_analysisResult == null) {
      return const Center(child: Text("Błąd analizy."));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Wynik EyeMatch AI'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('7 Punktów Anatomii', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 12),

            // 🚀 RENDEROWANIE 7 PUNKTÓW
            ..._analysisResult!.points.map((point) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("Kształt / Diagnoza: ${point['value']}", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(8)),
                        child: Text("Rekomendacja: ${point['rec']}", style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            const Text('🏆 TOP 3 Pasujące Style', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const Text('Wyniki na podstawie głosowania algorytmu', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),

            // 🚀 RENDEROWANIE PODIUM TOP 3
            ..._analysisResult!.topStyles.asMap().entries.map((entry) {
              int rank = entry.key + 1;
              var styleData = entry.value;
              Color badgeColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey[400]! : Colors.brown[300]!);

              return Card(
                color: rank == 1 ? Colors.amber[50] : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: badgeColor, width: rank == 1 ? 2 : 1)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: badgeColor, child: Text(rank.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                  title: Text(styleData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text("Pasuje do ${styleData['votes']} cech Twojej anatomii.", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            }),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _resetWizard,
              icon: const Icon(Icons.refresh),
              label: const Text('Zeskanuj kolejną osobę'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zakończ i wyjdź', style: TextStyle(color: Colors.grey))
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🚀 ZBUDOWANY OD NOWA BEZPIECZNY OVERLAY KAMERY Z POPRAWIONYMI TEKSTAMI
  Widget _buildCameraOverlay(String title, String subtitle, bool isProfile) {
    final double w = isProfile ? 240.0 : 260.0;
    final double h = 340.0;

    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Center(
                  child: Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(
                          Radius.elliptical(w, h)
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.pinkAccent, width: 2.5),
                borderRadius: BorderRadius.all(
                    Radius.elliptical(w, h)
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center
                ),
                const SizedBox(height: 8),
                Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 WIDOK PO WYKONANIU ZDJĘCIA Z POPRAWIONYM KOMUNIKATEM BŁĘDU
  Widget _buildPhotoResultView(XFile photo, List<Face> faces, Size? originalPhotoSize, VoidCallback onNextPressed, String buttonText) {
    Widget imageWidget = Image.file(File(photo.path), fit: BoxFit.cover);

    if (_selectedCameraIndex == 1) {
      imageWidget = Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(math.pi),
          child: imageWidget
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (faces.isNotEmpty && originalPhotoSize != null)
            Positioned.fill(
                child: CustomPaint(
                    painter: StaticPhotoFacePainter(faces, originalPhotoSize, _selectedCameraIndex == 1)
                )
            ),
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Column(
              children: [
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      faces.isNotEmpty
                          ? '✅ Pomyślnie zmapowano punkty powiek'
                          : '⚠️ Nie wykryto twarzy. Obróć głowę trochę mniej (ok. 45 stopni).',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    )
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _resetWizard,
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            child: const Text('Powtórz')
                        )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: faces.isNotEmpty ? onNextPressed : null,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            child: Text(buttonText)
                        )
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
    if (_currentStep == 2 && _frontPhotoFile != null) return _buildPhotoResultView(_frontPhotoFile!, _frontDetectedFaces, _frontImageSize, _goToStep3, 'Dalej (Profil)');
    if (_currentStep == 4 && _sidePhotoFile != null) return _buildPhotoResultView(_sidePhotoFile!, _sideDetectedFaces, _sideImageSize, _goToStep5Survey, 'Uzupełnij wywiad');
    if (_currentStep == 5) return _buildSurveyStep();
    if (_currentStep == 6) return _buildFinalReport();

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));
    }

    bool isProfileStep = _currentStep == 3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),

          _buildCameraOverlay(
              isProfileStep ? 'Krok 2: Delikatny półprofil' : 'Krok 1: Zdjęcie z przodu',
              isProfileStep ? 'Obróć głowę o ok. 45°. Drugie oko musi być chociaż lekko widoczne!' : 'Ustaw całą twarz symetrycznie wewnątrz owalu',
              isProfileStep
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
                                onPressed: () => Navigator.pop(context)
                            ),
                            IconButton(
                                icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 26),
                                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                onPressed: _toggleCamera
                            )
                          ]
                      )
                  )
              )
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
                          child: Container(decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle))
                      )
                  )
              )
          ),
        ],
      ),
    );
  }
}

class StaticPhotoFacePainter extends CustomPainter {
  final List<Face> faces;
  final Size originalPhotoSize;
  final bool isFrontCamera;

  StaticPhotoFacePainter(this.faces, this.originalPhotoSize, this.isFrontCamera);

  @override void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()..style = PaintingStyle.fill..color = Colors.pinkAccent..strokeWidth = 3.0;
    final linePaint = Paint()..style = PaintingStyle.stroke..color = Colors.cyanAccent..strokeWidth = 1.5;

    double finalScale; double offsetX = 0; double offsetY = 0;

    if (size.width / size.height > originalPhotoSize.width / originalPhotoSize.height) {
      finalScale = size.width / originalPhotoSize.width;
      offsetY = (size.height - originalPhotoSize.height * finalScale) / 2;
    } else {
      finalScale = size.height / originalPhotoSize.height;
      offsetX = (size.width - originalPhotoSize.width * finalScale) / 2;
    }

    for (final face in faces) {
      void drawContour(FaceContour? contour) {
        if (contour == null) return;
        List<Offset> pts = [];
        for (final p in contour.points) {
          double dx = p.x.toDouble() * finalScale + offsetX;
          double dy = p.y.toDouble() * finalScale + offsetY;
          if (isFrontCamera) dx = size.width - dx;
          pts.add(Offset(dx, dy));
        }
        for (int i = 0; i < pts.length; i++) {
          canvas.drawLine(pts[i], pts[(i + 1) % pts.length], linePaint);
          canvas.drawCircle(pts[i], 3.0, pointPaint);
        }
      }
      drawContour(face.contours[FaceContourType.leftEye]);
      drawContour(face.contours[FaceContourType.rightEye]);
    }
  }

  @override bool shouldRepaint(StaticPhotoFacePainter old) => old.faces != faces;
}

// =========================================================================
// 🧠 EYE MATCH ANALYZER - ZAAWANSOWANA LOGIKA Z 7 PUNKTÓW
// =========================================================================
class EyeAnalysisResult {
  final List<Map<String, String>> points;
  final List<Map<String, dynamic>> topStyles;

  EyeAnalysisResult({required this.points, required this.topStyles});
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
    required String surveyLashAnatomy,
    required String surveyEyelid,
    required String surveyEyeSize,
  }) {
    List<Map<String, String>> points = [];
    Map<String, int> styleVotes = {'Lis': 0, 'Wiewiórka': 0, 'Okrągły': 0, 'Lalka': 0, 'Naturalny': 0};

    void vote(List<String> styles) {
      for (var s in styles) {
        styleVotes[s] = (styleVotes[s] ?? 0) + 1;
      }
    }

    // 1. CECHY RZĘS (Z wywiadu)
    String p1Rec = "Skręt C, CC";
    if (surveyLashAnatomy == 'Proste / rosnące w dół') {
      p1Rec = "Skręt D, DD, L";
    }
    points.add({"title": "1. Cechy anatomiczne rzęs", "value": surveyLashAnatomy, "rec": p1Rec});

    // 2. KSZTAŁT OKA (ML Kit Proporcje)
    double leftEyeWidth = (leftOuterCorner.dx - leftInnerCorner.dx).abs();
    double leftEyeHeight = (leftBottomPupil.dy - leftTopPupil.dy).abs();
    double opennessRatio = leftEyeWidth > 0 ? (leftEyeHeight / leftEyeWidth) : 0;

    String p2Value = "Migdałowe";
    String p2Rec = "Wiewiórka, Okrągły, 5-6mm w kącikach, Skręt C/CC";
    if (opennessRatio > 0.40) {
      p2Value = "Okrągłe"; p2Rec = "Lis, Naturalny, 9-10mm, Skręt B/C"; vote(['Lis', 'Naturalny']);
    } else if (opennessRatio < 0.28) {
      p2Value = "Wąskie"; p2Rec = "Wiewiórka, Okrągły, 5-6mm w kącikach, Skręt D"; vote(['Wiewiórka', 'Okrągły']);
    } else {
      vote(['Wiewiórka', 'Okrągły']);
    }
    points.add({"title": "2. Kształt oka", "value": p2Value, "rec": p2Rec});

    // 3. ZEWNĘTRZNY KĄCIK (ML Kit Kąt)
    double tiltDelta = leftOuterCorner.dy - leftInnerCorner.dy;
    String p3Value = "Normalny"; String p3Rec = "Brak specjalnych restrykcji";
    if (tiltDelta > 3.0) {
      p3Value = "Opadający (Smutne oko)"; p3Rec = "Wiewiórka, Okrągły, 5-6mm, Skręt CC/D"; vote(['Wiewiórka', 'Okrągły']);
    } else if (tiltDelta < -3.0) {
      p3Value = "Uniesiony (Kocie oko)"; p3Rec = "Lis, Naturalny, 9-10mm, Skręt B/C"; vote(['Lis', 'Naturalny']);
    }
    points.add({"title": "3. Rozmieszczenie zewn. kącika", "value": p3Value, "rec": p3Rec});

    // 4. GÓRNA POWIEKA (Z wywiadu)
    String p4Rec = "Brak specjalnych restrykcji";
    if (surveyEyelid != 'Normalna') {
      p4Rec = "Lalka, Naturalny, Długie rzęsy, Skręt CC/D"; vote(['Lalka', 'Naturalny', 'Okrągły']);
    }
    points.add({"title": "4. Górna powieka", "value": surveyEyelid, "rec": p4Rec});

    // 5. ROZSTAWIENIE OCZU (ML Kit Odległość)
    double interOcularDistance = (rightInnerCorner.dx - leftInnerCorner.dx).abs();
    String p5Value = "Normalne"; String p5Rec = "Brak restrykcji";
    if (leftEyeWidth > 0 && interOcularDistance > 0) {
      if (interOcularDistance < leftEyeWidth * 0.9) {
        p5Value = "Zbliżone (Wąski rozstaw)"; p5Rec = "Lis, Naturalny, 9-10mm, Skręt B/C"; vote(['Lis', 'Naturalny']);
      } else if (interOcularDistance > leftEyeWidth * 1.1) {
        p5Value = "Dalekie (Szeroki rozstaw)"; p5Rec = "Okrągły, Lalka, Wiewiórka, 5-6mm zewn., Skręt C/D"; vote(['Okrągły', 'Lalka', 'Wiewiórka']);
      }
    }
    points.add({"title": "5. Rozstawienie oczu", "value": p5Value, "rec": p5Rec});

    // 6. GŁĘBOKOŚĆ OSADZENIA (ML Kit Profil 3D)
    double browToCheekAverageX = (profileBrowRidge.dx + profileCheekbone.dx) / 2;
    double depthDelta = profileEyeCenter.dx - browToCheekAverageX;
    String p6Value = "Normalnie osadzone"; String p6Rec = "Skręt dopasowany do reszty";
    if (profileBrowRidge.dx > 0 && profileCheekbone.dx > 0) {
      if (depthDelta < -8.0) {
        p6Value = "Głęboko osadzone"; p6Rec = "Okrągły, Lalka, Długie, Skręt B/C (M/L)"; vote(['Okrągły', 'Lalka']);
      } else if (depthDelta > 8.0) {
        p6Value = "Wypukłe"; p6Rec = "Lis, Naturalny, 9-10mm, Skręt B/C"; vote(['Lis', 'Naturalny']);
      }
    }
    points.add({"title": "6. Głębokość osadzenia", "value": p6Value, "rec": p6Rec});

    // 7. ROZMIAR OKA (Z wywiadu)
    String p7Rec = "Dopasowanie do proporcji twarzy";
    if (surveyEyeSize == 'Małe') {
      p7Rec = "Lalka, Wiewiórka, Skręt C/CC"; vote(['Lalka', 'Wiewiórka']);
    } else if (surveyEyeSize == 'Duże') {
      p7Rec = "Lis, Naturalny, Skręt B/C"; vote(['Lis', 'Naturalny']);
    }
    points.add({"title": "7. Rozmiar oka", "value": surveyEyeSize, "rec": p7Rec});

    // --- KALKULACJA TOP 3 ---
    var sortedStyles = styleVotes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var top3 = sortedStyles.take(3).map((e) => {"name": e.key, "votes": e.value}).toList();

    return EyeAnalysisResult(points: points, topStyles: top3);
  }
}