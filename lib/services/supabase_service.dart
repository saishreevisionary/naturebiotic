import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  // Sign in logic
  // For Admin: uses email (naturebiotic96@gmail.com)
  // For Executive: uses username (converts to username@naturebiotic.local internally)
  static Future<AuthResponse> signIn({
    required String identifier,
    required String password,
    required bool isAdmin,
  }) async {
    String email = identifier;
    if (!isAdmin && !identifier.contains('@')) {
      email = '$identifier@naturebiotic.local';
    }
    
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Create Executive Account (Admin only)
  static Future<void> createExecutive({
    required String username,
    required String password,
    required String fullName,
  }) async {
    final email = '$username@naturebiotic.local';
    
    // Create auth user
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'full_name': fullName,
        'role': 'executive',
      },
    );

    if (response.user == null) {
      throw 'Failed to create executive account';
    }
  }

  // Get current user profile
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle(); // Use maybeSingle to avoid throwing when row is missing
      
      return response;
    } catch (e) {
      return null;
    }
  }

  // Farmer CRUD
  static Future<List<Map<String, dynamic>>> getFarmers() async {
    return await client.from('farmers').select().order('created_at');
  }

  static Future<void> addFarmer(Map<String, dynamic> farmerData) async {
    await client.from('farmers').insert({
      ...farmerData,
      'created_by': client.auth.currentUser?.id,
    });
  }

  // Farm CRUD
  static Future<List<Map<String, dynamic>>> getFarms() async {
    return await client.from('farms').select().order('created_at');
  }

  static Future<void> addFarm(Map<String, dynamic> farmData) async {
    await client.from('farms').insert({
      ...farmData,
      'created_by': client.auth.currentUser?.id,
    });
  }

  // Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
