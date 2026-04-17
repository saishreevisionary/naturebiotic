import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ExecutiveReportsScreen extends StatefulWidget {
  final Map<String, dynamic> executive;

  const ExecutiveReportsScreen({super.key, required this.executive});

  @override
  State<ExecutiveReportsScreen> createState() => _ExecutiveReportsScreenState();
}

class _ExecutiveReportsScreenState extends State<ExecutiveReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final reports = await SupabaseService.getReportsByExecutive(
        widget.executive['id'],
        startDate: _dateRange?.start,
        endDate: _dateRange?.end.add(const Duration(days: 1)), // Include whole end day
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadReports();
    }
  }

  void _clearFilter() {
    setState(() => _dateRange = null);
    _loadReports();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Executive Reports', style: TextStyle(fontSize: 18)),
            Text(widget.executive['full_name'] ?? 'Executive', 
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off_rounded),
              onPressed: _clearFilter,
              tooltip: 'Clear Filter',
            ),
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (_dateRange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.primary.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Filter: ${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
                        style: const TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold, 
                          color: AppColors.primary
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearFilter,
                        child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _reports.isEmpty 
                    ? _buildEmptyState()
                    : _buildReportsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            _dateRange == null ? 'No Reports Found' : 'No reports in this period',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (_dateRange != null)
            TextButton(onPressed: _clearFilter, child: const Text('Clear Filter')),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final farmName = report['farms']?['name'] ?? 'Unknown Farm';
        final cropName = report['crops']?['name'] ?? 'Unknown Crop';
        final farmerName = report['farms']?['farmers']?['name'] ?? 'Valued Farmer';
        final date = _formatDate(report['created_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.description_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(
              farmName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$cropName • $date', style: const TextStyle(fontSize: 12)),
                Text('Farmer: $farmerName', style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportGeneratorScreen(
                    report: report,
                    farmName: farmName,
                    cropName: cropName,
                    farmerName: farmerName,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
