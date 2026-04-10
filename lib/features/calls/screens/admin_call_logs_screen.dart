import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class AdminCallLogsScreen extends StatefulWidget {
  const AdminCallLogsScreen({super.key});

  @override
  State<AdminCallLogsScreen> createState() => _AdminCallLogsScreenState();
}

class _AdminCallLogsScreenState extends State<AdminCallLogsScreen> {
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String? _selectedExecutiveId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await SupabaseService.getCallLogs();
      setState(() {
        _allLogs = logs;
        _applyFilters();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        bool matchesExec = _selectedExecutiveId == null || log['executive_id'] == _selectedExecutiveId;
        bool matchesDate = true;
        if (_dateRange != null) {
          final logDate = DateTime.parse(log['created_at']);
          matchesDate = logDate.isAfter(_dateRange!.start) && 
                        logDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
        }
        return matchesExec && matchesDate;
      }).toList();
    });
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Executive Call Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? const Center(child: Text('No call logs found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return _buildLogCard(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (range != null) {
                  setState(() => _dateRange = range);
                  _applyFilters();
                }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(_dateRange == null ? 'All Time' : 
                '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}'),
            ),
          ),
          const SizedBox(width: 12),
          if (_dateRange != null || _selectedExecutiveId != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _selectedExecutiveId = null;
                });
                _applyFilters();
              },
              icon: const Icon(Icons.clear_all_rounded, color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final execName = log['profiles']?['full_name'] ?? 'Unknown Exec';
    final farmerName = log['farmers']?['name'] ?? 'Direct Call';
    final startTime = DateTime.parse(log['created_at']);
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(startTime);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(execName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(_formatDuration(log['duration_seconds'] ?? 0), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Text(log['phone_number'] ?? 'N/A', style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 12),
                    const SizedBox(width: 4),
                    Text('Farmer: $farmerName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  log['summary'] != null && log['summary'].isNotEmpty 
                    ? log['summary'] 
                    : 'No summary provided by executive.',
                  style: TextStyle(
                    fontSize: 12, 
                    fontStyle: log['summary'] == null ? FontStyle.italic : FontStyle.normal,
                    color: log['summary'] == null ? AppColors.textGray : AppColors.textBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
