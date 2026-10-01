import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResponderMapPage extends StatefulWidget {
  const ResponderMapPage({Key? key}) : super(key: key);

  @override
  State<ResponderMapPage> createState() => _ResponderMapPageState();
}

class _ResponderMapPageState extends State<ResponderMapPage> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _currentUserId;
  Map<String, dynamic>? _responderProfile;

  // Cluster 6, City of Dasmariñas, Cavite
  static const LatLng _cluster6 = LatLng(14.3175, 120.9705);

  static const Map<String, Map<String, dynamic>> _statusConfig = {
    'pending': {'label': 'Pending', 'color': Color(0xFFFF9800), 'bg': Color(0x1FFF9800)},
    'responding': {'label': 'Responding', 'color': Color(0xFF2196F3), 'bg': Color(0x1F2196F3)},
    'resolved': {'label': 'Resolved', 'color': Color(0xFF4CAF50), 'bg': Color(0x1F4CAF50)},
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
    _fetchResponderProfile().then((_) => _fetchReports());
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String? _photoUrl(Map<String, dynamic> r) {
    final raw = (r['photo_url'] ?? r['photo'])?.toString();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return _supabase.storage.from('emergency_photos').getPublicUrl(raw);
  }

  bool _isMine(Map<String, dynamic> r) =>
      r['responder_id'] != null && r['responder_id'] == _currentUserId;

  // ── Data fetching ────────────────────────────────────────────────────

  Future<void> _fetchResponderProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    _currentUserId = userId;

    try {
      final profile = await _supabase
          .from('responders')
          .select('id, full_name, specialties, is_active, cluster')
          .eq('id', userId)
          .maybeSingle();

      final specialties = (profile?['specialties'] as List?)
              ?.map((s) => s.toString().trim())
              .toList() ??
          [];

      debugPrint('RESPONDER PROFILE: $profile');
      debugPrint('SPECIALTIES: $specialties');

      if (mounted) setState(() => _responderProfile = profile);
    } catch (e) {
      debugPrint('Responder profile fetch error: $e');
    }
  }

  Future<void> _fetchReports() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final specialties =
          (_responderProfile?['specialties'] as List?)?.cast<String>() ?? [];

      final sos = await _supabase
          .from('sos_emergency_reports')
          .select()
          .eq('responder_id', userId)
          .neq('status', 'resolved');

      final reports = await _supabase
          .from('reports')
          .select()
          .eq('responder_id', userId)
          .neq('status', 'resolved');

      List<Map<String, dynamic>> unclaimedSos = [];
      List<Map<String, dynamic>> unclaimedReports = [];

      if (specialties.isNotEmpty) {
        unclaimedSos = List<Map<String, dynamic>>.from(await _supabase
            .from('sos_emergency_reports')
            .select()
            .inFilter('emergency_type', specialties)
            .filter('responder_id', 'is', null)
            .neq('status', 'resolved'));

        unclaimedReports = List<Map<String, dynamic>>.from(await _supabase
            .from('reports')
            .select()
            .inFilter('emergency_type', specialties)
            .filter('responder_id', 'is', null)
            .neq('status', 'resolved'));
      }

      debugPrint('SPECIALTIES: $specialties');
      debugPrint('UNCLAIMED SOS: ${unclaimedSos.length}, UNCLAIMED REPORTS: ${unclaimedReports.length}');

      final combined = [
        ...List<Map<String, dynamic>>.from(sos).map((r) => {...r, 'source': 'sos'}),
        ...List<Map<String, dynamic>>.from(reports).map((r) => {...r, 'source': 'report'}),
        ...unclaimedSos.map((r) => {...r, 'source': 'sos'}),
        ...unclaimedReports.map((r) => {...r, 'source': 'report'}),
      ];

      if (mounted) {
        setState(() {
          _reports = combined;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Map fetch error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> report, String status) async {
    try {
      final table = report['source'] == 'sos' ? 'sos_emergency_reports' : 'reports';
      final userId = _supabase.auth.currentUser?.id;

      final query = _supabase.from(table).update({
        'status': status,
        if (status == 'responding') 'responder_id': userId,
      }).eq('id', report['id']);

      final result = status == 'responding'
          ? await query.filter('responder_id', 'is', null).select()
          : await query.select();

      if (status == 'responding' && result.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Someone else already claimed this report')),
        );
      }

      await _fetchReports();
    } catch (e) {
      debugPrint('Update error: $e');
    }
  }

  // ── Popup ────────────────────────────────────────────────────────────

  void _showReportPopup(Map<String, dynamic> report) {
    final type = report['emergency_type'] ?? report['type'] ?? 'General';
    final status = report['status'] ?? 'pending';
    final isSos = report['source'] == 'sos';
    final statusData = _statusConfig[status] ?? _statusConfig['pending']!;
    final typeData = _typeConfig[type] ?? _typeConfig['General']!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  color: isSos ? const Color(0xFFE53935) : const Color(0xFF888888),
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  width: 44, height: 44,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        report['location'] ?? report['address'] ?? 'Location unavailable',
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusData['bg'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusData['label'] as String,
                      style: TextStyle(
                          color: statusData['color'] as Color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_isMine(report))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Icon(Icons.directions_run_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 6),
                    Text('Assigned to you',
                        style: TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

            Row(
              children: [
                const Icon(Icons.gps_fixed_outlined, color: Color(0xFF555555), size: 14),
                const SizedBox(width: 8),
                Text(
                  report['latitude'] != null
                      ? '${(report['latitude'] as num).toStringAsFixed(5)}, ${(report['longitude'] as num).toStringAsFixed(5)}'
                      : 'No coordinates',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),

            if (report['description'] != null &&
                report['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined, color: Color(0xFF555555), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(report['description'],
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                  ),
                ],
              ),
            ],

            if (_photoUrl(report) != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _photoUrl(report)!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Color(0xFF333333), size: 28),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (status == 'pending')
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateStatus(report, 'responding');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('You are now responding to this incident'),
                          backgroundColor: const Color(0xFF2196F3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.directions_run_rounded, size: 18),
                  label: const Text('ON MY WAY',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            else if (status == 'responding')
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateStatus(report, 'resolved');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Incident marked as resolved'),
                          backgroundColor: const Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('MARK AS RESOLVED',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day} • $h:$m $ampm';
  }

  Color _markerColor(Map<String, dynamic> r) {
    if (r['status'] == 'resolved') return const Color(0xFF4CAF50);
    final type = r['emergency_type'] ?? r['type'] ?? 'General';
    return (_typeConfig[type]?['color'] as Color?) ?? const Color(0xFF888888);
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('INCIDENT MAP',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2)),
                      Text('Cluster 6 — Dasmariñas, Cavite',
                          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _fetchReports,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Icon(Icons.refresh_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Legend pills ──
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _legendPill('Fire', const Color(0xFFE53935)),
                    const SizedBox(width: 6),
                    _legendPill('Medical', const Color(0xFF2196F3)),
                    const SizedBox(width: 6),
                    _legendPill('Crime', const Color(0xFF9C27B0)),
                    const SizedBox(width: 6),
                    _legendPill('Disaster', const Color(0xFFFF9800)),
                    const SizedBox(width: 6),
                    _legendPill('Resolved', const Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    _assignedLegendPill(),
                  ],
                ),
              ),
            ),

            // ── Map ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _loading
                      ? Container(
                          color: const Color(0xFF1A1A1A),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFE53935)),
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
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.first_flutter_project',
                            ),

                            MarkerLayer(
                              markers: _reports
                                  .where((r) => r['latitude'] != null && r['longitude'] != null)
                                  .map((r) {
                                final lat = (r['latitude'] as num).toDouble();
                                final lng = (r['longitude'] as num).toDouble();
                                final color = _markerColor(r);
                                final isSos = r['source'] == 'sos';
                                final isMine = _isMine(r);

                                return Marker(
                                  point: LatLng(lat, lng),
                                  width: isMine ? 50 : 40,
                                  height: isMine ? 50 : 40,
                                  child: GestureDetector(
                                    onTap: () => _showReportPopup(r),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (isMine)
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2.5),
                                              color: color.withOpacity(0.25),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: color.withOpacity(0.2),
                                            ),
                                          ),
                                        Container(
                                          width: isMine ? 24 : 20,
                                          height: isMine ? 24 : 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: color,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: isMine ? 2.5 : 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withOpacity(isMine ? 0.8 : 0.5),
                                                blurRadius: isMine ? 10 : 6,
                                                spreadRadius: isMine ? 2 : 1,
                                              ),
                                            ],
                                          ),
                                          child: isMine
                                              ? const Icon(Icons.directions_run_rounded,
                                                  color: Colors.white, size: 14)
                                              : null,
                                        ),
                                        if (isSos)
                                          Positioned(
                                            top: isMine ? -2 : 0,
                                            right: isMine ? -2 : 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 3, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE53935),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: const Text('SOS',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 6,
                                                      fontWeight: FontWeight.w800)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution('OpenStreetMap contributors'),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_reports.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _reports.length,
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    final type = r['emergency_type'] ?? r['type'] ?? 'General';
                    final typeData = _typeConfig[type] ?? _typeConfig['General']!;
                    final status = r['status'] ?? 'pending';
                    final statusData = _statusConfig[status] ?? _statusConfig['pending']!;
                    final lat = (r['latitude'] as num?)?.toDouble();
                    final lng = (r['longitude'] as num?)?.toDouble();
                    final isMine = _isMine(r);

                    return GestureDetector(
                      onTap: () {
                        if (lat != null && lng != null) {
                          _mapController.move(LatLng(lat, lng), 17);
                        }
                        _showReportPopup(r);
                      },
                      child: Container(
                        width: 180,
                        margin: const EdgeInsets.only(right: 10, bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMine ? Colors.white.withOpacity(0.5) : const Color(0xFF2A2A2A),
                            width: isMine ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(typeData['icon'] as IconData,
                                    color: typeData['color'] as Color, size: 14),
                                const SizedBox(width: 6),
                                Text(type,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (isMine)
                                  const Icon(Icons.directions_run_rounded,
                                      color: Colors.white, size: 12)
                                else
                                  Container(
                                    width: 7, height: 7,
                                    decoration: BoxDecoration(
                                      color: statusData['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              r['location'] ?? r['address'] ?? 'No address',
                              style: const TextStyle(color: Color(0xFF666666), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(_formatDate(r['created_at']),
                                style: const TextStyle(color: Color(0xFF444444), fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_reports.isEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
                      SizedBox(width: 10),
                      Text('No active incidents assigned to you',
                          style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _legendPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _assignedLegendPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_run_rounded, color: Colors.white, size: 10),
          SizedBox(width: 5),
          Text('Assigned to me',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}