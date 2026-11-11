import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import '../../api/api_exceptions.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../../resto_provider.dart';
import '../../services/restaurant_service.dart';
import '../../theme.dart';
import '../../widgets/fast_night_surface.dart';
import '../../widgets/fast_ui.dart';
import '../../l10n/tr.dart';

class MenuAiScannerScreen extends StatefulWidget {
  const MenuAiScannerScreen({super.key});

  @override
  State<MenuAiScannerScreen> createState() => _MenuAiScannerScreenState();
}

class _MenuAiScannerScreenState extends State<MenuAiScannerScreen> {
  int _state =
      0; // 0: Idle/Frame, 1: Scanning, 2: Success, -1: Error, 3: Recording
  String _errorMessage = '';
  final ImagePicker _picker = ImagePicker();

  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Timer? _recordTimer;
  int _recordElapsed = 0;
  static const _maxRecordSeconds = 8;
  static const _maxPayloadCharacters = 3600000;
  final _recordWatch = Stopwatch();
  bool _startingRecording = false;
  bool _stoppingRecording = false;
  bool _stopRequested = false;
  bool _initializing = false;
  bool _cameraPermissionDenied = false;
  Timer? _returnTimer;

  void _fail(Object error, {bool camera = false}) {
    debugPrint('[Scanner] fail: $error');
    if (!mounted) return;
    final denied = error is CameraException && error.code.contains('Denied');
    final message = error is ApiException
        ? error.message
        : tr(
            context,
            denied
                ? 'camera_permission_hint'
                : camera
                ? 'camera_unavailable'
                : 'scan_failed',
          );
    setState(() {
      _state = -1;
      _cameraPermissionDenied = denied;
      _errorMessage = message;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    setState(() {
      _state = 0;
      _cameraPermissionDenied = false;
      _isCameraInitialized = false;
    });
    try {
      await _cameraController?.dispose();
      _cameraController = null;
      if (!mounted) return;
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[Scanner] No cameras found.');
        throw CameraException('CameraUnavailable', 'No camera');
      }

      // Initialize the back camera
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize().timeout(
        const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[Scanner] Camera initialization error: $e');
      _fail(e, camera: true);
    } finally {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _returnTimer?.cancel();
    _recordWatch.stop();
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
        _isRecording ||
        _startingRecording ||
        _stoppingRecording ||
        _state != 0) {
      return;
    }
    _startingRecording = true;
    _stopRequested = false;
    try {
      await _cameraController!.startVideoRecording();
      if (!mounted) return;
      _recordWatch
        ..reset()
        ..start();
      setState(() {
        _state = 3;
        _recordElapsed = 0;
      });
      if (_stopRequested) {
        await _stopVideoAndProcess();
        return;
      }
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recordElapsed++);
        if (_recordElapsed >= _maxRecordSeconds) {
          _stopVideoAndProcess();
        }
      });
    } catch (e) {
      debugPrint('[Scanner] Video start error: $e');
      _fail(e, camera: true);
    } finally {
      _startingRecording = false;
    }
  }

  bool get _isRecording => _state == 3;

  Future<void> _stopVideoAndProcess() async {
    if (_startingRecording && !_isRecording) {
      _stopRequested = true;
      return;
    }
    if (_stoppingRecording || !_isRecording || !mounted) return;
    _stoppingRecording = true;
    _recordTimer?.cancel();
    _recordTimer = null;
    _recordWatch.stop();
    final durationMs = _recordWatch.elapsedMilliseconds.clamp(100, 8000);
    setState(() => _state = 1);
    try {
      final video = await _cameraController!.stopVideoRecording();
      if (!mounted) return;
      await _processVideo(video, durationMs: durationMs);
    } catch (e) {
      _fail(e);
    } finally {
      _stoppingRecording = false;
    }
  }

  Future<void> _processVideo(XFile video, {required int durationMs}) async {
    final restoProvider = Provider.of<RestoProvider>(context, listen: false);
    final restaurantId = restoProvider.restaurantId;
    if (restaurantId == null) {
      setState(() {
        _state = -1;
        _errorMessage = tr(context, 'no_resto_connected');
      });
      return;
    }

    try {
      // Sample frames across the clip — pans across menu boards/screens
      // mean each frame catches different dishes.
      final frames = <String>[];
      int payloadSize = 0;
      for (final fraction in [0.1, 0.25, 0.4, 0.55, 0.7, 0.85]) {
        if (!mounted) return;
        final ms = (durationMs * fraction).round();
        // video_thumbnail returns null silently on some formats — retry
        // at frame 0 with a smaller size before giving up on this sample.
        var bytes = await vt.VideoThumbnail.thumbnailData(
          video: video.path,
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: ms,
          quality: 85,
          maxWidth: 1600,
        );
        bytes ??= await vt.VideoThumbnail.thumbnailData(
          video: video.path,
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: 0,
          quality: 70,
          maxWidth: 1024,
        );
        if (!mounted) return;
        if (bytes != null && bytes.isNotEmpty) {
          final encoded = base64Encode(bytes);
          if (payloadSize + encoded.length > _maxPayloadCharacters) continue;
          payloadSize += encoded.length;
          frames.add(encoded);
        }
      }
      if (frames.isEmpty) {
        if (!mounted) return;
        // ValidationException (an ApiException) so _fail shows THIS
        // message instead of the generic scan_failed text.
        throw ValidationException(tr(context, 'extract_fail'));
      }
      debugPrint('[Scanner] extracted ${frames.length} frames');

      final service = RestaurantService();
      await service.scanMenuFrames(restaurantId, frames);

      await restoProvider.loadMenu();
      if (!mounted) return;
      setState(() => _state = 2);
      _returnTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _fail(e);
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
      _fail(e);
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

      if (file == null || !mounted) return; // User cancelled

      setState(() => _state = 1);

      await _processImage(file);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    if (!mounted) return;

    final restoProvider = Provider.of<RestoProvider>(context, listen: false);
    final restaurantId = restoProvider.restaurantId;

    if (restaurantId == null) {
      setState(() {
        _state = -1;
        _errorMessage = tr(context, 'no_resto_connected');
      });
      return;
    }

    try {
      // Read image bytes and encode as base64
      final bytes = await imageFile.readAsBytes();
      if (!mounted) return;
      final imageBase64 = base64Encode(bytes);
      if (imageBase64.length > _maxPayloadCharacters) {
        throw ValidationException(tr(context, 'scan_image_too_large'));
      }

      final service = RestaurantService();
      await service.scanMenu(restaurantId, imageBase64);

      // Refresh menu in provider
      await restoProvider.loadMenu();

      if (!mounted) return;
      setState(() => _state = 2);

      _returnTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    // The viewfinder (idle and recording) is always dark, whatever the
    // theme; the result states follow the theme.
    final live = _state == 0 || _state == 3;
    const onCameraShadow = [
      Shadow(offset: Offset(0, 1), blurRadius: 4, color: Color(0x99000000)),
    ];
    return Scaffold(
      backgroundColor: live ? Colors.black : fast.bg,
      appBar: AppBar(
        backgroundColor: live ? Colors.black : fast.bg,
        elevation: 0,
        systemOverlayStyle: live ? SystemUiOverlayStyle.light : null,
        iconTheme: IconThemeData(color: live ? Colors.white : fast.t1),
        title: Text(
          tr(context, 'ai_assistant'),
          style: FASTText.title.copyWith(color: live ? Colors.white : fast.t1),
        ),
      ),
      extendBodyBehindAppBar: false,
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
                  : Container(color: FastNightSurface.bottom),
            ),

          // Viewfinder darkened overlay with a clear center cutout
          if (_state == 0)
            Positioned.fill(child: CustomPaint(painter: ViewfinderPainter())),

          // Finder frame and guidelines
          if (_state == 0)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 360,
                    decoration: BoxDecoration(
                      border: Border.all(color: FASTPro.teal, width: 1.5),
                      borderRadius: BorderRadius.circular(FASTRadius.sm),
                    ),
                    child: Stack(
                      children: [
                        // Corner highlights
                        _scannerCorner(top: 0, left: 0),
                        _scannerCorner(top: 0, right: 0),
                        _scannerCorner(bottom: 0, left: 0),
                        _scannerCorner(bottom: 0, right: 0),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(FASTSpace.s24),
                            child: Text(
                              tr(context, 'frame_menu'),
                              textAlign: TextAlign.center,
                              style: FASTText.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                                shadows: onCameraShadow,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FASTSpace.s40),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s24,
                    ),
                    child: Text(
                      tr(context, 'scan_hint'),
                      textAlign: TextAlign.center,
                      style: FASTText.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: onCameraShadow,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Control buttons at the bottom
          if (_state == 0 || _state == 3)
            Positioned(
              key: const ValueKey('scanner-controls'),
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // While recording: how to move the phone.
                  if (_state == 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FASTSpace.s24,
                        0,
                        FASTSpace.s24,
                        FASTSpace.s16,
                      ),
                      child: Text(
                        tr(context, 'scan_sweep'),
                        textAlign: TextAlign.center,
                        style: FASTText.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          shadows: onCameraShadow,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gallery picker button
                      IconButton(
                        onPressed: _isRecording
                            ? null
                            : () => _captureAndScan(ImageSource.gallery),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.08,
                          ),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white38,
                          fixedSize: const Size(48, 48),
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Capture button in the absolute center — Snapchat
                      // style: tap = photo, press & hold = video (release
                      // to stop).
                      GestureDetector(
                        onTap: _isRecording
                            ? _stopVideoAndProcess
                            : _isCameraInitialized
                            ? _takeInAppPicture
                            : null,
                        onLongPressStart: (_) => _startVideoRecording(),
                        onLongPressEnd: (_) => _stopVideoAndProcess(),
                        onLongPressCancel: _stopVideoAndProcess,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording
                                  ? FASTBrand.error
                                  : const Color(0xFFB8B4BE),
                              width: 6,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.camera_alt,
                              color: _isRecording
                                  ? FASTBrand.error
                                  : FASTBrand.onAmber,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      // Spacing balance (matches the gallery button + gap)
                      const SizedBox(width: 68),
                    ],
                  ),
                  const SizedBox(height: FASTSpace.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FASTSpace.s24,
                    ),
                    child: Text(
                      tr(context, 'scan_gesture'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: FASTText.label.copyWith(
                        color: Colors.white70,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Recording overlay — red REC + elapsed
          if (_state == 3)
            Positioned(
              top: FASTSpace.s24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FASTSpace.s12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(FASTRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: FASTBrand.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: FASTSpace.s8),
                      Text(
                        'REC ${(_recordElapsed ~/ 60).toString().padLeft(2, '0')}:${(_recordElapsed % 60).toString().padLeft(2, '0')}',
                        style: FASTText.price.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_state == 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(FASTSpace.s24),
                child: FastNightSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FASTSpace.s24,
                    vertical: FASTSpace.s40,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: FASTPro.teal),
                        const SizedBox(height: FASTSpace.s24),
                        Text(
                          tr(context, 'ai_analyzing'),
                          textAlign: TextAlign.center,
                          style: FASTText.title.copyWith(
                            color: FastNightSurface.onNight,
                          ),
                        ),
                        const SizedBox(height: FASTSpace.s8),
                        Text(
                          tr(context, 'extracting'),
                          textAlign: TextAlign.center,
                          style: FASTText.body.copyWith(
                            color: FastNightSurface.onNightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_state == 2)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(FASTSpace.s24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: FASTBrand.success,
                      size: 72,
                    ),
                    const SizedBox(height: FASTSpace.s24),
                    Text(
                      tr(context, 'menu_imported'),
                      textAlign: TextAlign.center,
                      style: FASTText.title.copyWith(color: fast.t1),
                    ),
                  ],
                ),
              ),
            ),

          if (_state == -1)
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(FASTSpace.s24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: FASTBrand.error,
                      size: 72,
                    ),
                    const SizedBox(height: FASTSpace.s24),
                    Text(
                      tr(context, 'scan_failed'),
                      textAlign: TextAlign.center,
                      style: FASTText.title.copyWith(color: fast.t1),
                    ),
                    const SizedBox(height: FASTSpace.s8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: FASTText.body.copyWith(color: fast.t2),
                    ),
                    const SizedBox(height: FASTSpace.s24),
                    FastButton(
                      kind: FastButtonKind.ink,
                      expand: false,
                      icon: Icons.refresh,
                      label: tr(context, 'retry'),
                      onPressed: _initializeCamera,
                    ),
                    if (_cameraPermissionDenied) ...[
                      const SizedBox(height: FASTSpace.s4),
                      TextButton(
                        onPressed: Geolocator.openAppSettings,
                        child: Text(
                          tr(context, 'open_settings'),
                          style: FASTText.body.copyWith(
                            color: FASTPro.teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: FASTSpace.s12),
                    FastTap(
                      onTap: () => _captureAndScan(ImageSource.gallery),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FASTSpace.s24,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(FASTRadius.pill),
                          border: Border.all(color: fast.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 18,
                              color: fast.t1,
                            ),
                            const SizedBox(width: FASTSpace.s8),
                            Flexible(
                              child: Text(
                                tr(context, 'choose_photo'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fast.t1,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
          color: FASTPro.teal,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(top != null && left != null ? 10 : 0),
            topRight: Radius.circular(top != null && right != null ? 10 : 0),
            bottomLeft: Radius.circular(
              bottom != null && left != null ? 10 : 0,
            ),
            bottomRight: Radius.circular(
              bottom != null && right != null ? 10 : 0,
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
