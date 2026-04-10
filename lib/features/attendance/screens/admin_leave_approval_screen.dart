import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class AdminLeaveApprovalScreen extends StatefulWidget {
  const AdminLeaveApprovalScreen({super.key});

  @override
  State<AdminLeaveApprovalScreen> createState() => _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState extends State<AdminLeaveApprovalScreen> {
  List<Map<String, dynamic>> _leaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getAllLeaves();
      if (mounted) {
        setState(() {
          _leaves = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading requests: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await SupabaseService.updateLeaveStatus(id, status);
      _loadLeaves();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave $status'), backgroundColor: status == 'Approved' ? Colors.green : Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leave Approvals'),
        actions: [
          IconButton(onPressed: _loadLeaves, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? const Center(child: Text('No leave requests found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final leave = _leaves[index];
                    final profile = leave['profiles'];
                    final status = leave['status'];
                    final isPending = status == 'Pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.secondary,
                                child: Text(profile['full_name']?[0] ?? 'E', 
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(profile['full_name'] ?? 'Unknown', 
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(leave['leave_type'], 
                                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              _statusChip(status),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.textGray),
                              const SizedBox(width: 8),
                              Text(
                                '${DateFormat('MMM d').format(DateTime.parse(leave['start_date']))} - ${DateFormat('MMM d').format(DateTime.parse(leave['end_date']))}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray)),
                          const SizedBox(height: 4),
                          Text(leave['reason'] ?? 'No reason provided', style: const TextStyle(fontSize: 14)),
                          if (isPending) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _updateStatus(leave['id'], 'Rejected'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                    child: const Text('Reject'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _updateStatus(leave['id'], 'Approved'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'Approved': color = Colors.green; break;
      case 'Rejected': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
