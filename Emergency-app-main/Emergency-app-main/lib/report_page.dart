import 'dart:io';
import 'package:first_flutter_project/auth_serv.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:first_flutter_project/cam_page.dart';
 
// ─── Emergency types ──────────────────────────────────────────────────────────
enum EmergencyType { fire, medical, crime, disaster, other }
 
extension EmergencyTypeExt on EmergencyType {
  String get label {
    switch (this) {
      case EmergencyType.fire:     return 'Fire';
      case EmergencyType.medical:  return 'Medical';
      case EmergencyType.crime:    return 'Crime';
      case EmergencyType.disaster: return 'Disaster';
      case EmergencyType.other:    return 'Other';
    }
  }
 
  IconData get icon {
    switch (this) {
      case EmergencyType.fire:     return Icons.local_fire_department_outlined;
      case EmergencyType.medical:  return Icons.local_hospital_outlined;
      case EmergencyType.crime:    return Icons.security_outlined;
      case EmergencyType.disaster: return Icons.thunderstorm_outlined;
      case EmergencyType.other:    return Icons.report_outlined;
    }
  }
 
  Color get color {
    switch (this) {
      case EmergencyType.fire:     return const Color(0xFFE53935);
      case EmergencyType.medical:  return const Color(0xFF2196F3);
      case EmergencyType.crime:    return const Color(0xFF9C27B0);
      case EmergencyType.disaster: return const Color(0xFFFF9800);
      case EmergencyType.other:    return const Color(0xFF607D8B);
    }
  }
}
 
// ─── Report Page ──────────────────────────────────────────────────────────────
class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);
 
  @override
  State<ReportPage> createState() => _ReportPageState();
}
 
class _ReportPageState extends State<ReportPage> {
  final authService = AuthService();
  final _descController = TextEditingController();
 
  EmergencyType? _selectedType;
  File? _capturedPhoto;
  Position? _position;
  String _readableAddress = 'Fetching location...';
  bool _isSubmitting = false;
  bool _submitted = false;
 
  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }
 
  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }
 
  // ── Location + Reverse Geocoding ──────────────────────────────────────────
 
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
 
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
 
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
 
      // Reverse geocoding: coordinates → readable address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
 
      if (mounted) {
        setState(() {
          _position = pos;
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            // Build a readable string from the placemark
            _readableAddress = [
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
            ].where((s) => s != null && s.isNotEmpty).join(', ');
          }
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _readableAddress = 'Location unavailable');
    }
  }
 
  // ── Open Camera Page ──────────────────────────────────────────────────────
 
  Future<void> _openCamera() async {
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => CamPage(position: _position),
      ),
    );
    if (result != null && mounted) {
      setState(() => _capturedPhoto = result);
    }
  }
 
  // ── Submit ────────────────────────────────────────────────────────────────
 
  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Please select an emergency type.'),
      );
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Please describe the emergency.'),
      );
      return;
    }
    if (_capturedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Please capture a photo of the emergency.'),
      );
    }
 
    setState(() => _isSubmitting = true);
 
    await authService.reportEmergency(
      emergency_type: _selectedType!.label,
      description: _descController.text.trim(),
      latitude: _position?.latitude ?? 0,
      longitude: _position?.longitude ?? 0,
      location: _readableAddress,
      photo: _capturedPhoto,
    );
 
    setState(() {
      _isSubmitting = false;
      _submitted = true;
    });
  }
 
  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
 
  // ─── Build ────────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();
 
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'FILE A REPORT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Dasmariñas — Cluster 6',
                        style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
 
            // Scrollable form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Location card
                    _sectionLabel('DETECTED LOCATION'),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _readableAddress,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_position != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      color: Color(0xFF555555),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_position == null)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                        ],
                      ),
                    ),
 
                    const SizedBox(height: 28),
 
                    // ── Emergency type selector
                    _sectionLabel('EMERGENCY TYPE'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: EmergencyType.values.map((type) {
                        final selected = _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? type.color.withOpacity(0.18)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? type.color : const Color(0xFF2A2A2A),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(type.icon,
                                    color: selected ? type.color : const Color(0xFF555555),
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  type.label,
                                  style: TextStyle(
                                    color: selected ? type.color : const Color(0xFF888888),
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
 
                    const SizedBox(height: 28),
 
                    // ── Description
                    _sectionLabel('DESCRIPTION'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Describe what is happening in detail...',
                        hintStyle: const TextStyle(color: Color(0xFF3A3A3A), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
 
                    const SizedBox(height: 28),
 
                    // ── Photo capture
                    _sectionLabel('PHOTO EVIDENCE'),
                    const SizedBox(height: 4),
                    const Text(
                      'Required — photo is taken live via camera only',
                      style: TextStyle(color: Color(0xFF444444), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _openCamera,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _capturedPhoto != null
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2A2A2A),
                            width: _capturedPhoto != null ? 1.5 : 1,
                          ),
                        ),
                        child: _capturedPhoto != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_capturedPhoto!, fit: BoxFit.cover),
                                    // Retake overlay
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: _openCamera,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.replay, color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text('Retake',
                                                  style: TextStyle(
                                                      color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF252525),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.photo_camera_outlined,
                                        color: Color(0xFF555555), size: 24),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Tap to open camera',
                                      style: TextStyle(
                                          color: Color(0xFF555555), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  const Text('GPS & timestamp will be embedded automatically',
                                      style: TextStyle(
                                          color: Color(0xFF3A3A3A), fontSize: 11)),
                                ],
                              ),
                      ),
                    ),
 
                    const SizedBox(height: 36),
 
                    // ── Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF3A1A1A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'SUBMIT REPORT',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
 
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  // ── Success screen
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF4CAF50), size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'REPORT SUBMITTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your report has been sent to the responders. Stay safe and stay in a secure location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      _submitted = false;
                      _selectedType = null;
                      _capturedPhoto = null;
                      _descController.clear();
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('FILE ANOTHER REPORT',
                        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      );
}
 