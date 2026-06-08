import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';

class EyeMatchScreen extends StatefulWidget {
  const EyeMatchScreen({super.key});

  @override
  State<EyeMatchScreen> createState() => _EyeMatchScreenState();
}

class _EyeMatchScreenState extends State<EyeMatchScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 1; // Domyślnie kamera przednia (selfie)

  late FaceDetector _faceDetector;
  bool _isProcessingImage = false;
  List<Face> _detectedFaces = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      if (_selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }

      // --- 🚀 POPRAWKA 2: PODBICIE JAKOŚCI NA HIGH DLA OSTRZEJSZEGO OBRAZU ---
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.veryHigh, // Zapewnia doskonały balans ostrości i wydajności AI
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      _cameraController!.startImageStream((CameraImage image) {
        _processCameraImage(image);
      });

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Błąd inicjalizacji kamery: $e");
    }
  }

  // --- 🛠️ POPRAWKA 1: BEZPIECZNE PRZEŁĄCZANIE BEZ CZERWONYCH EKRANÓW ---
  void _toggleCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = _selectedCameraIndex == 1 ? 0 : 1;

    if (_cameraController != null) {
      // 1. Zatrzymujemy stream klatek
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint("Stream już zatrzymany lub nieaktywny");
      }

      // 2. Kopia lokalna do zniszczenia w tle
      final oldController = _cameraController;

      // 3. NATYCHMIAST ustawiamy zmienną na null i czyścimy stan detekcji,
      // dzięki czemu metoda build() przestanie renderować stary podgląd.
      setState(() {
        _cameraController = null;
        _detectedFaces = [];
        _imageSize = null;
      });

      // 4. Usuwamy stary kontroler z pamięci RAM
      await oldController?.dispose();
    }

    // 5. Wstaje nowa kamera
    _initializeCamera();
  }

  void _processCameraImage(CameraImage image) async {
    // Jeśli kontroler został wyzerowany (trwa przełączanie), przerywamy potok AI
    if (_cameraController == null || _isProcessingImage) return;
    _isProcessingImage = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameras[_selectedCameraIndex];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);

      // Dodatkowe sprawdzenie przed wywołaniem ciężkiego procesu detekcji
      if (_cameraController == null) return;
      final faces = await _faceDetector.processImage(inputImage);

      if (mounted && _cameraController != null) {
        setState(() {
          _detectedFaces = faces;
          _imageSize = imageSize;
        });
      }
    } catch (e) {
      debugPrint("Błąd przetwarzania obrazu: $e");
    } finally {
      _isProcessingImage = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- 🛠️ ZABEZPIECZENIE RENDERERA: Jeśli kontroler jest null lub się ładuje, pokazujemy loader ---
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. PODGLĄD KAMERY
          CameraPreview(_cameraController!),

          // 2. SZKICOWNIK PKT ORAZ LINII OCZU
          if (_imageSize != null && _detectedFaces.isNotEmpty)
            CustomPaint(
              painter: FaceDetectorPainter(
                _detectedFaces,
                _imageSize!,
                _cameraController!.value.aspectRatio,
                _cameras[_selectedCameraIndex].lensDirection,
              ),
            ),

          // 3. INTERFEJS / PRZYCISKI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.pinkAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'EyeMatch AI',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 26),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: _toggleCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size absoluteImageSize;
  final double aspectRatio;
  final CameraLensDirection lensDirection;

  FaceDetectorPainter(this.faces, this.absoluteImageSize, this.aspectRatio, this.lensDirection);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.pinkAccent
      ..strokeWidth = 3.0;

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 1.5;

    // Przeliczanie skali z uwzględnieniem orientacji sensora (ML Kit podaje wymiary obrócone)
    final double scaleX = size.width / absoluteImageSize.height;
    final double scaleY = size.height / absoluteImageSize.width;

    for (final Face face in faces) {
      final leftEyeContour = face.contours[FaceContourType.leftEye];
      final rightEyeContour = face.contours[FaceContourType.rightEye];

      void drawEye(FaceContour? contour) {
        if (contour == null) return;

        List<Offset> transformedPoints = [];
        for (final point in contour.points) {
          double x = point.x.toDouble() * scaleX;
          double y = point.y.toDouble() * scaleY;

          if (lensDirection == CameraLensDirection.front) {
            x = size.width - x;
          }

          transformedPoints.add(Offset(x, y));
        }

        for (int i = 0; i < transformedPoints.length; i++) {
          final currentPoint = transformedPoints[i];
          final nextPoint = transformedPoints[(i + 1) % transformedPoints.length];
          canvas.drawLine(currentPoint, nextPoint, linePaint);
          canvas.drawCircle(currentPoint, 2.5, pointPaint);
        }
      }

      drawEye(leftEyeContour);
      drawEye(rightEyeContour);
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}