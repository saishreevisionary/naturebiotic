import 'dart:io';
import 'dart:typed_data';
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

    // Explicitly create profile record
    await client.from('profiles').insert({
      'id': response.user!.id,
      'full_name': fullName,
      'username': username,
      'role': 'executive',
    });
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
    final profile = await getProfile();
    var query = client.from('farmers').select();
    
    if (profile?['role'] == 'executive') {
      // For executives, show only farmers they created
      query = query.eq('created_by', client.auth.currentUser!.id);
    }
    
    return await query.order('created_at');
  }

  static Future<void> addFarmer(Map<String, dynamic> farmerData) async {
    await client.from('farmers').insert({
      ...farmerData,
      'created_by': client.auth.currentUser?.id,
    });
  }

  static Future<void> addFarmersBulk(List<Map<String, dynamic>> farmersData) async {
    final userId = client.auth.currentUser?.id;
    final farmersWithCreatedBy = farmersData.map((farmer) => {
      ...farmer,
      'created_by': userId,
    }).toList();
    
    await client.from('farmers').insert(farmersWithCreatedBy);
  }

  static Future<void> updateFarmer(String id, Map<String, dynamic> farmerData) async {
    await client.from('farmers').update(farmerData).eq('id', id);
  }

  static Future<void> deleteFarmer(dynamic id) async {
    await client.from('farmers').delete().eq('id', id);
  }

  // Farm CRUD
  static Future<List<Map<String, dynamic>>> getFarms() async {
    final user = client.auth.currentUser;
    final profile = await getProfile();
    var query = client.from('farms').select('*, farmers(name)');
    
    print('DEBUG: getFarms - User ID: ${user?.id}');
    print('DEBUG: getFarms - Role: ${profile?['role']}');
    
    if (profile?['role'] == 'executive') {
      final userId = user!.id;
      print('DEBUG: getFarms - Filtering by assigned_to: $userId');
      // THE NEW WORKFLOW: Executives ONLY see farms assigned to them
      query = query.eq('assigned_to', userId);
    }
    
    final response = await query.order('created_at');
    print('DEBUG: getFarms - Found ${response.length} farms');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addFarm(Map<String, dynamic> farmData) async {
    await client.from('farms').insert({
      ...farmData,
      'created_by': client.auth.currentUser?.id,
    });
  }

  static Future<void> updateFarm(String id, Map<String, dynamic> farmData) async {
    await client.from('farms').update(farmData).eq('id', id);
  }

  static Future<void> deleteFarm(dynamic id) async {
    await client.from('farms').delete().eq('id', id);
  }

  static Future<List<Map<String, dynamic>>> getFarmsByFarmer(String farmerId) async {
    final response = await client
        .from('farms')
        .select()
        .eq('farmer_id', farmerId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  // Get all executive profiles
  static Future<List<Map<String, dynamic>>> getExecutives() async {
    return await client
        .from('profiles')
        .select()
        .eq('role', 'executive')
        .order('full_name');
  }

  // Assign farm to executive
  static Future<void> assignFarm(String farmId, String? executiveId) async {
    await client
        .from('farms')
        .update({'assigned_to': executiveId})
        .eq('id', farmId);
  }

  // Get profile by ID
  static Future<Map<String, dynamic>?> getProfileById(String id) async {
    try {
      return await client.from('profiles').select().eq('id', id).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  // Crop CRUD
  static Future<List<Map<String, dynamic>>> getCrops(String farmId) async {
    final response = await client
        .from('crops')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getAllCrops() async {
    final user = client.auth.currentUser;
    final profile = await getProfile();
    
    if (profile?['role'] == 'executive' && user != null) {
      // Executives see crops for farms assigned to them
      final response = await client
          .from('crops')
          .select('*, farms!inner(assigned_to)')
          .eq('farms.assigned_to', user.id);
      return List<Map<String, dynamic>>.from(response);
    } else {
      // Admins see all crops
      final response = await client.from('crops').select();
      return List<Map<String, dynamic>>.from(response);
    }
  }

  static Future<void> addCrop(Map<String, dynamic> cropData) async {
    await client.from('crops').insert(cropData);
  }

  // Report CRUD
  static Future<void> addReport(Map<String, dynamic> reportData) async {
    await client.from('reports').insert({
      ...reportData,
      'created_by': client.auth.currentUser?.id,
    });
  }

  static Future<Map<String, dynamic>?> getLastReportForCrop(String farmId, String cropId) async {
    try {
      final response = await client
          .from('reports')
          .select()
          .eq('farm_id', farmId)
          .eq('crop_id', cropId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getReportsForFarm(String farmId) async {
    final response = await client
        .from('reports')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getReports() async {
    final user = client.auth.currentUser;
    final profile = await getProfile();
    
    if (profile?['role'] == 'executive' && user != null) {
      // Executives only see reports for farms assigned to them
      final response = await client
          .from('reports')
          .select('*, farms!inner(name, assigned_to, farmers(name)), crops(name)')
          .eq('farms.assigned_to', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } else {
      // Admins see all reports
      final response = await client
          .from('reports')
          .select('*, farms(name, farmers(name)), crops(name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    }
  }

  static Future<List<Map<String, dynamic>>> getReportsByExecutive(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = client
        .from('reports')
        .select('*, farms!inner(name, assigned_to, farmers(name)), crops(name)')
        .eq('created_by', userId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getRecentActivities() async {
    // Combine 5 latest farmers and 5 latest reports
    final farmers = await getFarmers();
    final reports = await getReports();
    
    List<Map<String, dynamic>> activities = [];
    
    for (var f in farmers.take(5)) {
      activities.add({
        'type': 'new_farmer',
        'title': 'Farmer Added',
        'subtitle': '${f['name']} was added',
        'created_at': f['created_at'],
      });
    }
    
    for (var r in reports.take(5)) {
      final farmName = r['farms']?['name'] ?? 'Unknown Farm';
      activities.add({
        'type': 'report_generated',
        'title': 'Report Generated',
        'subtitle': 'Analysis for $farmName',
        'created_at': r['created_at'],
      });
    }
    
    // Sort combined activities by created_at descending
    activities.sort((a, b) => 
        DateTime.parse(b['created_at'].toString()).compareTo(
        DateTime.parse(a['created_at'].toString())));
        
    return activities.take(5).toList();
  }

  static Future<String> uploadImage(Uint8List bytes, String fileName, String bucketId) async {
    try {
      await client.storage.from(bucketId).uploadBinary(fileName, bytes);
    } catch (e) {
      if (e.toString().contains('Bucket not found') || 
          e.toString().contains('404')) {
        try {
          // Attempt to create the bucket with public access
          await client.storage.createBucket(
            bucketId, 
            const BucketOptions(public: true)
          );
          // Retry upload
          await client.storage.from(bucketId).uploadBinary(fileName, bytes);
        } catch (_) {
          // If creation fails, rethrow the original error
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    return client.storage.from(bucketId).getPublicUrl(fileName);
  }

  // Get User statistics
  static Future<Map<String, int>> getUserStats() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return {'farmers': 0, 'farms': 0, 'reports': 0};

    final profile = await getProfile();
    final role = profile?['role'];

    // Farmers count
    var farmersQuery = client.from('farmers').select('id');
    if (role == 'executive') farmersQuery = farmersQuery.eq('created_by', userId);
    final farmersRes = await farmersQuery.count(CountOption.exact);

    // Farms count
    var farmsQuery = client.from('farms').select('id');
    if (role == 'executive') farmsQuery = farmsQuery.eq('assigned_to', userId);
    final farmsRes = await farmsQuery.count(CountOption.exact);

    // Reports count
    var reportsQuery = client.from('reports').select('id');
    if (role == 'executive') {
      reportsQuery = reportsQuery.eq('created_by', userId);
    }
    final reportsRes = await reportsQuery.count(CountOption.exact);

    return {
      'farmers': farmersRes.count,
      'farms': farmsRes.count,
      'reports': reportsRes.count,
    };
  }

  // Update profile
  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('profiles').update(data).eq('id', userId);
  }

  // Update password
  static Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Send password reset email
  static Future<void> resetPasswordForEmail(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.naturebiotic://login-callback/',
    );
  }

  // Dropdown Options CRUD
  static Future<List<Map<String, dynamic>>> getDropdownOptions(String type, {int? parentId}) async {
    var query = client.from('dropdown_options').select().eq('type', type);
    if (parentId != null) {
      query = query.eq('parent_id', parentId);
    }
    return await query.order('label');
  }

  static Future<void> addDropdownOption(String type, String label, {int? parentId}) async {
    await client.from('dropdown_options').insert({
      'type': type,
      'label': label,
      'parent_id': parentId,
    });
  }

  static Future<void> updateDropdownOption(int id, String label) async {
    await client.from('dropdown_options').update({'label': label}).eq('id', id);
  }

  static Future<void> deleteDropdownOption(int id) async {
    await client.from('dropdown_options').delete().eq('id', id);
  }

  // Master Crop CRUD
  static Future<List<Map<String, dynamic>>> getMasterCrops() async {
    final response = await client
        .from('master_crops')
        .select('*, master_crop_varieties(*)')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addMasterCrop(String name) async {
    await client.from('master_crops').insert({'name': name});
  }

  static Future<void> addMasterVariety(int cropId, String variety, String life) async {
    await client.from('master_crop_varieties').insert({
      'crop_id': cropId,
      'variety_name': variety,
      'life': life,
    });
  }

  static Future<void> updateMasterVariety(int id, String variety, String life) async {
    await client.from('master_crop_varieties').update({
      'variety_name': variety,
      'life': life,
    }).eq('id', id);
  }

  static Future<void> deleteMasterCrop(int id) async {
    await client.from('master_crops').delete().eq('id', id);
  }

  static Future<void> deleteMasterVariety(int id) async {
    await client.from('master_crop_varieties').delete().eq('id', id);
  }

  // Attendance Methods
  static Future<Map<String, dynamic>?> getTodayAttendance({String? userId}) async {
    final targetUserId = userId ?? client.auth.currentUser?.id;
    if (targetUserId == null) return null;

    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    
    try {
      final response = await client
          .from('attendance')
          .select()
          .eq('user_id', targetUserId)
          .gte('created_at', startOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  static Future<void> checkIn(Map<String, dynamic> data) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw 'User not authenticated';

    await client.from('attendance').insert({
      ...data,
      'user_id': userId,
      'status': 'present',
    });
  }

  static Future<void> checkOut(String attendanceId, Map<String, dynamic> data) async {
    await client.from('attendance').update(data).eq('id', attendanceId);
  }

  static Future<List<Map<String, dynamic>>> getAttendanceLogs({String? userId}) async {
    final targetUserId = userId ?? client.auth.currentUser?.id;
    if (targetUserId == null) return [];

    final response = await client
        .from('attendance')
        .select()
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Leave Methods
  static Future<void> requestLeave(Map<String, dynamic> leaveData) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw 'User not authenticated';

    await client.from('leaves').insert({
      ...leaveData,
      'user_id': userId,
      'status': 'Pending',
    });
  }

  static Future<List<Map<String, dynamic>>> getMyLeaves({String? userId}) async {
    final targetUserId = userId ?? client.auth.currentUser?.id;
    if (targetUserId == null) return [];

    final response = await client
        .from('leaves')
        .select()
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getAllLeaves() async {
    try {
      // 1. Fetch all leaves
      final leavesResponse = await client
          .from('leaves')
          .select()
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> leaves = List<Map<String, dynamic>>.from(leavesResponse);
      if (leaves.isEmpty) return [];

      // 2. Fetch profiles for these leaves to avoid join errors
      final userIds = leaves.map((l) => l['user_id']).toSet().toList();
      final profilesResponse = await client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', userIds);
      
      final Map<String, dynamic> profilesMap = {
        for (var p in profilesResponse) p['id']: p
      };

      // 3. Manually join them
      return leaves.map((leave) {
        return {
          ...leave,
          'profiles': profilesMap[leave['user_id']] ?? {'full_name': 'Unknown Executive'}
        };
      }).toList();
    } catch (e) {
      print('Error in getAllLeaves: $e');
      rethrow;
    }
  }

  static Future<void> updateLeaveStatus(String id, String status) async {
    await client.from('leaves').update({'status': status}).eq('id', id);
  }

  // Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
