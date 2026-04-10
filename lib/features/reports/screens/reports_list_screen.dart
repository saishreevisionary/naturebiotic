import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/features/reports/screens/create_report_screen.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:intl/intl.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await SupabaseService.getReports();
      setState(() => _reports = reports);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Analysis Reports'),
        actions: [
          IconButton(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty 
              ? _buildEmptyState()
              : _buildReportsList(),
      floatingActionButton: _reports.isNotEmpty ? FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateReportScreen()),
        ).then((_) => _loadReports()),
        child: const Icon(Icons.add_rounded),
      ) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Reports Generated Yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new analysis for your farms',
            style: TextStyle(color: AppColors.textGray),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateReportScreen()),
            ).then((_) => _loadReports()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Generate New Report'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
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
