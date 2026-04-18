import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _FarmerDetailScreenState extends State<FarmerDetailScreen>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed &&
        _callStartTime != null &&
        _dialedNumber != null) {
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
            farmerId: _farmer['id'].toString(),
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
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Farmer'),
            content: Text(
              'Are you sure you want to delete ${_farmer['name']}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
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
        debugPrint(
          'Attempting to delete farmer with ID: ${_farmer['id']} (type: ${_farmer['id'].runtimeType})',
        );
        await SupabaseService.deleteFarmer(_farmer['id'].toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farmer Deleted Successfully'),
              backgroundColor: Colors.green,
            ),
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
      MaterialPageRoute(builder: (context) => AddFarmerScreen(farmer: _farmer)),
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
        title: Text(
          'Farmer Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: _isLoading ? null : _handleEdit,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.hot,
            ),
            onPressed: _isLoading ? null : _handleDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Hero(
                                tag: 'farmer_icon_${_farmer['id']}',
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _getCategoryColor(
                                          _farmer['category'],
                                        ).withOpacity(0.8),
                                        _getCategoryColor(_farmer['category']),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getCategoryColor(
                                          _farmer['category'],
                                        ).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getInitials(_farmer['name'] ?? 'F'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(
                                      _farmer['category'],
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _farmer['category']
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _getCategoryColor(
                                        _farmer['category'],
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            _farmer['name'] ?? 'N/A',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textBlack,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Information',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.black.withOpacity(0.02),
                            ),
                          ),
                          child: Column(
                            children: [
                              _phoneNumberSection(),
                              const Divider(height: 32, thickness: 0.5),
                              _infoSection(
                                Icons.location_on_rounded,
                                'Village',
                                _farmer['village'] ?? 'N/A',
                              ),
                              const Divider(height: 32, thickness: 0.5),
                              _infoSection(
                                Icons.home_work_rounded,
                                'Address',
                                _farmer['address'] ?? 'N/A',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Farms & Crops',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBlack,
                          ),
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
                                Icon(
                                  Icons.agriculture_rounded,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 16),
                                Text('No farms added yet'),
                              ],
                            ),
                          )
                        else
                          Column(
                            children:
                                _farms.map((farm) => _farmItem(farm)).toList(),
                          ),

                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        AddFarmScreen(farmerId: _farmer['id']),
                              ),
                            );
                            _loadFarms();
                          },
                          icon: const Icon(Icons.add_location_alt_rounded),
                          label: const Text('Add New Farm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            side: BorderSide(
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                            minimumSize: const Size(double.infinity, 60),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _farmItem(Map<String, dynamic> farm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FarmDetailScreen(farm: farm),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm['name'] ?? farm['place'] ?? 'N/A',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${farm['area'] ?? '0'} Acres • ${farm['place'] ?? ''}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textGray.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneNumberSection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.phone_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mobile Number',
                style: GoogleFonts.outfit(
                  color: AppColors.textGray.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _farmer['mobile'] ?? 'N/A',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
        ),
        if (_farmer['mobile'] != null &&
            _farmer['mobile'].toString().isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _initiateCall,
              icon: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoSection(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.textGray.withOpacity(0.7),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: AppColors.textGray.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'F';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts[0].length > 1) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Hot':
        return AppColors.hot;
      case 'Warm':
        return AppColors.warm;
      case 'Cold':
        return AppColors.cold;
      default:
        return AppColors.warm;
    }
  }
}
