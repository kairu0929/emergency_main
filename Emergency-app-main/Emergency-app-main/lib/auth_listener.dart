import 'package:first_flutter_project/login_page.dart';
import 'package:first_flutter_project/nav_bar.dart';
import 'package:first_flutter_project/responder_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthListener extends StatefulWidget {
  const AuthListener({super.key});

  @override
  State<AuthListener> createState() => _AuthListenerState();
}

class _AuthListenerState extends State<AuthListener> {
  final _supabase = Supabase.instance.client;

  Future<String> _getUserType(String userId) async {
    try {
      final data = await _supabase
          .from('users_flutter')
          .select('user_type')
          .eq('id', userId)
          .single();
      print('user_type fetched: ${data['user_type']}');
      return data['user_type'] as String? ?? 'resident';
    } catch (e) {
      print('getUserType error: $e');
      debugPrint('Error fetching user type: $e');
      return 'resident';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            ),
          );
        }

        final session =
            snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return FutureBuilder<String>(
            future: _getUserType(session.user.id),
            builder: (context, snap) {
              // While fetching user type show loading
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0D0D0D),
                  body: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE53935)),
                  ),
                );
              }

              final userType = snap.data ?? 'resident';

              if (userType == 'responder') {
                return const ResponderNavBar();
              } else {
                return const NavBar();
              }
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}