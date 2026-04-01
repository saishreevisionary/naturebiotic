import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farms/screens/add_farm_screen.dart';
import 'package:nature_biotic/features/farms/screens/farm_detail_screen.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final data = await SupabaseService.getFarms();
      if (mounted) {
        setState(() {
          _farms = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farms'),
        actions: [
          IconButton(onPressed: _loadFarms, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _farms.isEmpty
          ? const Center(child: Text('No farms registered.'))
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _farms.length,
              itemBuilder: (context, index) {
                final farm = _farms[index];
                return FarmCard(
                  name: farm['name'] ?? farm['place'] ?? 'N/A',
                  place: farm['place'] ?? 'N/A',
                  area: '${farm['area'] ?? '0'} Acres',
                  soilType: farm['soil_type'] ?? 'N/A',
                  onViewDetails: () {
                    debugPrint('Opening farm details for: ${farm['name']}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FarmDetailScreen(farm: farm),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFarmScreen()),
          );
          _loadFarms();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class FarmCard extends StatelessWidget {
  final String name;
  final String place;
  final String area;
  final String soilType;
  final VoidCallback? onViewDetails;

  const FarmCard({
    super.key,
    required this.name,
    required this.place,
    required this.area,
    required this.soilType,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
              ),
              const Icon(Icons.more_vert_rounded, color: AppColors.textGray),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          Text(
            place,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoTile(Icons.square_foot_rounded, area),
              const SizedBox(width: 16),
              _infoTile(Icons.waves_rounded, soilType),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onViewDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('View Farm Details'),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textGray),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textGray),
        ),
      ],
    );
  }
}
