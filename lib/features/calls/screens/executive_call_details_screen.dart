import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExecutiveCallDetailsScreen extends StatefulWidget {
  final String executiveId;
  final String executiveName;

  const ExecutiveCallDetailsScreen({
    super.key,
    required this.executiveId,
    required this.executiveName,
  });

  @override
  State<ExecutiveCallDetailsScreen> createState() => _ExecutiveCallDetailsScreenState();
}

class _ExecutiveCallDetailsScreenState extends State<ExecutiveCallDetailsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final remoteLogs = await SupabaseService.getCallLogs(
        userId: widget.executiveId,
        startDate: _selectedDate,
        endDate: _selectedDate,
      );

      List<Map<String, dynamic>> localLogs = [];
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      // Only fetch local logs if viewing own history on mobile
      if (!kIsWeb && currentUserId == widget.executiveId) {
        final startOfDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final endOfDate = startOfDate.add(const Duration(days: 1));

        localLogs = await LocalDatabaseService.getData(
          'call_logs',
          where: 'start_time >= ? AND start_time < ?',
          whereArgs: [startOfDate.toIso8601String(), endOfDate.toIso8601String()],
        );
      }

      if (mounted) {
        setState(() {
          final Map<String, Map<String, dynamic>> combinedMap = {};

          // Add local logs first (they might have more up-to-date data or be pending)
          for (var log in localLogs) {
            combinedMap[log['id'].toString()] = {
              ...log,
              'is_local': true,
            };
          }

          // Add remote logs (overwrite if same ID)
          for (var log in remoteLogs) {
            combinedMap[log['id'].toString()] = {
              ...log,
              'is_local': false,
            };
          }

          _logs = combinedMap.values.toList();
          
          // Sort by start_time descending
          _logs.sort((a, b) {
            final t1 = DateTime.parse(a['start_time'].toString());
            final t2 = DateTime.parse(b['start_time'].toString());
            return t2.compareTo(t1);
          });
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading logs: $e');
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.executiveName),
            const Text('Call History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Generate Report',
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(
                  start: _selectedDate,
                  end: _selectedDate,
                ),
              );

              if (range == null) return;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating PDF report...')),
                );
              }

              final logsForReport = await SupabaseService.getCallLogs(
                userId: widget.executiveId,
                startDate: range.start,
                endDate: range.end,
              );

              if (logsForReport.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No logs found for the selected range'), backgroundColor: Colors.red),
                  );
                }
                return;
              }

              await PdfService.generateCallLogReport(
                logs: logsForReport,
                executiveName: widget.executiveName,
                dateRange: range,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildSummaryHeader(),
              _buildFilterBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                        ? const Center(child: Text('No call logs found for this period'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return _buildLogCard(_logs[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
              _loadLogs();
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _loadLogs();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isToday ? null : () {
              setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
              _loadLogs();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
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
              Row(
                children: [
                   Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textBlack)),
                   if (log['is_local'] == true) ...[
                     const SizedBox(width: 12),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.orange.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.orange.withOpacity(0.2)),
                       ),
                       child: const Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Icon(Icons.sync_rounded, size: 10, color: Colors.orange),
                           SizedBox(width: 4),
                           Text(
                             'Pending Sync',
                             style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ),
                   ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(log['duration_seconds'] ?? 0), 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Text(log['phone_number'] ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              _typeBadge(log['type'] ?? 'Outgoing'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Farmer: $farmerName', 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'By: ${widget.executiveName}', 
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 20),
                Text(
                  log['summary'] != null && log['summary'].isNotEmpty 
                    ? log['summary'] 
                    : 'No summary provided.',
                  style: TextStyle(
                    fontSize: 13, 
                    height: 1.4,
                    fontStyle: log['summary'] == null || log['summary'].isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: log['summary'] == null || log['summary'].isEmpty ? AppColors.textGray : AppColors.textBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    int totalSeconds = 0;
    for (var log in _logs) {
      totalSeconds += (log['duration_seconds'] as int? ?? 0);
    }
    final totalMins = totalSeconds / 60;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _summaryStat(
            label: 'Total Calls',
            value: _logs.length.toString(),
            icon: Icons.call_rounded,
          ),
          Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 24)),
          _summaryStat(
            label: 'Total Duration',
            value: '${totalMins.toStringAsFixed(1)} min',
            icon: Icons.timer_outlined,
          ),
        ],
      ),
    );
  }

  Widget _summaryStat({required String label, required String value, required IconData icon}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
