import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

Future<AuthResponse> signUp(
  String firstName,
  String lastName,
  String phoneNumber,
  String email,
  String password,
  File? voterIdFile,
) async {

  print('Step 1 — Creating auth account for: $email');

  final response = await _supabase.auth.signUp(
    email: email,
    password: password,
    data: {
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
    },
  );

  print('Step 1 done — user: ${response.user?.id}');

  if (response.user != null) {
    final userId = response.user!.id;

    print('Step 2 — Signing in to get session');
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    print('Step 2 done — session active');

    String? voterIdPath;

    if (voterIdFile != null) {
  print('Step 3 — Uploading voter ID');
  try {
    final fileExt = voterIdFile.path.split('.').last;
    final filePath =
        'voter_id_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage
        .from('voter_id') // ← make sure this matches exactly
        .upload(
          filePath,
          voterIdFile,
          fileOptions: const FileOptions(upsert: true),
        );

    voterIdPath = filePath;
    print('Step 3 done — path: $voterIdPath');
  } catch (e) {
    print('Step 3 FAILED — $e'); // ← will tell us exact storage error
    // Don't rethrow — skip photo and still create the account
    voterIdPath = null;
  }
}

    print('Step 4 — Inserting into users_flutter');
    await _supabase.from('users_flutter').insert({
      'id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'email': email,
      'voter_picture': voterIdPath,
      'user_type': "resident",
    });
    print('Step 4 done — row inserted');
  }

  return response;
}

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  String? getCurrentUserFirstName() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.userMetadata?['first_name'];
  }

  String? getCurrentUserLastName() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.userMetadata?['last_name'];
  }

  String? getCurrentUserPhone() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.userMetadata?['phone_number'];
  }

  Future<void> reportEmergency({
  required String emergency_type,
  required String description,
  required double latitude,
  required double longitude,
  String? location,
  File? photo,
  }) async {
  
  final userId = _supabase.auth.currentUser?.id;


  if (userId == null) {
    throw Exception('User not logged in');
  }

  String? photoPath;

  if (photo != null) {
  final fileExt = photo.path.split('.').last;
  final filePath =
      'emergency_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

  await _supabase.storage
      .from('emergency_photos')
      .upload(filePath, photo);

  photoPath = filePath;
}

await _supabase.from('reports').insert({
  'user_id': userId,
  'description': description,
  'latitude': latitude,
  'longitude': longitude,
  'location': location ?? 'Unknown',
  'photo': photoPath,
  'status': "pending",
  
});
}

Future<void> sosEmergency({
  required String emergency_type,
  required double latitude,
  required double longitude,
  String? location,
}) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not logged in');
  }

  await supabase.from('sos_emergency_reports').insert({
    'user_id': userId,
    'emergency_type': emergency_type,
    'latitude': latitude,
    'longitude': longitude,
    'location': location ?? 'Unknown',
    'status': "pending",
  });
}
}