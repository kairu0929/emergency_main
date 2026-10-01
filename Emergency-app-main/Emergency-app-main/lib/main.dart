import 'package:first_flutter_project/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: "https://ciosraiwrvudsyzakoio.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpb3NyYWl3cnZ1ZHN5emFrb2lvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1ODAxMTMsImV4cCI6MjA5MjE1NjExM30.Vkv9a0K1j74V45Y3ehoWqE6JpX4j-4GrsrDKjLSzQLA",
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key : key);
@override 
  State<MyApp> createState() => _MyAppState();

}  
  class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginPage(),
      );
  }
}