import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farmers/screens/add_farmer_screen.dart';
import 'package:nature_biotic/features/farms/screens/add_farm_screen.dart';
import 'package:nature_biotic/features/farms/screens/farm_detail_screen.dart';

import 'package:nature_biotic/core/call_tracker.dart';

class FarmerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const FarmerDetailScreen({super.key, required this.farmer});

  @override
  State<FarmerDetailScreen> createState() => _FarmerDetailScreenState();
}

class _FarmerDetailScreenState extends State<FarmerDetailScreen> with WidgetsBindingObserver {
  late Map<String, dynamic> _farmer;
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;

  // Tracking
  DateTime? _callStartTime;
  String? _dialedNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _farmer = widget.farmer;
    _loadFarms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callStartTime != null && _dialedNumber != null) {
      final startTime = _callStartTime!;
      final dialedNumber = _dialedNumber!;
      
      _callStartTime = null;
      _dialedNumber = null;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          CallTracker.processCallResult(
            context, 
            dialedNumber, 
            startTime, 
            farmerId: _farmer['id'].toString()
          );
        }
      });
    }
  }

  void _initiateCall() {
    final number = _farmer['mobile']?.toString();
    if (number == null || number.isEmpty) return;

    _callStartTime = DateTime.now();
    _dialedNumber = number;
    CallTracker.makeCall(context, number, farmerId: _farmer['id'].toString());
  }

  Future<void> _loadFarms() async {
    try {
      final farms = await SupabaseService.getFarmsByFarmer(_farmer['id']);
      if (mounted) {
        setState(() {
          _farms = farms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farmer'),
        content: Text('Are you sure you want to delete ${_farmer['name']}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        debugPrint('Attempting to delete farmer with ID: ${_farmer['id']} (type: ${_farmer['id'].runtimeType})');
        await SupabaseService.deleteFarmer(_farmer['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Farmer Deleted Successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } catch (e) {
        debugPrint('Delete error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'), 
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFarmerScreen(farmer: _farmer),
      ),
    );

    if (result == true) {
      // Re-fetch or pass updated data?
      // For now, let's just refresh list by popping back or we could fetch again.
      // Since AddFarmerScreen doesn't return the data, we might need to fetch.
      _refreshFarmer();
    }
  }

  Future<void> _refreshFarmer() async {
    // Optionally fetch specific farmer by ID to update detail screen
    // For now, let's just pop back to list to keep it simple and ensure consistency
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_farmer['name'] ?? 'Farmer Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isLoading ? null : _handleEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _isLoading ? null : _handleDelete,
            color: Colors.red,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.person, size: 60, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _farmer['name'] ?? 'N/A',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(_farmer['category']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _farmer['category'] ?? 'Warm',
                    style: TextStyle(
                      color: _getCategoryColor(_farmer['category']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _phoneNumberSection(),
                _infoSection(Icons.location_on_outlined, 'Village', _farmer['village'] ?? 'N/A'),
                _infoSection(Icons.home_outlined, 'Address', _farmer['address'] ?? 'N/A'),
                const SizedBox(height: 32),
            const Text(
              'Farms & Crops',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_farms.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: const Row(
                  children: [
                     Icon(Icons.agriculture_rounded, color: AppColors.primary),
                     SizedBox(width: 16),
                     Text('No farms added yet'),
                  ],
                ),
              )
            else
              Column(
                children: _farms.map((farm) => _farmItem(farm)).toList(),
              ),
            
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFarmScreen(farmerId: _farmer['id'])),
                );
                _loadFarms();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Farm for this Farmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _farmItem(Map<String, dynamic> farm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
        ),
        title: Text(farm['name'] ?? farm['place'] ?? 'N/A', 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${farm['area'] ?? '0'} Acres • ${farm['place'] ?? ''}', 
          style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FarmDetailScreen(farm: farm)),
          );
        },
      ),
    );
  }

  Widget _phoneNumberSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mobile Number', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_farmer['mobile'] ?? 'N/A', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (_farmer['mobile'] != null)
            IconButton.filled(
              onPressed: _initiateCall,
              icon: const Icon(Icons.call, size: 20),
              style: IconButton.styleFrom(backgroundColor: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _infoSection(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textGray, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot': return Colors.red;
      case 'Warm': return Colors.orange;
      case 'Cold': return Colors.blue;
      default: return Colors.orange;
    }
  }
}
