import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/calls/screens/executive_call_details_screen.dart';

class AdminCallLogsScreen extends StatefulWidget {
  const AdminCallLogsScreen({super.key});

  @override
  State<AdminCallLogsScreen> createState() => _AdminCallLogsScreenState();
}

class _AdminCallLogsScreenState extends State<AdminCallLogsScreen> {
  List<Map<String, dynamic>> _executives = [];
  Map<String, int> _talkTimeToday = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExecutives();
  }

  Future<void> _loadExecutives() async {
    setState(() => _isLoading = true);
    try {
      final execs = await SupabaseService.getExecutives();
      
      // Fetch all today's logs to calculate duration
      final today = DateTime.now();
      final logs = await SupabaseService.getCallLogs(
        startDate: today,
        endDate: today,
      );

      final Map<String, int> talkTime = {};
      for (var log in logs) {
        final execId = log['executive_id'];
        final duration = (log['duration_seconds'] as num? ?? 0).toInt();
        talkTime[execId] = (talkTime[execId] ?? 0) + duration;
      }

      setState(() {
        _executives = execs;
        _talkTimeToday = talkTime;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Executive Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadExecutives,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Select an executive to view their call history and analytics',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _executives.isEmpty
                        ? const Center(child: Text('No executives found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _executives.length,
                            itemBuilder: (context, index) {
                              final exec = _executives[index];
                              return _buildExecutiveCard(exec);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveCard(Map<String, dynamic> exec) {
    final name = exec['full_name'] ?? 'Unknown';
    final username = exec['username'] ?? 'N/A';
    final avatarUrl = exec['avatar_url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExecutiveCallDetailsScreen(
                executiveId: exec['id'],
                executiveName: name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.secondary,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty ? const Icon(Icons.person, color: AppColors.primary) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Talk Time today: ${((_talkTimeToday[exec['id']] ?? 0) / 60).toStringAsFixed(1)} mins',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Logs',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
