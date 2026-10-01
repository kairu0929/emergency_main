import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:first_flutter_project/login_page.dart';
import 'package:first_flutter_project/auth_serv.dart';

class ResponderProfilePage extends StatefulWidget {
  const ResponderProfilePage({Key? key}) : super(key: key);

  @override
  State<ResponderProfilePage> createState() => _ResponderProfilePageState();
}

class _ResponderProfilePageState extends State<ResponderProfilePage> {
  final _supabase = Supabase.instance.client;
  final authService = AuthService();
  int _pending = 0;
  int _responding = 0;
  int _resolved = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final sos = await _supabase
          .from('sos_emergency_reports')
          .select('status')
          .eq('responder_id', userId);

      final reports = await _supabase
          .from('reports')
          .select('status')
          .eq('responder_id', userId);

      final all = [
        ...List<Map<String, dynamic>>.from(sos),
        ...List<Map<String, dynamic>>.from(reports),
      ];

      if (mounted) {
        setState(() {
          _pending = all.where((r) => r['status'] == 'pending').length;
          _responding = all.where((r) => r['status'] == 'responding').length;
          _resolved = all.where((r) => r['status'] == 'resolved').length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = authService.getCurrentUserFirstName() ?? 'Responder';
    final lastName = authService.getCurrentUserLastName() ?? '';
    final phone = authService.getCurrentUserPhone() ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header ──
              const Text(
                'MY PROFILE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Cluster 6 — Dasmariñas, Cavite',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),

              const SizedBox(height: 28),

              // ── Profile card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935).withOpacity(0.12),
                        border: Border.all(
                          color: const Color(0xFFE53935).withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFFE53935),
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE53935).withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        '🚑  RESPONDER — CLUSTER 6',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF2A2A2A)),
                    const SizedBox(height: 14),

                    // Info rows
                    _infoRow(Icons.phone_outlined, 'Phone', phone),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.email_outlined,
                      'Email',
                      _supabase.auth.currentUser?.email ?? '—',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.location_on_outlined,
                      'Assignment',
                      'Cluster 6, City of Dasmariñas',
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.verified_user_outlined,
                      'Status',
                      'Active',
                      valueColor: const Color(0xFF4CAF50),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Stats ──
              const Text(
                'YOUR STATS',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),

              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE53935), strokeWidth: 2))
                  : Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Pending',
                            value: '$_pending',
                            color: const Color(0xFFFF9800),
                            icon: Icons.hourglass_empty_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            label: 'Responding',
                            value: '$_responding',
                            color: const Color(0xFF2196F3),
                            icon: Icons.directions_run_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            label: 'Resolved',
                            value: '$_resolved',
                            color: const Color(0xFF4CAF50),
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 20),

              // ── Settings section ──
              const Text(
                'SETTINGS',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  children: [
                    _settingRow(
                      icon: Icons.notifications_outlined,
                      label: 'Push Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (_) {},
                        activeColor: const Color(0xFFE53935),
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                      ),
                    ),
                    const Divider(color: Color(0xFF2A2A2A), height: 0),
                    _settingRow(
                      icon: Icons.lock_outline,
                      label: 'Change Password',
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF444444), size: 20),
                      onTap: () {},
                    ),
                    const Divider(color: Color(0xFF2A2A2A), height: 0),
                    _settingRow(
                      icon: Icons.info_outline,
                      label: 'About',
                      trailing: const Icon(Icons.chevron_right,
                          color: Color(0xFF444444), size: 20),
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Logout ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _supabase.auth.signOut();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'LOGOUT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = const Color(0xFFCCCCCC),
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF555555), size: 16),
        const SizedBox(width: 12),
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: valueColor, fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF555555), size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
