import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({Key? key}) : super(key: key);
 
  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}
 
class _MyReportsPageState extends State<MyReportsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
 
  // Status config
  static const Map<String, Map<String, dynamic>> _statusConfig = {
    'pending': {
      'label': 'Pending',
      'color': Color(0xFFFF9800),
      'icon': Icons.hourglass_empty_rounded,
      'bg': Color(0x1FFF9800),
    },
    'responding': {
      'label': 'Responding',
      'color': Color(0xFF2196F3),
      'icon': Icons.directions_run_rounded,
      'bg': Color(0x1F2196F3),
    },
    'resolved': {
      'label': 'Resolved',
      'color': Color(0xFF4CAF50),
      'icon': Icons.check_circle_outline_rounded,
      'bg': Color(0x1F4CAF50),
    },
  };
 
  // Emergency type config
  static const Map<String, Map<String, dynamic>> _typeConfig = {
    'Fire': {
      'color': Color(0xFFE53935),
      'icon': Icons.local_fire_department_outlined,
    },
    'Medical': {
      'color': Color(0xFF2196F3),
      'icon': Icons.local_hospital_outlined,
    },
    'Crime': {
      'color': Color(0xFF9C27B0),
      'icon': Icons.security_outlined,
    },
    'Disaster': {
      'color': Color(0xFFFF9800),
      'icon': Icons.warning_amber_outlined,
    },
    'General': {
      'color': Color(0xFF888888),
      'icon': Icons.report_outlined,
    },
  };
 
  @override
  void initState() {
    super.initState();
    _fetchReports();
    _listenForUpdates();
  }
 
  Future<void> _fetchReports() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
 
      final data = await _supabase
          .from('emergency_reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
 
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
 
  // Real-time listener — updates status automatically
  void _listenForUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
 
    _supabase
        .from('emergency_reports')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen((data) {
          if (mounted) {
            setState(() {
              _reports = List<Map<String, dynamic>>.from(data);
              _loading = false;
            });
          }
        });
  }
 
  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return 'Unknown';
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day}, ${dt.year} • $hour:$min $ampm';
  }
 
  void _openReportDetail(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportDetailSheet(
        report: report,
        statusConfig: _statusConfig,
        typeConfig: _typeConfig,
        formatDate: _formatDate,
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MY REPORTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loading
                        ? 'Loading...'
                        : '${_reports.length} report${_reports.length != 1 ? 's' : ''} submitted',
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 13),
                  ),
                ],
              ),
            ),
 
            // ── Status summary pills ──
            if (!_loading && _reports.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 16),
                child: Row(
                  children: [
                    _summaryPill('Pending',
                        _reports.where((r) => r['status'] == 'pending').length,
                        const Color(0xFFFF9800)),
                    const SizedBox(width: 8),
                    _summaryPill(
                        'Responding',
                        _reports
                            .where((r) => r['status'] == 'responding')
                            .length,
                        const Color(0xFF2196F3)),
                    const SizedBox(width: 8),
                    _summaryPill(
                        'Resolved',
                        _reports
                            .where((r) => r['status'] == 'resolved')
                            .length,
                        const Color(0xFF4CAF50)),
                  ],
                ),
              ),
 
            // ── Report list ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE53935)))
                  : _reports.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchReports,
                          color: const Color(0xFFE53935),
                          backgroundColor: const Color(0xFF1A1A1A),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: _reports.length,
                            itemBuilder: (context, index) {
                              return _buildReportCard(_reports[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _summaryPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
 
  Widget _buildReportCard(Map<String, dynamic> report) {
    final String status = report['status'] ?? 'pending';
    final String type = report['emergency_type'] ?? 'General';
    final statusData =
        _statusConfig[status] ?? _statusConfig['pending']!;
    final typeData = _typeConfig[type] ?? _typeConfig['General']!;
 
    return GestureDetector(
      onTap: () => _openReportDetail(report),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (typeData['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeData['icon'] as IconData,
                  color: typeData['color'] as Color, size: 22),
            ),
 
            const SizedBox(width: 14),
 
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusData['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusData['icon'] as IconData,
                                color: statusData['color'] as Color,
                                size: 11),
                            const SizedBox(width: 4),
                            Text(
                              statusData['label'] as String,
                              style: TextStyle(
                                color: statusData['color'] as Color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    report['location'] ?? 'Location unavailable',
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(report['created_at']),
                    style: const TextStyle(
                        color: Color(0xFF444444), fontSize: 11),
                  ),
                ],
              ),
            ),
 
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: Color(0xFF333333), size: 20),
          ],
        ),
      ),
    );
  }
 
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Icon(Icons.assignment_outlined,
                color: Color(0xFF333333), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reports yet',
            style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your submitted reports will appear here',
            style: TextStyle(color: Color(0xFF333333), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
 
// ── Report Detail Bottom Sheet ─────────────────────────────────────────────
 
class _ReportDetailSheet extends StatelessWidget {
  final Map<String, dynamic> report;
  final Map<String, Map<String, dynamic>> statusConfig;
  final Map<String, Map<String, dynamic>> typeConfig;
  final String Function(String?) formatDate;
 
  const _ReportDetailSheet({
    required this.report,
    required this.statusConfig,
    required this.typeConfig,
    required this.formatDate,
  });
 
  @override
  Widget build(BuildContext context) {
    final String status = report['status'] ?? 'pending';
    final String type = report['emergency_type'] ?? 'General';
    final statusData = statusConfig[status] ?? statusConfig['pending']!;
    final typeData = typeConfig[type] ?? typeConfig['General']!;
 
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
 
          const SizedBox(height: 20),
 
          // Type + status row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      (typeData['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeData['icon'] as IconData,
                    color: typeData['color'] as Color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$type Emergency',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(report['created_at']),
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusData['bg'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusData['label'] as String,
                  style: TextStyle(
                    color: statusData['color'] as Color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
 
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1E1E1E)),
          const SizedBox(height: 16),
 
          // Details
          _detailRow(Icons.location_on_outlined,
              report['location'] ?? 'Location unavailable'),
          const SizedBox(height: 12),
          _detailRow(
            Icons.gps_fixed_outlined,
            report['latitude'] != null && report['longitude'] != null
                ? '${(report['latitude'] as num).toStringAsFixed(6)}, ${(report['longitude'] as num).toStringAsFixed(6)}'
                : 'Coordinates unavailable',
          ),
 
          if (report['description'] != null &&
              report['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _detailRow(Icons.notes_outlined, report['description']),
          ],
 
          // Status timeline
          const SizedBox(height: 20),
          const Text(
            'STATUS TIMELINE',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          _statusTimeline(status),
 
          // Photo
          if (report['photo_url'] != null) ...[
            const SizedBox(height: 20),
            const Text(
              'PHOTO EVIDENCE',
              style: TextStyle(
                color: Color(0xFF444444),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                report['photo_url'],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: const Color(0xFF1A1A1A),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Color(0xFF333333), size: 32),
                  ),
                ),
              ),
            ),
          ],
 
          const SizedBox(height: 8),
        ],
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
          child: Text(
            text,
            style: const TextStyle(
                color: Color(0xFFAAAAAA), fontSize: 13, height: 1.4),
          ),
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
 
    return Column(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isCompleted = i <= currentIndex;
        final isCurrent = i == currentIndex;
        final stepStatus = step['key']!;
        final config = {
          'pending': const Color(0xFFFF9800),
          'responding': const Color(0xFF2196F3),
          'resolved': const Color(0xFF4CAF50),
        };
        final color = isCompleted
            ? config[stepStatus]!
            : const Color(0xFF2A2A2A);
 
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
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
                      ? Icon(Icons.check,
                          color: color, size: 12)
                      : null,
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 1,
                    height: 28,
                    color: i < currentIndex
                        ? config[steps[i + 1]['key']!]!
                            .withOpacity(0.3)
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
                  Text(
                    step['label']!,
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.white
                          : const Color(0xFF333333),
                      fontSize: 13,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step['sub']!,
                    style: TextStyle(
                      color: isCompleted ? color : const Color(0xFF2A2A2A),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}