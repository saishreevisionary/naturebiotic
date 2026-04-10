import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/crops/screens/add_crop_screen.dart';
import 'package:nature_biotic/features/crops/screens/crop_detail_screen.dart';

import 'package:nature_biotic/core/call_tracker.dart';

class FarmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const FarmDetailScreen({super.key, required this.farm});

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> with WidgetsBindingObserver {
  late Map<String, dynamic> _farm;
  List<Map<String, dynamic>> _crops = [];
  Map<String, dynamic>? _farmer;
  bool _isAdmin = false;
  bool _isLoading = true;

  // Tracking
  DateTime? _callStartTime;
  String? _dialedNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _farm = widget.farm;
    _checkAdminStatus();
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
            farmerId: _farm['farmer_id'].toString()
          );
        }
      });
    }
  }

  void _initiateCall() {
    final number = _farmer?['mobile']?.toString();
    if (number == null || number.isEmpty) return;

    _callStartTime = DateTime.now();
    _dialedNumber = number;
    CallTracker.makeCall(context, number, farmerId: _farm['farmer_id'].toString());
  }

  Future<void> _checkAdminStatus() async {
    final profile = await SupabaseService.getProfile();
    if (mounted) {
      setState(() {
        _isAdmin = profile?['role'] == 'admin';
        _isLoading = false;
      });
      _loadAssignedExecutive();
      _loadCrops();
      _loadFarmer();
    }
  }

  Future<void> _loadFarmer() async {
    if (_farm['farmer_id'] != null) {
      try {
        final response = await SupabaseService.client
            .from('farmers')
            .select()
            .eq('id', _farm['farmer_id'])
            .maybeSingle();
        if (mounted) {
          setState(() {
            _farmer = response;
          });
        }
      } catch (e) {
        debugPrint('Error loading farmer: $e');
      }
    }
  }

  Future<void> _loadCrops() async {
    try {
      final crops = await SupabaseService.getCrops(_farm['id']);
      if (mounted) {
        setState(() {
          _crops = crops;
        });
      }
    } catch (e) {
      debugPrint('Error loading crops: $e');
    }
  }

  Future<void> _loadAssignedExecutive() async {
    if (_farm['assigned_to'] != null && _farm['assigned_executive'] == null) {
      final executive = await SupabaseService.getProfileById(_farm['assigned_to']);
      if (mounted) {
        setState(() {
          _farm['assigned_executive'] = executive;
        });
      }
    }
  }

  Future<void> _showAssignDialog() async {
    showDialog(
      context: context,
      builder: (context) => _AssignExecutiveDialog(
        currentAssignedId: _farm['assigned_to'],
        onAssign: (executive) async {
          await SupabaseService.assignFarm(_farm['id'], executive?['id']);
          // Refresh local state
          setState(() {
            _farm['assigned_to'] = executive?['id'];
            _farm['assigned_executive'] = executive;
          });
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final assignedExecutive = _farm['assigned_executive'];
    final executiveName = assignedExecutive?['full_name'] ?? 'Not Assigned';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_farm['name'] ?? _farm['place'] ?? 'Farm Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.agriculture_rounded, size: 32, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Registration Date', 
                          style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                        const Text('March 31, 2026', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            if (_isAdmin) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assigned Executive', 
                            style: TextStyle(color: AppColors.textGray, fontSize: 10)),
                          Text(executiveName, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showAssignDialog,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Change', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            if (_farmer != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Farm Owner (Farmer)', 
                            style: TextStyle(color: AppColors.textGray, fontSize: 10)),
                          Text(_farmer?['name'] ?? 'N/A', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (_farmer?['mobile'] != null)
                      IconButton(
                        onPressed: _initiateCall,
                        icon: const Icon(Icons.call, size: 20, color: Colors.green),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.verified_user_rounded, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text('Farm Information', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            const SizedBox(height: 16),
            
            // Grid of Info Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: [
                _infoCard(Icons.location_on_outlined, 'Place', _farm['place'] ?? 'N/A'),
                _infoCard(Icons.square_foot_rounded, 'Area', '${_farm['area'] ?? '0'} Acres'),
                _infoCard(Icons.waves_rounded, 'Soil', _farm['soil_type'] ?? 'N/A'),
                _infoCard(Icons.opacity_rounded, 'Irrigation', _farm['irrigation_type'] ?? 'N/A'),
                _infoCard(Icons.water_drop_outlined, 'Source', _farm['water_source'] ?? 'N/A'),
                _infoCard(Icons.inventory_2_outlined, 'Qty', _farm['water_quantity'] ?? 'N/A'),
                _infoCard(Icons.flash_on_outlined, 'Power', _farm['power_source'] ?? 'N/A'),
              ],
            ),
            
            const SizedBox(height: 24),
            const Text('Crops in this Farm', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            const SizedBox(height: 16),
            if (_crops.isEmpty)
              const Text('No crops added to this farm yet.', style: TextStyle(color: AppColors.textGray, fontSize: 13))
            else
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _crops.length,
                  itemBuilder: (context, index) {
                    final crop = _crops[index];
                    return _cropCard(crop);
                  },
                ),
              ),
            
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCropScreen(farmId: _farm['id'])),
                );
                if (result == true) {
                  _loadCrops();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Crop to Farm'),
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

  Widget _cropCard(Map<String, dynamic> crop) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CropDetailScreen(crop: crop)),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                const Icon(Icons.eco_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    crop['name'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Variety: ${crop['variety'] ?? 'N/A'}', 
              style: const TextStyle(fontSize: 10, color: AppColors.textGray),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('Area: ${crop['acre'] ?? 'N/A'}', 
              style: const TextStyle(fontSize: 10, color: AppColors.textGray),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Count: ${crop['count'] ?? 'N/A'}', 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text(crop['age'] ?? 'N/A', 
                      style: const TextStyle(fontSize: 9, color: AppColors.textGray)),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textGray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 9)),
                Text(value, 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignExecutiveDialog extends StatefulWidget {
  final String? currentAssignedId;
  final Function(Map<String, dynamic>?) onAssign;

  const _AssignExecutiveDialog({this.currentAssignedId, required this.onAssign});

  @override
  State<_AssignExecutiveDialog> createState() => _AssignExecutiveDialogState();
}

class _AssignExecutiveDialogState extends State<_AssignExecutiveDialog> {
  List<Map<String, dynamic>> _executives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExecutives();
  }

  Future<void> _loadExecutives() async {
    final data = await SupabaseService.getExecutives();
    if (mounted) {
      setState(() {
        _executives = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Executive'),
      content: _isLoading 
        ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
        : SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _executives.length + 1, // +1 for "Unassign"
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.person_off_rounded),
                    title: const Text('Unassign'),
                    onTap: () => widget.onAssign(null),
                  );
                }
                final executive = _executives[index - 1];
                final isSelected = widget.currentAssignedId == executive['id'];
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    child: Text(executive['full_name']?[0] ?? 'E'),
                  ),
                  title: Text(executive['full_name'] ?? 'N/A'),
                  subtitle: Text('@${executive['username']}'),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () => widget.onAssign(executive),
                );
              },
            ),
          ),
    );
  }
}
