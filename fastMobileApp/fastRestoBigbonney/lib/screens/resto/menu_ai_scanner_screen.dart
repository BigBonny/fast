import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../../resto_provider.dart';
import '../../services/restaurant_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';

class MenuAiScannerScreen extends StatefulWidget {
  const MenuAiScannerScreen({super.key});

  @override
  State<MenuAiScannerScreen> createState() => _MenuAiScannerScreenState();
}

class _MenuAiScannerScreenState extends State<MenuAiScannerScreen> {
  int _state = 0; // 0: Idle/Frame, 1: Scanning, 2: Success, -1: Error, 3: Recording
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Timer? _recordTimer;
  int _recordElapsed = 0;
  static const _maxRecordSeconds = 8;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[Scanner] No cameras found.');
        return;
      }

      // Initialize the back camera
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[Scanner] Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── Video menu scan ─────────────────────────────────────────
  // Records up to 8s panning across the menu screens, samples frames,
  // and sends them all in one request — the backend merges results.

  // Snapchat-style shutter: tap = photo, press-and-hold = video.
  // Releasing the finger stops the recording automatically.
  Future<void> _startVideoRecording() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isRecording) {
      return;
    }
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _state = 3;
        _recordElapsed = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordElapsed++);
        if (_recordElapsed >= _maxRecordSeconds) {
          _stopVideoAndProcess();
        }
      });
    } catch (e) {
      debugPrint('[Scanner] Video start error: $e');
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_isRecording) {
      await _stopVideoAndProcess();
      return;
    }
    await _startVideoRecording();
  }

  bool get _isRecording => _state == 3;

  Future<void> _stopVideoAndProcess() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      final video = await _cameraController!.stopVideoRecording();
      if (!mounted) return;
      setState(() => _state = 1);
      await _processVideo(video);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur vidéo: $e';
        });
      }
    }
  }

  Future<void> _processVideo(XFile video) async {
    final restoProvider = Provider.of<RestoProvider>(context, listen: false);
    final restaurantId = restoProvider.restaurantId;
    if (restaurantId == null) {
      setState(() {
        _state = -1;
        _errorMessage = 'Aucun restaurant connecté.';
      });
      return;
    }

    try {
      // Sample frames across the clip — pans across menu boards/screens
      // mean each frame catches different dishes.
      final frames = <String>[];
      for (final ms in [400, 1600, 3000, 4500, 6000, 7400]) {
        final bytes = await vt.VideoThumbnail.thumbnailData(
          video: video.path,
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: ms,
          quality: 80,
          maxWidth: 1280,
        );
        if (bytes != null && bytes.isNotEmpty) {
          frames.add(base64Encode(bytes));
        }
      }
      if (frames.isEmpty) {
        throw Exception('Impossible d\'extraire les images de la vidéo');
      }
      debugPrint('[Scanner] extracted ${frames.length} frames');

      final service = RestaurantService();
      await service.scanMenuFrames(restaurantId, frames);

      await restoProvider.loadMenu();
      if (!mounted) return;
      setState(() => _state = 2);
      Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'analyse: $e';
        });
      }
    }
  }

  Future<void> _takeInAppPicture() async {
    debugPrint('[Scanner] _takeInAppPicture called');
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint(
        '[Scanner] Camera not ready: controller is ${_cameraController == null ? "null" : "not initialized"}',
      );
      return;
    }

    try {
      setState(() => _state = 1);

      final XFile file = await _cameraController!.takePicture();
      debugPrint('[Scanner] In-app photo taken: ${file.path}');

      await _processImage(file);
    } catch (e) {
      debugPrint('[Scanner] Error taking picture: $e');
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'import: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _captureAndScan(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (file == null) return; // User cancelled

      setState(() => _state = 1);

      await _processImage(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'import: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    if (!mounted) return;

    final restoProvider = Provider.of<RestoProvider>(context, listen: false);
    final restaurantId = restoProvider.restaurantId;

    if (restaurantId == null) {
      setState(() {
        _state = -1;
        _errorMessage = 'Aucun restaurant connecté.';
      });
      return;
    }

    try {
      // Read image bytes and encode as base64
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      final service = RestaurantService();
      await service.scanMenu(restaurantId, imageBase64);

      // Refresh menu in provider
      await restoProvider.loadMenu();

      if (!mounted) return;
      setState(() => _state = 2);

      Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = -1;
          _errorMessage = 'Erreur lors de l\'analyse: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.fast.t1),
        title: Text(
          'Assistant IA FAST',
          style: TextStyle(color: context.fast.t1, fontWeight: FontWeight.bold),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Live Camera Preview as the background (also while recording)
          if (_state == 0 || _state == 3)
            Positioned.fill(
              child: _isCameraInitialized && _cameraController != null
                  ? ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height,
                            height: _cameraController!.value.previewSize!.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    )
                  : Container(color: context.fast.bg),
            ),

          // Viewfinder darkened overlay with a clear center cutout
          if (_state == 0)
            Positioned.fill(child: CustomPaint(painter: ViewfinderPainter())),

          // Green Finder cadre box and guidelines
          if (_state == 0)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 360,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Corner highlights
                        _scannerCorner(top: 0, left: 0),
                        _scannerCorner(top: 0, right: 0),
                        _scannerCorner(bottom: 0, left: 0),
                        _scannerCorner(bottom: 0, right: 0),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Cadrez le menu\npapier ou l\'ardoise\npour l\'importation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                        SizedBox(height: 40), Text(
                    'Photo nette, ou maintenez pour filmer',
                    style: TextStyle(
                      color: context.fast.t1,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      shadows: [ Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4,
                          color: Color(0x80000000),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Control buttons at the bottom
          if (_state == 0)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery picker button
 IconButton(
                    onPressed: () => _captureAndScan(ImageSource.gallery),
                    icon: Icon( Icons.photo_library_outlined,
                      color: context.fast.t1,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Capture button in the absolute center — Snapchat style:
                  // tap = photo, press & hold = video (release to stop).
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _takeInAppPicture,
                        onLongPressStart: (_) => _startVideoRecording(),
                        onLongPressEnd: (_) => _stopVideoAndProcess(),
                        onLongPressCancel: () {
                          if (_isRecording) _stopVideoAndProcess();
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.fast.line,
                              width: 6,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              color: Color(0xFF17171B),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'APPUYEZ = PHOTO · MAINTENEZ = VIDÉO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Spacing balance (matches the gallery button width)
                  const SizedBox(width: 48),
                ],
              ),
            ),

          // Recording overlay — red REC + elapsed + stop button
          if (_state == 3) ...[
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'REC ${(_recordElapsed ~/ 60).toString().padLeft(2, '0')}:${(_recordElapsed % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 130,
              left: 24,
              right: 24,
              child: Text(
                'Balayez lentement les écrans / ardoises du menu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: InkWell(
                  onTap: _toggleVideoRecording,
                  borderRadius: BorderRadius.circular(38),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                    ),
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (_state == 1)
                  Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 24), Text(
                    'L\'IA analyse votre menu...',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8), Text(
                    'Extraction des plats et des prix en cours',
                    style: TextStyle(color: context.fast.t2),
                  ),
                ],
              ),
            ),

          if (_state == 2)
                  Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Icon(Icons.check_circle, color: Color(0xFF10B981), size: 80),
                  SizedBox(height: 24), Text(
                    'Menu importé avec succès !',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (_state == -1)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ Icon( Icons.error_outline,
                    color: Color(0xFFEF4444),
                    size: 80,
                  ),
                        SizedBox(height: 24), Text(
                    'Erreur d\'import',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                        SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.fast.t2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                        SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _state = 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00C8B3),
                      foregroundColor: FASTBrand.onAmber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(tr(context, 'retry')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scannerCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top != null && left != null ? 8 : 0),
            topRight: Radius.circular(top != null && right != null ? 8 : 0),
            bottomLeft: Radius.circular(bottom != null && left != null ? 8 : 0),
            bottomRight: Radius.circular(
              bottom != null && right != null ? 8 : 0,
            ),
          ),
        ),
      ),
    );
  }
}

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    // Viewfinder dimensions
    const width = 260.0;
    const height = 360.0;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;

    final rect = Rect.fromLTWH(left, top, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Draw overlay with transparent cutout in the center
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rrect),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
