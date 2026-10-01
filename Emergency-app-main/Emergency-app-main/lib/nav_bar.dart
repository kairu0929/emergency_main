import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:first_flutter_project/home_page.dart';
import 'package:first_flutter_project/location_page.dart';
import 'package:first_flutter_project/my_reports.dart';
import 'package:first_flutter_project/report_page.dart';
import 'package:flutter/material.dart';
 
class NavBar extends StatefulWidget {
  const NavBar({Key? key}) : super(key: key);
 
  @override
  State<NavBar> createState() => _NavBarState();
}
 
class _NavBarState extends State<NavBar> {
  int currentIndex = 0;
 
  final screens = [
    const HomePage(),
    const ReportPage(),
    const MyReportsPage(),
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
          Icon(Icons.home_outlined, color: Colors.white, size: 26),
          Icon(Icons.photo_camera_outlined, color: Colors.white, size: 26),
          Icon(Icons.assignment_outlined, color: Colors.white, size: 26), // ← third tab
        ],
      ),
    );
  }
}
 