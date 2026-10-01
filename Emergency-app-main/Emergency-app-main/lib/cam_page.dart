import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
 
class CamPage extends StatefulWidget {
  final Position? position;
  const CamPage({Key? key, this.position}) : super(key: key);
 
  @override
  State<CamPage> createState() => _CamPageState();
}
 
class _CamPageState extends State<CamPage> with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? cameraController;
  int selectedCameraIndex = 0;
  bool _takingPicture = false;
  late String _timestamp;
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timestamp = DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now());
    _setupCameraController();
  }
 
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController?.dispose();
    super.dispose();
  }
 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) return;
    if (state == AppLifecycleState.inactive) {
      cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController();
    }
  }
 
  Future<void> _setupCameraController() async {
    final List<CameraDescription> _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      setState(() {
        cameras = _cameras;
        cameraController = CameraController(
          _cameras[selectedCameraIndex],
          ResolutionPreset.high,
        );
      });
      await cameraController!.initialize();
      if (mounted) setState(() {});
    }
  }
 
  Future<void> _switchCamera() async {
    if (cameras.isEmpty) return;
    selectedCameraIndex = (selectedCameraIndex + 1) % cameras.length;
    await cameraController?.dispose();
    cameraController = CameraController(
      cameras[selectedCameraIndex],
      ResolutionPreset.high,
    );
    await cameraController!.initialize();
    if (mounted) setState(() {});
  }
 
  // ── Get readable address from coordinates ──────────────────────────────────
  Future<String> _getAddress(double lat, double lng) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(lat, lng);
      final p = placemarks[0];
      return '${p.street}, ${p.subLocality}, ${p.locality}';
    } catch (e) {
      return 'Address unavailable';
    }
  }
 
  // ── Burn geotag text into the photo file ───────────────────────────────────
  Future<File> _embedGeotag(File originalFile, Position? pos) async {
    final Uint8List bytes = await originalFile.readAsBytes();
    img.Image? photo = img.decodeImage(bytes);
    if (photo == null) return originalFile;
 
    final String timestamp =
        DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now());
 
    // Build stamp lines
    List<String> lines = [
      'Cluster 6 — Dasmariñas, Cavite',
      'Time: $timestamp',
    ];
 
    if (pos != null) {
      final address = await _getAddress(pos.latitude, pos.longitude);
      lines.add('GPS: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
      lines.add('Acc: ±${pos.accuracy.toStringAsFixed(1)}m');
      lines.add('Loc: $address');
    } else {
      lines.add('GPS: Unavailable');
    }
 
    // ── Draw dark background bar at the bottom ──
    final int barHeight = 18 * lines.length + 24;
    final int barTop = photo.height - barHeight;
 
    img.fillRect(
      photo,
      x1: 0,
      y1: barTop,
      x2: photo.width,
      y2: photo.height,
      color: img.ColorRgba8(0, 0, 0, 180),
    );
 
    // ── Draw each line of text ──
    final imgFont = img.arial14; // built-in font, no extra files needed
 
    for (int i = 0; i < lines.length; i++) {
      img.drawString(
        photo,
        lines[i],
        font: imgFont,
        x: 16,
        y: barTop + 12 + (i * 18),
        color: img.ColorRgb8(255, 255, 255),
      );
    }
 
    // ── Save the modified image to a new file ──
    final Directory tempDir = await getTemporaryDirectory();
    final String newPath =
        '${tempDir.path}/geotagged_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File newFile = File(newPath);
    await newFile.writeAsBytes(img.encodeJpg(photo, quality: 90));
 
    return newFile;
  }
 
  Future<void> _takePicture() async {
    if (_takingPicture || cameraController == null) return;
    setState(() {
      _takingPicture = true;
      _timestamp = DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now());
    });
 
    try {
      final XFile xfile = await cameraController!.takePicture();
      File file = File(xfile.path);
 
      // Embed geotag into the actual photo
      file = await _embedGeotag(file, widget.position);
 
      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _takingPicture = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildUI(),
    );
  }
 
  Widget _buildUI() {
    if (cameraController == null ||
        cameraController?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE53935)),
      );
    }
 
    final pos = widget.position;
    final hasGps = pos != null;
 
    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen preview
          CameraPreview(cameraController!),
 
          // ── Top gradient + header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, null),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'EVIDENCE CAPTURE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('● LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ),
 
          // ── Viewfinder stamp overlay (preview only — also burned into photo)
          Positioned(
            bottom: 130,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stampRow(Icons.shield_outlined, 'Cluster 6 — Dasmariñas'),
                  const SizedBox(height: 4),
                  _stampRow(Icons.access_time_outlined, _timestamp),
                  if (hasGps) ...[
                    const SizedBox(height: 4),
                    _stampRow(
                      Icons.location_on_outlined,
                      '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 4),
                    _stampRow(
                      Icons.speed_outlined,
                      'Acc ±${pos.accuracy.toStringAsFixed(1)}m',
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    _stampRow(
                        Icons.location_off_outlined, 'GPS unavailable'),
                  ],
                  const SizedBox(height: 4),
                  _stampRow(Icons.camera_outlined,
                      'Geotag will be embedded in photo'),
                ],
              ),
            ),
          ),
 
          // ── Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Switch camera
                  GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.flip_camera_ios_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
 
                  // Shutter
                  GestureDetector(
                    onTap: _takingPicture ? null : _takePicture,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: _takingPicture
                            ? const Color(0xFFE53935).withOpacity(0.6)
                            : Colors.white.withOpacity(0.12),
                      ),
                      child: Center(
                        child: _takingPicture
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
 
                  const SizedBox(width: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _stampRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 12),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
 