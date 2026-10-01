import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _supabase = Supabase.instance.client;
  final _locationController = loc.Location();
  final MapController _mapController = MapController();

  LatLng? _currentPosition;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  bool _centeredOnUser = false;
  StreamSubscription? _locationSub;

  // Cluster 6, City of Dasmariñas, Cavite — default center
  static const LatLng _cluster6 = LatLng(14.3175, 120.9705);

  static const Map<String, Map<String, dynamic>> _statusConfig = {
    'pending': {
      'label': 'Pending',
      'color': Color(0xFFFF9800),
      'bg': Color(0x1FFF9800),
      'icon': Icons.hourglass_empty_rounded,
    },
    'responding': {
      'label': 'Responding',
      'color': Color(0xFF2196F3),
      'bg': Color(0x1F2196F3),
      'icon': Icons.directions_run_rounded,
    },
    'resolved': {
      'label': 'Resolved',
      'color': Color(0xFF4CAF50),
      'bg': Color(0x1F4CAF50),
      'icon': Icons.check_circle_outline_rounded,
    },
  };

  static const Map<String, Map<String, dynamic>> _typeConfig = {
    'Fire': {'color': Color(0xFFE53935), 'icon': Icons.local_fire_department_outlined},
    'Medical': {'color': Color(0xFF2196F3), 'icon': Icons.local_hospital_outlined},
    'Crime': {'color': Color(0xFF9C27B0), 'icon': Icons.security_outlined},
    'Disaster': {'color': Color(0xFFFF9800), 'icon': Icons.warning_amber_outlined},
    'General': {'color': Color(0xFF888888), 'icon': Icons.report_outlined},
  };

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _startLocationUpdates();
    _listenForReportUpdates();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _startLocationUpdates() async {
    try {
      bool serviceEnabled = await _locationController.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationController.requestService();
        if (!serviceEnabled) return;
      }

      loc.PermissionStatus permission =
          await _locationController.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await _locationController.requestPermission();
        if (permission == loc.PermissionStatus.denied) return;
      }

      _locationSub =
          _locationController.onLocationChanged.listen((locData) {
        if (locData.latitude != null && locData.longitude != null && mounted) {
          final pos = LatLng(locData.latitude!, locData.longitude!);
          setState(() => _currentPosition = pos);

          // Auto-center on user once on first fix
          if (!_centeredOnUser) {
            _mapController.move(pos, 15);
            _centeredOnUser = true;
          }
        }
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ── Supabase ──────────────────────────────────────────────────────────────

  Future<void> _fetchReports() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final sos = await _supabase
          .from('sos_emergency_reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final reports = await _supabase
          .from('emergency_reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final combined = [
        ...List<Map<String, dynamic>>.from(sos)
            .map((r) => {...r, 'source': 'sos'}),
        ...List<Map<String, dynamic>>.from(reports)
            .map((r) => {...r, 'source': 'report'}),
      ];

      combined.sort((a, b) =>
          (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      if (mounted) {
        setState(() {
          _reports = combined;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForReportUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Listen to both tables — refresh when anything changes
    _supabase
        .from('sos_emergency_reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => _fetchReports());

    _supabase
        .from('emergency_reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => _fetchReports());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _pinColor(Map<String, dynamic> r) {
    final status = r['status'] ?? 'pending';
    if (status == 'resolved') return const Color(0xFF4CAF50);
    if (status == 'responding') return const Color(0xFF2196F3);
    final type = r['emergency_type'] ?? r['type'] ?? 'General';
    return (_typeConfig[type]?['color'] as Color?) ?? const Color(0xFF888888);
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Unknown';
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day}, ${dt.year} • $h:$m $ampm';
  }

  // ── Report detail popup ───────────────────────────────────────────────────

  void _showDetail(Map<String, dynamic> report) {
    final type = report['emergency_type'] ?? report['type'] ?? 'General';
    final status = report['status'] ?? 'pending';
    final isSos = report['source'] == 'sos';
    final statusData = _statusConfig[status] ?? _statusConfig['pending']!;
    final typeData = _typeConfig[type] ?? _typeConfig['General']!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Source badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSos
                      ? const Color(0xFFE53935).withOpacity(0.1)
                      : const Color(0xFF333333).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSos
                        ? const Color(0xFFE53935).withOpacity(0.3)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Text(
                  isSos ? '🚨 SOS REPORT' : '📋 INCIDENT REPORT',
                  style: TextStyle(
                    color: isSos
                        ? const Color(0xFFE53935)
                        : const Color(0xFF888888),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Type + status
              Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: (typeData['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeData['icon'] as IconData,
                        color: typeData['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$type Emergency',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(_formatDate(report['created_at']),
                            style: const TextStyle(
                                color: Color(0xFF666666), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusData['bg'] as Color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(statusData['label'] as String,
                        style: TextStyle(
                            color: statusData['color'] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1E1E1E)),
              const SizedBox(height: 14),

              _detailRow(Icons.location_on_outlined,
                  report['location'] ?? report['address'] ?? 'Location unavailable'),
              const SizedBox(height: 10),
              _detailRow(
                Icons.gps_fixed_outlined,
                report['latitude'] != null
                    ? '${(report['latitude'] as num).toStringAsFixed(6)}, ${(report['longitude'] as num).toStringAsFixed(6)}'
                    : 'Coordinates unavailable',
              ),

              if (report['description'] != null &&
                  report['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _detailRow(Icons.notes_outlined, report['description']),
              ],

              // Photo
              if (report['photo_url'] != null &&
                  report['photo_url'].toString().isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('PHOTO EVIDENCE',
                    style: TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    report['photo_url'],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 160,
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFE53935), strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Color(0xFF333333), size: 28)),
                    ),
                  ),
                ),
              ],

              // Status timeline
              const SizedBox(height: 20),
              const Text('STATUS TIMELINE',
                  style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8)),
              const SizedBox(height: 12),
              _statusTimeline(status),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF555555), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFAAAAAA), fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  Widget _statusTimeline(String currentStatus) {
    final steps = [
      {'key': 'pending', 'label': 'Report submitted', 'sub': 'Waiting for response'},
      {'key': 'responding', 'label': 'Responder dispatched', 'sub': 'Help is on the way'},
      {'key': 'resolved', 'label': 'Incident resolved', 'sub': 'Case closed'},
    ];
    final order = ['pending', 'responding', 'resolved'];
    final currentIndex = order.indexOf(currentStatus);
    final config = {
      'pending': const Color(0xFFFF9800),
      'responding': const Color(0xFF2196F3),
      'resolved': const Color(0xFF4CAF50),
    };

    return Column(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isCompleted = i <= currentIndex;
        final isCurrent = i == currentIndex;
        final color = isCompleted
            ? config[step['key']]!
            : const Color(0xFF2A2A2A);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? color.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    border: Border.all(
                        color: isCompleted ? color : const Color(0xFF2A2A2A),
                        width: isCurrent ? 2 : 1),
                  ),
                  child: isCompleted
                      ? Icon(Icons.check, color: color, size: 12)
                      : null,
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 1, height: 28,
                    color: i < currentIndex
                        ? config[steps[i + 1]['key']!]!.withOpacity(0.3)
                        : const Color(0xFF1E1E1E),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step['label']!,
                      style: TextStyle(
                          color: isCompleted
                              ? Colors.white
                              : const Color(0xFF333333),
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(step['sub']!,
                      style: TextStyle(
                          color: isCompleted
                              ? color
                              : const Color(0xFF2A2A2A),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final withCoords = _reports
        .where((r) => r['latitude'] != null && r['longitude'] != null)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('MY LOCATION',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      Text('Cluster 6 — Dasmariñas, Cavite',
                          style: TextStyle(
                              color: Color(0xFF666666), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  // Center on me button
                  GestureDetector(
                    onTap: () {
                      if (_currentPosition != null) {
                        _mapController.move(_currentPosition!, 16);
                      }
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: _currentPosition != null
                            ? const Color(0xFFE53935)
                            : const Color(0xFF444444),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Refresh button
                  GestureDetector(
                    onTap: _fetchReports,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Icon(Icons.refresh_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── GPS pill ──
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 12),
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
                        width: 7, height: 7,
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

            // ── Map ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _loading
                      ? Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFE53935)),
                          ),
                        )
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _cluster6,
                            initialZoom: 14.5,
                            minZoom: 10,
                            maxZoom: 19,
                          ),
                          children: [
                            // OpenStreetMap — free, no API key
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.first_flutter_project',
                            ),

                            // Current user location marker
                            if (_currentPosition != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentPosition!,
                                    width: 44,
                                    height: 44,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Pulsing ring
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFE53935)
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        // Blue dot (you are here)
                                        Container(
                                          width: 18, height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF1565C0),
                                            border: Border.all(
                                                color: Colors.white, width: 2.5),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x662196F3),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                            // Report pins
                            MarkerLayer(
                              markers: withCoords.map((r) {
                                final lat =
                                    (r['latitude'] as num).toDouble();
                                final lng =
                                    (r['longitude'] as num).toDouble();
                                final color = _pinColor(r);
                                final isSos = r['source'] == 'sos';

                                return Marker(
                                  point: LatLng(lat, lng),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () => _showDetail(r),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Glow
                                        Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                color.withOpacity(0.2),
                                          ),
                                        ),
                                        // Pin
                                        Container(
                                          width: 20, height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color,
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color
                                                    .withOpacity(0.5),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ],
                                          ),
                                        ),
                                        // SOS badge
                                        if (isSos)
                                          Positioned(
                                            top: 0, right: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFFE53935),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        3),
                                              ),
                                              child: const Text('SOS',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 6,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            // Attribution
                            const RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                    'OpenStreetMap contributors'),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Legend ──
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _legendItem('You are here', const Color(0xFF1565C0),
                        isCircle: true),
                    const SizedBox(width: 8),
                    _legendItem('Pending', const Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    _legendItem('Responding', const Color(0xFF2196F3)),
                    const SizedBox(width: 8),
                    _legendItem('Resolved', const Color(0xFF4CAF50)),
                  ],
                ),
              ),
            ),

            // ── Report list ──
            Expanded(
              flex: 2,
              child: _reports.isEmpty && !_loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: const Icon(Icons.map_outlined,
                                color: Color(0xFF333333), size: 24),
                          ),
                          const SizedBox(height: 12),
                          const Text('No reports on the map yet',
                              style: TextStyle(
                                  color: Color(0xFF555555), fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Submit a report to see it pinned here',
                              style: TextStyle(
                                  color: Color(0xFF333333), fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: _reports.length,
                      itemBuilder: (_, i) => _buildReportTile(_reports[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, {bool isCircle = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isCircle
                ? Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF666666), fontSize: 11)),
      ],
    );
  }

  Widget _buildReportTile(Map<String, dynamic> report) {
    final type = report['emergency_type'] ?? report['type'] ?? 'General';
    final status = report['status'] ?? 'pending';
    final isSos = report['source'] == 'sos';
    final statusData = _statusConfig[status] ?? _statusConfig['pending']!;
    final typeData = _typeConfig[type] ?? _typeConfig['General']!;
    final lat = (report['latitude'] as num?)?.toDouble();
    final lng = (report['longitude'] as num?)?.toDouble();

    return GestureDetector(
      onTap: () {
        // Fly map to this report then show detail
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 17);
        }
        _showDetail(report);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSos && status == 'pending'
                ? const Color(0xFFE53935).withOpacity(0.3)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (typeData['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeData['icon'] as IconData,
                  color: typeData['color'] as Color, size: 18),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (isSos) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('SOS',
                              style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusData['bg'] as Color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(statusData['label'] as String,
                            style: TextStyle(
                                color: statusData['color'] as Color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    report['location'] ?? report['address'] ?? 'Location unavailable',
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Color(0xFF333333), size: 18),
          ],
        ),
      ),
    );
  }
}