import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class LoginLogsScreen extends StatefulWidget {
  const LoginLogsScreen({super.key});

  @override
  State<LoginLogsScreen> createState() => _LoginLogsScreenState();
}

class _LoginLogsScreenState extends State<LoginLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await SupabaseService.getLoginLogs();
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Login Activities'),
        actions: [
          IconButton(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildLogCard(_logs[index]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: AppColors.textGray),
          SizedBox(height: 16),
          Text('No login activities recorded yet.', style: TextStyle(color: AppColors.textGray)),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final status = log['status']?.toString() ?? 'UNKNOWN';
    final isMismatch = status == 'DEVICE_MISMATCH';
    final Color color = isMismatch ? Colors.red : Colors.green;
    final IconData icon = isMismatch ? Icons.warning_amber_rounded : Icons.login_rounded;
    
    // Support both direct join and aliased join
    final profile = (log['profiles'] ?? log['user_id_profiles']) as Map<String, dynamic>?;
    final fullName = profile?['full_name'] ?? 'User ID: ${log['user_id']?.toString().substring(0, 8) ?? 'Unknown'}';
    final username = profile?['username'] ?? 'No Username';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('@$username', style: const TextStyle(color: AppColors.textGray, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.phone_android_rounded, 'Device', log['device_name'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.info_outline_rounded, 'OS', log['os_version'] ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time_rounded, 'Time', _formatDateTime(log['created_at'])),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.fingerprint_rounded, 'ID', log['device_id'] ?? 'N/A', isId: true),
          if (isMismatch) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final userId = log['user_id'];
                  if (userId == null) return;
                  
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset Device?'),
                      content: const Text('This will allow the user to link their account to this new phone. Continue?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true), 
                          child: const Text('Allow Device', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await SupabaseService.resetUserDevice(userId);
                    if (mounted) {
                      _loadLogs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device pairing reset. User can now log in.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
                label: const Text('Allow This Device'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isId = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textGray),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              fontFamily: isId ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }
}
