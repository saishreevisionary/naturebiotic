import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/attendance/screens/attendance_history_screen.dart';
import 'package:intl/intl.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<Map<String, dynamic>> _executives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final executives = await SupabaseService.getExecutives();
      // Join attendance status for each executive
      final List<Map<String, dynamic>> enrichedData = [];
      
      for (var exec in executives) {
        final attendance = await SupabaseService.getTodayAttendance(userId: exec['id']);
        enrichedData.add({
          ...exec,
          'today_attendance': attendance,
        });
      }

      if (mounted) {
        setState(() {
          _executives = enrichedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Team Attendance'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _executives.isEmpty
              ? const Center(child: Text('No executives found'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _executives.length,
                      itemBuilder: (context, index) {
                        final exec = _executives[index];
                        final attendance = exec['today_attendance'];
                        final bool isCheckedIn = attendance != null;
                        final bool isCheckedOut = attendance != null && attendance['check_out_time'] != null;
    
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AttendanceHistoryScreen(userId: exec['id']),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.secondary,
                                    backgroundImage: exec['avatar_url'] != null ? NetworkImage(exec['avatar_url']) : null,
                                    child: exec['avatar_url'] == null 
                                      ? Text(exec['full_name']?[0] ?? 'E', 
                                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                                      : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(exec['full_name'] ?? 'Unknown', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        _statusIndicator(isCheckedIn, isCheckedOut, attendance),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.textGray),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _statusIndicator(bool isCheckedIn, bool isCheckedOut, dynamic attendance) {
    if (!isCheckedIn) {
      return Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('Absent / Not Checked In', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      );
    }

    if (isCheckedOut) {
      final time = DateFormat('hh:mm a').format(DateTime.parse(attendance['check_out_time']));
      return Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('Shift Ended at $time', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
    }

    final time = DateFormat('hh:mm a').format(DateTime.parse(attendance['check_in_time']));
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('Active - Checked in at $time', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
