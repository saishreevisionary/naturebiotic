import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/pdf_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:intl/intl.dart';

enum NavMode { farms, folder }

class FarmPdfFolderScreen extends StatefulWidget {
  const FarmPdfFolderScreen({super.key});

  @override
  State<FarmPdfFolderScreen> createState() => _FarmPdfFolderScreenState();
}

class _FarmPdfFolderScreenState extends State<FarmPdfFolderScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  NavMode _mode = NavMode.farms;
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _allReports = [];
  Map<String, dynamic>? _selectedFarm;
  List<Map<String, dynamic>> _selectedFarmReports = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      // Add timeout to prevent hanging on slow networks
      final farms = await SupabaseService.getFarms().timeout(const Duration(seconds: 15));
      final reports = await SupabaseService.getReports().timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _farms = farms;
          _allReports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading library data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load library: ${e.toString().contains('Timeout') ? 'Connection Timeout' : e}'), 
            backgroundColor: Colors.red,
            action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _loadData),
          ),
        );
      }
    }
  }

  void _openFolder(Map<String, dynamic> farm) {
    final farmId = farm['id'].toString();
    final reports = _allReports.where((r) => r['farm_id'].toString() == farmId).toList();
    setState(() {
      _selectedFarm = farm;
      _selectedFarmReports = reports;
      _mode = NavMode.folder;
    });
  }

  void _goBack() {
    setState(() {
      _mode = NavMode.farms;
      _selectedFarm = null;
      _selectedFarmReports = [];
    });
  }

  Future<void> _viewPdf(Map<String, dynamic> report) async {
    final farmName = _selectedFarm?['name'] ?? 'Unknown Farm';
    final cropName = report['crops']?['name'] ?? 'Unknown Crop';
    final farmerName = _selectedFarm?['farmers']?['name'] ?? 'Valued Farmer';

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await PdfService.generateAndShare(
        report: report,
        farmName: farmName,
        cropName: cropName,
        farmerName: farmerName,
      );
      if (mounted) Navigator.pop(context); // Close loading
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_mode == NavMode.farms ? 'Report Library' : _selectedFarm?['name'] ?? 'Folder'),
        leading: _mode == NavMode.folder 
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goBack)
            : null,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorUI()
              : _mode == NavMode.farms ? _buildFarmsGrid() : _buildReportsList(),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textGray),
            const SizedBox(height: 24),
            const Text(
              'Connection Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We had trouble reaching the reports library. Please check your internet connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmsGrid() {
    if (_farms.isEmpty) {
      return const Center(child: Text('No farm folders found.'));
    }

    final double width = MediaQuery.of(context).size.width;
    // Responsive column count: 5 for large screens, 4 for medium, 2 for mobile
    final int crossAxisCount = width > 1400 ? 5 : (width > 900 ? 4 : 2);
    // Adjust aspect ratio for better look in grid
    final double childAspectRatio = width > 900 ? 0.95 : 1.1;

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _farms.length,
      itemBuilder: (context, index) {
        final farm = _farms[index];
        final reportCount = _allReports.where((r) => r['farm_id'].toString() == farm['id'].toString()).length;

        return EntranceAnimation(
          delay: index * 50,
          child: InkWell(
            onTap: () => _openFolder(farm),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_shared_rounded,
                    size: 56,
                    color: Color(0xFFFFA000), // Folder yellow
                  ),
                  const SizedBox(height: 12),
                  Text(
                    farm['name'] ?? 'Unnamed Farm',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$reportCount PDF Files',
                    style: TextStyle(color: AppColors.textGray.withOpacity(0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportsList() {
    if (_selectedFarmReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: AppColors.textGray.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('This folder is empty', style: TextStyle(color: AppColors.textGray)),
            TextButton(onPressed: _goBack, child: const Text('Go Back')),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedFarmReports.length,
      itemBuilder: (context, index) {
        final report = _selectedFarmReports[index];
        final date = DateTime.tryParse(report['created_at']?.toString() ?? '') ?? DateTime.now();
        final dateStr = DateFormat('dd MMMM, yyyy').format(date);
        final cropName = report['crops']?['name'] ?? 'Analysis';

        return EntranceAnimation(
          delay: index * 50,
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: ListTile(
              onTap: () => _viewPdf(report),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
              ),
              title: Text(
                'Analysis Report - $dateStr',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Crop: $cropName • PDF Document',
                style: const TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              trailing: const Icon(Icons.file_download_outlined, color: AppColors.textGray),
            ),
          ),
        );
      },
    );
  }
}
