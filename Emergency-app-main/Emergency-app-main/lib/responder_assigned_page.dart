import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResponderAssignedPage extends StatefulWidget {
  const ResponderAssignedPage({Key? key}) : super(key: key);

  @override
  State<ResponderAssignedPage> createState() => _ResponderAssignedPageState();
}

class _ResponderAssignedPageState extends State<ResponderAssignedPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  late TabController _tabController;

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
  _tabController = TabController(length: 3, vsync: this);
  _fetchResponderProfile().then((_) => _fetchReports()); // only this one
  _listenForUpdates();
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _responderProfile;

Future<void> _fetchResponderProfile() async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return;

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

      final specialtyFilter =
      '(${specialties.map((s) => '"$s"').join(",")})';

      // Fetch from both tables where this responder is assigned
      final sos = await _supabase
          .from('sos_emergency_reports')
          .select()
          .eq('responder_id', userId)
          .order('created_at', ascending: false);

      final reports = await _supabase
          .from('reports')
          .select()
          .eq('responder_id', userId)
          .order('created_at', ascending: false);
      debugPrint('RESPONDER PROFILE: $_responderProfile');
      debugPrint('SOS results: ${sos.length}');
      debugPrint('SOS data: $sos');
      debugPrint('CURRENT USER ID: $userId');
      debugPrint('REPORT results: ${reports.length}');
      debugPrint('REPORT data: $reports');

      final unclaimedSos = await _supabase
        .from('sos_emergency_reports')
        .select()
        .inFilter('emergency_type', specialties)
        .filter('responder_id', 'is', null)
        .neq('status', 'resolved');

      final unclaimedReports = await _supabase
        .from('reports')
        .select()
        .inFilter('emergency_type', specialties)
        .filter('responder_id', 'is', null)
        .neq('status', 'resolved');
      debugPrint('UNCLAIMED REPORTS: ${unclaimedReports.length}');
      debugPrint('$unclaimedReports');
      debugPrint('SPECIALTIES: $specialties');

      final test = await _supabase
    .from('reports')
    .select()
    .filter('responder_id', 'is', null);

    debugPrint('TEST NULL RESPONDER: ${test.length}');
    debugPrint('TEST DATA: $test');


      final combined = [
        ...List<Map<String, dynamic>>.from(sos).map((r) => {...r, 'source': 'sos'}),
        ...List<Map<String, dynamic>>.from(reports).map((r) => {...r, 'source': 'report'}),
        ...unclaimedSos.map((r) => {...r, 'source': 'sos'}),
        ...unclaimedReports.map((r) => {...r, 'source': 'report'}),
      ];

      // Sort by created_at descending
      combined.sort((a, b) =>
          (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

      if (mounted) {
        setState(() {
          _reports = combined;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .from('sos_emergency_reports')
        .stream(primaryKey: ['id'])
        .eq('responder_id', userId)
        .listen((_) => _fetchReports());

    _supabase
        .from('reports')
        .stream(primaryKey: ['id'])
        .eq('responder_id', userId)
        .listen((_) => _fetchReports());
  }

  Future<void> _updateStatus(Map<String, dynamic> report, String newStatus) async {
    try {
      final table = report['source'] == 'sos'
          ? 'sos_emergency_reports'
          : 'reports';

      await _supabase
          .from(table)
          .update({'status': newStatus})
          .eq('id', report['id']);

      await _fetchReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'responding'
                  ? 'Status updated — you are now responding'
                  : 'Incident marked as resolved',
            ),
            backgroundColor: newStatus == 'resolved'
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2196F3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
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

  List<Map<String, dynamic>> _filtered(String status) =>
      _reports.where((r) => r['status'] == status).toList();

  void _openDetail(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportDetailSheet(
        report: report,
        statusConfig: _statusConfig,
        typeConfig: _typeConfig,
        formatDate: _formatDate,
        onUpdateStatus: _updateStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _filtered('pending');
    final responding = _filtered('responding');
    final resolved = _filtered('resolved');

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'RESCUE LINK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Responder dashboard',
                        style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Active assignments badge
                  if (responding.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x1F2196F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${responding.length} active',
                            style: const TextStyle(
                              color: Color(0xFF2196F3),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Summary pills ──
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  _pill('${pending.length} Pending', const Color(0xFFFF9800)),
                  const SizedBox(width: 8),
                  _pill('${responding.length} Responding', const Color(0xFF2196F3)),
                  const SizedBox(width: 8),
                  _pill('${resolved.length} Resolved', const Color(0xFF4CAF50)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabs ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF666666),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                tabs: [
                  Tab(text: 'Pending (${pending.length})'),
                  Tab(text: 'Active (${responding.length})'),
                  Tab(text: 'Done (${resolved.length})'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab content ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE53935)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(pending),
                        _buildList(responding),
                        _buildList(resolved),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Icon(Icons.assignment_outlined,
                  color: Color(0xFF333333), size: 28),
            ),
            const SizedBox(height: 14),
            const Text('No reports here',
                style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Check other tabs for updates',
                style: TextStyle(color: Color(0xFF333333), fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReports,
      color: const Color(0xFFE53935),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final type = report['emergency_type'] ?? report['type'] ?? 'General';
    final isSos = report['source'] == 'sos';
    final statusData = _statusConfig[status] ?? _statusConfig['pending']!;
    final typeData = _typeConfig[type] ?? _typeConfig['General']!;

    return GestureDetector(
      onTap: () => _openDetail(report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == 'pending' && isSos
                ? const Color(0xFFE53935).withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Stack(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: (typeData['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(typeData['icon'] as IconData,
                      color: typeData['color'] as Color, size: 22),
                ),
                if (isSos)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusData['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusData['icon'] as IconData,
                                color: statusData['color'] as Color, size: 11),
                            const SizedBox(width: 4),
                            Text(statusData['label'] as String,
                                style: TextStyle(
                                    color: statusData['color'] as Color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    report['location'] ?? report['address'] ?? 'Location unavailable',
                    style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(_formatDate(report['created_at']),
                      style: const TextStyle(color: Color(0xFF444444), fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF333333), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Report Detail Bottom Sheet ────────────────────────────────────────────────

class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> report;
  final Map<String, Map<String, dynamic>> statusConfig;
  final Map<String, Map<String, dynamic>> typeConfig;
  final String Function(String?) formatDate;
  final Future<void> Function(Map<String, dynamic>, String) onUpdateStatus;

  const _ReportDetailSheet({
    required this.report,
    required this.statusConfig,
    required this.typeConfig,
    required this.formatDate,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = report['status'] ?? 'pending';
    final type = report['emergency_type'] ?? report['type'] ?? 'General';
    final isSos = report['source'] == 'sos';
    final statusData = statusConfig[status] ?? statusConfig['pending']!;
    final typeData = typeConfig[type] ?? typeConfig['General']!;

    return Container(
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
                  color: isSos ? const Color(0xFFE53935) : const Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Type + status row
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
                      Text(formatDate(report['created_at']),
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

            // Details
            _row(Icons.location_on_outlined,
                report['location'] ?? report['address'] ?? 'Location unavailable'),
            const SizedBox(height: 10),
            _row(
              Icons.gps_fixed_outlined,
              report['latitude'] != null && report['longitude'] != null
                  ? '${(report['latitude'] as num).toStringAsFixed(6)}, ${(report['longitude'] as num).toStringAsFixed(6)}'
                  : 'Coordinates unavailable',
            ),

            if (report['description'] != null &&
                report['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _row(Icons.notes_outlined, report['description']),
            ],

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

            const SizedBox(height: 24),

            // Action buttons
            if (status == 'pending') ...[
              _actionBtn(
                label: 'ON MY WAY',
                color: const Color(0xFF2196F3),
                icon: Icons.directions_run_rounded,
                onTap: () {
                  Navigator.pop(context);
                  onUpdateStatus(report, 'responding');
                },
              ),
              const SizedBox(height: 10),
              _outlineBtn(label: 'Close', onTap: () => Navigator.pop(context)),
            ] else if (status == 'responding') ...[
              _actionBtn(
                label: 'MARK AS RESOLVED',
                color: const Color(0xFF4CAF50),
                icon: Icons.check_circle_outline_rounded,
                onTap: () {
                  Navigator.pop(context);
                  onUpdateStatus(report, 'resolved');
                },
              ),
              const SizedBox(height: 10),
              _outlineBtn(label: 'Close', onTap: () => Navigator.pop(context)),
            ] else ...[
              _outlineBtn(label: 'Close', onTap: () => Navigator.pop(context)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
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

  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _outlineBtn({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF666666),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Color(0xFF666666))),
      ),
    );
  }
}
