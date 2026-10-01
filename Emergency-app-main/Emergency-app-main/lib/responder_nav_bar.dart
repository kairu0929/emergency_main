import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:first_flutter_project/responder_assigned_page.dart';
import 'package:first_flutter_project/responder_map_page.dart';
import 'package:first_flutter_project/responder_profile_page.dart';
import 'package:flutter/material.dart';

class ResponderNavBar extends StatefulWidget {
  const ResponderNavBar({Key? key}) : super(key: key);

  @override
  State<ResponderNavBar> createState() => _ResponderNavBarState();
}

class _ResponderNavBarState extends State<ResponderNavBar> {
  int currentIndex = 0;

  final screens = [
    const ResponderAssignedPage(),
    const ResponderMapPage(),
    const ResponderProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: screens[currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        index: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        backgroundColor: const Color(0xFF0D0D0D),
        color: const Color(0xFF1A1A1A),
        buttonBackgroundColor: const Color(0xFFE53935),
        animationDuration: const Duration(milliseconds: 350),
        animationCurve: Curves.easeInOut,
        height: 60,
        items: const [
          Icon(Icons.assignment_outlined, color: Colors.white, size: 26),
          Icon(Icons.map_outlined, color: Colors.white, size: 26),
          Icon(Icons.person_outline, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}
