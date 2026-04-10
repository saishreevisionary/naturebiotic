import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/auth/screens/create_executive_screen.dart';
import 'package:nature_biotic/features/auth/screens/executive_list_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_screen.dart';
import 'package:nature_biotic/features/attendance/screens/leave_request_screen.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_history_screen.dart';
import 'package:nature_biotic/features/attendance/screens/admin_attendance_screen.dart';
import 'package:nature_biotic/features/attendance/screens/admin_leave_approval_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isAdmin = false;
  int _farmerCount = 0;
  int _farmCount = 0;
  int _cropCount = 0;
  int _reportCount = 0;
  String _userName = 'User';
  String _avatarUrl = '';
  bool _isLoading = true;
  Map<String, dynamic>? _todayAttendance;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  List<Map<String, dynamic>> _recentActivities = [];

  Future<void> _loadDashboardData() async {
    try {
      final profile = await SupabaseService.getProfile();
      final farmers = await SupabaseService.getFarmers();
      final farms = await SupabaseService.getFarms();
      final crops = await SupabaseService.getAllCrops();
      final reports = await SupabaseService.getReports();
      final activities = await SupabaseService.getRecentActivities();
      final attendance = await SupabaseService.getTodayAttendance();
      
      if (mounted) {
        setState(() {
          _isAdmin = profile?['role'] == 'admin';
          _userName = profile?['full_name']?.split(' ')[0] ?? 'User';
          _avatarUrl = profile?['avatar_url'] ?? '';
          _farmerCount = farmers.length;
          _farmCount = farms.length; 
          _cropCount = crops.length;
          _reportCount = reports.length;
          _recentActivities = activities;
          _todayAttendance = attendance;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final diff = DateTime.now().difference(dateTime);
      
      if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
      if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $_userName!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const Text(
                        'Welcome to Nature Biotic',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.secondary,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty ? const Icon(Icons.person, color: AppColors.primary) : null,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  StatCard(
                    title: 'Total Farmers',
                    value: _farmerCount.toString(),
                    icon: Icons.people_alt_rounded,
                  ),
                  StatCard(
                    title: 'Total Farms',
                    value: _farmCount.toString(),
                    icon: Icons.agriculture_rounded,
                  ),
                  StatCard(
                    title: 'Total Crops',
                    value: _cropCount.toString(),
                    icon: Icons.eco_rounded,
                  ),
                  StatCard(
                    title: 'Reports',
                    value: _reportCount.toString(),
                    icon: Icons.bar_chart_rounded,
                  ),
                ],
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 32),
                const Text(
                  'Admin Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Create Executive Account',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CreateExecutiveScreen()),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.1)),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AdminLeaveApprovalScreen()),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.event_available_rounded, color: Colors.orange),
                              const SizedBox(height: 12),
                              const Text('Leave Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Pending Requests', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.1)),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AdminAttendanceScreen()),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.fact_check_rounded, color: Colors.blue),
                              const SizedBox(height: 12),
                              const Text('Team Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Daily Status', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              
              if (!_isAdmin) ...[
                const SizedBox(height: 32),
                
                // Attendance Section
                const Text(
                  'My Work',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                      child: _workActionCard(
                        context,
                        title: 'Attendance',
                        subtitle: _todayAttendance == null 
                          ? 'Not checked in' 
                          : (_todayAttendance!['check_out_time'] == null ? 'Working' : 'Check-out done'),
                        icon: Icons.camera_enhance_rounded,
                        color: AppColors.primary,
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const AttendanceScreen())
                        ).then((_) => _loadDashboardData()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _workActionCard(
                        context,
                        title: 'Leave',
                        subtitle: 'Apply Now',
                        icon: Icons.event_note_rounded,
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const LeaveRequestScreen())
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _workActionCard(
                  context,
                  title: 'Work Logs',
                  subtitle: 'History & Leave Status',
                  icon: Icons.history_edu_rounded,
                  color: Colors.blue,
                  fullWidth: true,
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen())
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              if (_recentActivities.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No recent activities', style: TextStyle(color: AppColors.textGray)),
                  ),
                )
              else
                ..._recentActivities.map((activity) => ActivityItem(
                  title: activity['title'],
                  subtitle: activity['subtitle'],
                  time: _getTimeAgo(activity['created_at']),
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;

  const ActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
