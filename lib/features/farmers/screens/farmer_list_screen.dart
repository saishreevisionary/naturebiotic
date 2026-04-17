import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/farmers/screens/add_farmer_screen.dart';
import 'package:nature_biotic/features/farmers/screens/farmer_detail_screen.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/core/widgets/animations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FarmerListScreen extends StatefulWidget {
  const FarmerListScreen({super.key});

  @override
  State<FarmerListScreen> createState() => _FarmerListScreenState();
}

class _FarmerListScreenState extends State<FarmerListScreen> {
  List<Map<String, dynamic>> _farmers = [];
  bool _isLoading = true;
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFarmers();
  }

  Future<void> _loadFarmers() async {
    setState(() => _isLoading = true);
    try {
      final remoteData = await SupabaseService.getFarmers();
      List<Map<String, dynamic>> localData = [];
      
      if (!kIsWeb) {
        localData = await LocalDatabaseService.getData('farmers');
      }

      if (mounted) {
        setState(() {
          // Merge and De-duplicate
          final Map<String, Map<String, dynamic>> combinedMap = {};
          
          for (var farmer in localData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }
          for (var farmer in remoteData) {
            combinedMap[farmer['id'].toString()] = farmer;
          }

          _farmers = combinedMap.values.toList();
          _farmers.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
          
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
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search Farmers...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        fillColor: AppColors.secondary.withOpacity(0.3),
                        suffixIcon: _searchController.text.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChipWidget(
                            label: 'Hot', 
                            color: Colors.red,
                            isSelected: _selectedCategory == 'Hot',
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Hot' ? null : 'Hot'),
                          ),
                          const SizedBox(width: 8),
                          FilterChipWidget(
                            label: 'Warm', 
                            color: Colors.orange,
                            isSelected: _selectedCategory == 'Warm',
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Warm' ? null : 'Warm'),
                          ),
                          const SizedBox(width: 8),
                          FilterChipWidget(
                            label: 'Cold', 
                            color: Colors.blue,
                            isSelected: _selectedCategory == 'Cold',
                            onTap: () => setState(() => _selectedCategory = _selectedCategory == 'Cold' ? null : 'Cold'),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _searchController.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final query = _searchController.text.toLowerCase();
                        final filtered = _farmers.where((f) {
                          final name = (f['name'] ?? '').toString().toLowerCase();
                          final village = (f['village'] ?? '').toString().toLowerCase();
                          final mobile = (f['mobile'] ?? '').toString().toLowerCase();
                          final category = f['category'];
                          
                          final matchesQuery = name.contains(query) || village.contains(query) || mobile.contains(query);
                          final matchesCategory = _selectedCategory == null || category == _selectedCategory;
                          
                          return matchesQuery && matchesCategory;
                        }).toList();
    
                        if (filtered.isEmpty) {
                          return const Center(child: Text('No farmers found.'));
                        }
    
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final farmer = filtered[index];
                            return EntranceAnimation(
                              delay: 100 + (index * 100),
                              child: FarmerCard(
                                id: farmer['id'].toString(),
                                name: farmer['name'] ?? 'N/A',
                                village: farmer['village'] ?? 'N/A',
                                category: farmer['category'] ?? 'Warm',
                                categoryColor: _getCategoryColor(farmer['category']),
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FarmerDetailScreen(farmer: farmer),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadFarmers();
                                  }
                                },
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
      floatingActionButton: EntranceAnimation(
        delay: 1200,
        child: ScaleButton(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddFarmerScreen()),
            );
            _loadFarmers();
          },
          child: FloatingActionButton(
            heroTag: 'farmer_fab',
            onPressed: null,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
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
  final bool isSelected;
  final VoidCallback onTap;

  const FilterChipWidget({
    super.key, 
    required this.label, 
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class FarmerCard extends StatelessWidget {
  final String id;
  final String name;
  final String village;
  final String category;
  final Color categoryColor;
  final VoidCallback? onTap;

  const FarmerCard({
    super.key,
    required this.id,
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
          Hero(
            tag: 'farmer_icon_$id',
            child: Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
            ),
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
