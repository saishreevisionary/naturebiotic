import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String? userId; // Null means current user
  const AttendanceHistoryScreen({super.key, this.userId});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceLogs = [];
  List<Map<String, dynamic>> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logs = await SupabaseService.getAttendanceLogs(userId: widget.userId);
      final leaves = await SupabaseService.getMyLeaves(userId: widget.userId);
      if (mounted) {
        setState(() {
          _attendanceLogs = logs;
          _leaveRequests = leaves;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.userId == null ? 'My Logs' : 'Attendance History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Leaves'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGray,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceList(),
                _buildLeaveList(),
              ],
            ),
    );
  }

  Widget _buildAttendanceList() {
    if (_attendanceLogs.isEmpty) {
      return const Center(child: Text('No attendance records found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _attendanceLogs.length,
      itemBuilder: (context, index) {
        final log = _attendanceLogs[index];
        final checkIn = DateTime.parse(log['check_in_time']);
        final checkOut = log['check_out_time'] != null ? DateTime.parse(log['check_out_time']) : null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(checkIn), style: const TextStyle(fontWeight: FontWeight.bold)),
                      _statusBadge(checkOut != null),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _timeInfo('In', DateFormat('hh:mm a').format(checkIn)),
                      if (checkOut != null) ...[
                        const SizedBox(width: 40),
                        _timeInfo('Out', DateFormat('hh:mm a').format(checkOut)),
                      ],
                    ],
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Photos & Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (log['check_in_photo'] != null)
                            Expanded(child: _photoColumn('Check In', log['check_in_photo'])),
                          if (log['check_out_photo'] != null) ...[
                            const SizedBox(width: 12),
                            Expanded(child: _photoColumn('Check Out', log['check_out_photo'])),
                          ],
                        ],
                      ),
                      if (log['check_in_location_lat'] != null) ...[
                        const SizedBox(height: 16),
                        _locationInfo(
                          'Check In Location', 
                          log['check_in_location_lat'], 
                          log['check_in_location_lng']
                        ),
                      ],
                      if (log['check_out_location_lat'] != null) ...[
                        const SizedBox(height: 12),
                        _locationInfo(
                          'Check Out Location', 
                          log['check_out_location_lat'], 
                          log['check_out_location_lng']
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? 'Shift Completed' : 'Working',
        style: TextStyle(
          fontSize: 10, 
          color: isCompleted ? Colors.green : Colors.orange,
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _photoColumn(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url, 
            height: 120, 
            width: double.infinity, 
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: AppColors.secondary,
              child: const Icon(Icons.broken_image_rounded, color: AppColors.textGray),
            ),
          ),
        ),
      ],
    );
  }

  Widget _locationInfo(String label, double lat, double lng) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                Text('$lat, $lng', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveList() {
    if (_leaveRequests.isEmpty) {
      return const Center(child: Text('No leave requests found'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final leave = _leaveRequests[index];
        final start = DateTime.parse(leave['start_date']);
        final end = DateTime.parse(leave['end_date']);
        final status = leave['status'] ?? 'Pending';
        
        Color statusColor = Colors.orange;
        if (status == 'Approved') statusColor = Colors.green;
        if (status == 'Rejected') statusColor = Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(leave['leave_type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}',
                style: const TextStyle(color: AppColors.textGray, fontSize: 13),
              ),
              if (leave['reason'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  leave['reason'],
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _timeInfo(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 11)),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
