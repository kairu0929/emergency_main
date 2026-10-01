import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'dart:async';
import 'package:first_flutter_project/login_page.dart';
import 'package:geocoding/geocoding.dart';
import 'package:first_flutter_project/auth_serv.dart';
 
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
 
  @override
  State<HomePage> createState() => _HomePageState();
}
 
class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
      final authService = AuthService();
  // Location
  final loc.Location _locationController = loc.Location();
  LatLng? _currentPosition;
  StreamSubscription? _locationSubscription;
  String _userAddress = 'Fetching location...';
 
  // SOS animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _sosSent = false;
 
  String? _selectedType;
 
  final String _userName = 'Juan Dela Cruz';
  final String _userPhone = '+63 912 345 6789';

    SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
 
  // Emergency types
  final List<Map<String, dynamic>> _emergencyTypes = [
    {'label': 'Disaster',  'icon': Icons.thunderstorm_outlined,               'color': const Color(0xFFFF9800)},
    {'label': 'Medical', 'icon': Icons.local_hospital_outlined,       'color': const Color(0xFF2196F3)},
    {'label': 'Fire',    'icon': Icons.local_fire_department_outlined, 'color': const Color(0xFFE53935)},
    {'label': 'Crime',   'icon': Icons.security_outlined,              'color': const Color(0xFF9C27B0)},
  ];
 
  @override
  void initState() {
    super.initState();
 
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
 
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getLocationUpdates();
    });
  }
 
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
 
  Future<void> getLocationUpdates() async {
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;
 
    try {
      serviceEnabled = await _locationController.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationController.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBar("Location permission is required for SOS"),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Location service error: $e');
      return;
    }
 
    try {
      permissionGranted = await _locationController.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _locationController.requestPermission();
      }
      if (permissionGranted == loc.PermissionStatus.denied ||
          permissionGranted == loc.PermissionStatus.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _snackBar("Location permission is required for SOS"),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Permission error: $e');
      return;
    }
 
  _locationSubscription =
    _locationController.onLocationChanged.listen((loc.LocationData loc) {
  if (loc.latitude != null && loc.longitude != null) {
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(loc.latitude!, loc.longitude!);
      });
      // ← add this
      _updateAddressFromStream(loc.latitude!, loc.longitude!);
    }
  }
});
  }

  Future<void> _updateAddressFromStream(double lat, double lng) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isNotEmpty && mounted) {
      final p = placemarks.first;
      final address = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

      setState(() => _userAddress = address);
    }
  } catch (e) {
    debugPrint('Geocoding error: $e');
  }
}
 
  // ─── SOS confirmation popup with countdown ───────────────────────────────
  Future<void> _sendSOS() async {
    final String emergencyType = _selectedType ?? 'General';
    final double latitude = _currentPosition?.latitude ?? 0.0;
    final double longitude = _currentPosition?.longitude ?? 0.0;
    final String location = _userAddress;
 
    await authService.sosEmergency(
      emergency_type: emergencyType,
      latitude: latitude,
      longitude: longitude,
      location: location,
    );
  }

  void _onSOSTapped() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar("Please select an emergency type before sending SOS"),
        );
      return;
    }

    if (_sosSent) {
      // already sent — reset
      setState(() {
        _sosSent = false;
        _selectedType = null;
      });
      _pulseController.repeat(reverse: true);
      return;
    }
 
    final String type = _selectedType ?? 'General';
    final Map<String, dynamic>? typeData = _selectedType != null
        ? _emergencyTypes.firstWhere((e) => e['label'] == _selectedType)
        : null;
    final Color typeColor =
        typeData != null ? typeData['color'] : const Color(0xFFE53935);
 
    showDialog (
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => _SOSConfirmDialog(
        emergencyType: type,
        typeColor: typeColor,
        onConfirmed: () async {
          Navigator.pop(context);

          try {
            await _sendSOS();

            if(!mounted) return;

            setState(() => _sosSent = true);
              _pulseController.stop();
              _pulseController.reset();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBar('Error sending SOS: ${e.toString()}'),
            );
            return;
          }
        },
        onCancelled: () {
          Navigator.pop(context);
        },
      ),
    );
  }
 
  // ─── User info bottom sheet ───────────────────────────────────────────────
 
  void _showUserMenu(BuildContext context) {
    final currentFirstName = authService.getCurrentUserFirstName();
    final currentLastName = authService.getCurrentUserLastName();
    final currentPhone = authService.getCurrentUserPhone();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFFE53935).withOpacity(0.2),
                  child: const Icon(Icons.person,
                      color: Color(0xFFE53935), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$currentFirstName $currentLastName',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('$currentPhone',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 4),
            _infoRow(Icons.location_on_outlined, 'Address', _userAddress),
            _infoRow(
                Icons.verified_user_outlined, 'Role', 'Resident — Cluster 6'),
            _infoRow(
              Icons.circle,
              'GPS',
              _currentPosition != null
                  ? '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                  : 'Acquiring...',
              valueColor: _currentPosition != null
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              iconColor: _currentPosition != null
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              iconSize: 10,
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('LOGOUT',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = const Color(0xFFCCCCCC),
    Color iconColor = const Color(0xFF555555),
    double iconSize = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 12),
          Text('$label: ',
              style:
                  const TextStyle(color: Color(0xFF666666), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
 
  // ─── Build ────────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('RESCUE LINK',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      Text('Dasmariñas — Cluster 6',
                          style: TextStyle(
                              color: Color(0xFF666666), fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      _topBarIcon(Icons.notifications_outlined, onTap: () {}),
                      const SizedBox(width: 10),
                      _topBarIcon(Icons.person_outline,
                          onTap: () => _showUserMenu(context)),
                    ],
                  ),
                ],
              ),
            ),
 
            // GPS pill
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentPosition != null
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentPosition != null
                            ? 'GPS Active • ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                            : 'Acquiring GPS...',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
 
            const Spacer(),
 
            // SOS section
            Column(
              children: [
                // ── Emergency type label ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedType != null
                      ? Row(
                          key: ValueKey(_selectedType),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _emergencyTypes.firstWhere(
                                  (e) => e['label'] == _selectedType)['icon'],
                              color: _emergencyTypes.firstWhere(
                                  (e) => e['label'] == _selectedType)['color'],
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_selectedType!.toUpperCase()} EMERGENCY SELECTED',
                              style: TextStyle(
                                color: _emergencyTypes.firstWhere(
                                    (e) => e['label'] == _selectedType)['color'],
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'SELECT TYPE BELOW, THEN PRESS SOS',
                          key: ValueKey('default'),
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
 
                const SizedBox(height: 32),
 
                // ── SOS button ──
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _sosSent ? 1.0 : _pulseAnimation.value,
                    child: child,
                  ),
                  child: GestureDetector(
                    onTap: _onSOSTapped,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_sosSent
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE53935))
                                .withOpacity(0.07),
                          ),
                        ),
                        Container(
                          width: 208,
                          height: 208,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_sosSent
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE53935))
                                .withOpacity(0.14),
                          ),
                        ),
                        Container(
                          width: 182,
                          height: 182,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sosSent
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE53935),
                            boxShadow: [
                              BoxShadow(
                                color: (_sosSent
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFE53935))
                                    .withOpacity(0.45),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _sosSent ? '✓' : 'SOS',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                if (_sosSent)
                                  const Text(
                                    'SENT',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w600,
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
 
                const SizedBox(height: 22),
 
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _sosSent
                        ? 'HELP IS ON THE WAY'
                        : 'PRESS THE BUTTON TO SEND SOS',
                    key: ValueKey(_sosSent),
                    style: TextStyle(
                      color: _sosSent
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF666666),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
 
            const Spacer(),
 
            // ── Emergency type selector cards ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EMERGENCY TYPE',
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _emergencyTypes.map((type) {
                      final bool isSelected =
                          _selectedType == type['label'];
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: type == _emergencyTypes.last ? 0 : 10,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedType = isSelected
                                    ? null
                                    : type['label'];
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (type['color'] as Color)
                                        .withOpacity(0.15)
                                    : const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? type['color']
                                      : const Color(0xFF2A2A2A),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(type['icon'],
                                      color: isSelected
                                          ? type['color']
                                          : const Color(0xFF555555),
                                      size: 22),
                                  const SizedBox(height: 6),
                                  Text(
                                    type['label'],
                                    style: TextStyle(
                                      color: isSelected
                                          ? type['color']
                                          : const Color(0xFF555555),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
 
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
 
  Widget _topBarIcon(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
 
// ─── SOS Confirmation Dialog with countdown ───────────────────────────────────
 
class _SOSConfirmDialog extends StatefulWidget {
  final String emergencyType;
  final Color typeColor;
  final VoidCallback onConfirmed;
  final VoidCallback onCancelled;
 
  const _SOSConfirmDialog({
    required this.emergencyType,
    required this.typeColor,
    required this.onConfirmed,
    required this.onCancelled,
  });
 
  @override
  State<_SOSConfirmDialog> createState() => _SOSConfirmDialogState();
}
 
class _SOSConfirmDialogState extends State<_SOSConfirmDialog> {
  int _countdown = 5;
  Timer? _timer;
 
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        widget.onCancelled();
      } else {
        setState(() => _countdown--);
      }
    });
  }
 
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.typeColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.typeColor.withOpacity(0.15),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: widget.typeColor, size: 32),
            ),
 
            const SizedBox(height: 20),
 
            const Text(
              'CONFIRM SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
 
            const SizedBox(height: 10),
 
            // Emergency type badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: widget.typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: widget.typeColor.withOpacity(0.4)),
              ),
              child: Text(
                widget.emergencyType.toUpperCase(),
                style: TextStyle(
                  color: widget.typeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
 
            const SizedBox(height: 16),
 
            Text(
              'Your location will be sent to\nresponders immediately.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                height: 1.5,
              ),
            ),
 
            const SizedBox(height: 24),
 
            // Countdown indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined,
                    color: Color(0xFF555555), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Auto-cancels in $_countdown seconds',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
 
            const SizedBox(height: 6),
 
            // Countdown bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _countdown / 5,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.typeColor),
                minHeight: 4,
              ),
            ),
 
            const SizedBox(height: 24),
 
            // Buttons
            Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: widget.onCancelled,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF2A2A2A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
 
                const SizedBox(width: 12),
 
                // Confirm
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: widget.onConfirmed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.typeColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'SEND SOS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
 