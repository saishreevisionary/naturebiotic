import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farmers/screens/add_farmer_screen.dart';
import 'package:nature_biotic/features/farmers/screens/farmer_detail_screen.dart';

class FarmerListScreen extends StatefulWidget {
  const FarmerListScreen({super.key});

  @override
  State<FarmerListScreen> createState() => _FarmerListScreenState();
}

class _FarmerListScreenState extends State<FarmerListScreen> {
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    try {
      final data = await SupabaseService.getFarmers();
      if (mounted) {
        setState(() {
          _farmers = data;
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
        title: const Text('Farmers'),
        actions: [
          IconButton(onPressed: _loadFarmers, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Farmers...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    fillColor: AppColors.secondary.withOpacity(0.3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: [
                    const FilterChipWidget(label: 'Hot', color: Colors.red),
                    const SizedBox(width: 8),
                    const FilterChipWidget(label: 'Warm', color: Colors.orange),
                    const SizedBox(width: 8),
                    const FilterChipWidget(label: 'Cold', color: Colors.blue),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Clear All', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _farmers.isEmpty 
                  ? const Center(child: Text('No farmers found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      itemCount: _farmers.length,
                      itemBuilder: (context, index) {
                        final farmer = _farmers[index];
                        return FarmerCard(
                          name: farmer['name'] ?? 'N/A',
                          village: farmer['village'] ?? 'N/A',
                          category: farmer['category'] ?? 'Warm',
                          categoryColor: _getCategoryColor(farmer['category']),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FarmerDetailScreen(farmer: farmer),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFarmerScreen()),
          );
          _loadFarmers();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
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

class FilterChipWidget extends StatelessWidget {
  final String label;
  final Color color;

  const FilterChipWidget({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FarmerCard extends StatelessWidget {
  final String name;
  final String village;
  final String category;
  final Color categoryColor;
  final VoidCallback? onTap;

  const FarmerCard({
    super.key,
    required this.name,
    required this.village,
    required this.category,
    required this.categoryColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                Text(
                  village,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textGray),
            ],
          ),
        ),
      ),
    );
  }
}
