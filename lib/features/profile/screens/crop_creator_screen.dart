import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class CropCreatorScreen extends StatefulWidget {
  const CropCreatorScreen({super.key});

  @override
  State<CropCreatorScreen> createState() => _CropCreatorScreenState();
}

class _CropCreatorScreenState extends State<CropCreatorScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _masterCrops = [];
  bool _tableMissing = false;

  @override
  void initState() {
    super.initState();
    _fetchCrops();
  }

  Future<void> _fetchCrops() async {
    setState(() => _isLoading = true);
    try {
      final crops = await SupabaseService.getMasterCrops();
      if (mounted) {
        setState(() {
          _masterCrops = crops;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('PGRST200') || errorStr.contains('master_crops') || errorStr.contains('master_crop_varieties')) {
          setState(() => _tableMissing = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching crops: $e'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCrop() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Crop'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Crop Name (e.g. Lemon)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addMasterCrop(controller.text.trim());
        await _fetchCrops();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding crop: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _addOrEditVariety(int cropId, [Map<String, dynamic>? variety]) async {
    final varietyController = TextEditingController(text: variety?['variety_name']);
    final lifeController = TextEditingController(text: variety?['life']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(variety == null ? 'Add Variety' : 'Edit Variety'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: varietyController,
              decoration: const InputDecoration(labelText: 'Variety Name', hintText: 'e.g. Alphonso'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lifeController,
              decoration: const InputDecoration(labelText: 'Life Cycle', hintText: 'e.g. 20 Years'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(variety == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (result == true && varietyController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        if (variety == null) {
          await SupabaseService.addMasterVariety(cropId, varietyController.text.trim(), lifeController.text.trim());
        } else {
          await SupabaseService.updateMasterVariety(variety['id'], varietyController.text.trim(), lifeController.text.trim());
        }
        await _fetchCrops();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving variety: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteCrop(Map<String, dynamic> crop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Crop'),
        content: Text('Are you sure you want to delete "${crop['name']}" and all its varieties?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteMasterCrop(crop['id']);
        await _fetchCrops();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting crop: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteVariety(Map<String, dynamic> variety) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variety'),
        content: Text('Are you sure you want to delete "${variety['variety_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.deleteMasterVariety(variety['id']);
        await _fetchCrops();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting variety: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Crop Creator'),
      ),
      body: _tableMissing ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: _buildSetupGuide())) : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: (_isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _masterCrops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.eco_rounded, size: 64, color: AppColors.secondary),
                      const SizedBox(height: 16),
                      const Text('No crops defined', style: TextStyle(color: AppColors.textGray)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addCrop,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Crop'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _masterCrops.length,
                  itemBuilder: (context, index) {
                    final crop = _masterCrops[index];
                    final List varieties = crop['master_crop_varieties'] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.secondary.withOpacity(0.5),
                            child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            crop['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Text('${varieties.length} varieties established'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.black26, size: 18),
                                onPressed: () => _deleteCrop(crop),
                              ),
                              const Icon(Icons.expand_more_rounded),
                            ],
                          ),
                          children: [
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ...varieties.map((v) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              title: Text(v['variety_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Expected Life: ${v['life'] ?? 'Not set'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                    onPressed: () => _addOrEditVariety(crop['id'], v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                    onPressed: () => _deleteVariety(v),
                                  ),
                                ],
                              ),
                            )),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextButton.icon(
                                onPressed: () => _addOrEditVariety(crop['id']),
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: const Text('Add Variety for this Crop'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
        ),
      ),
      floatingActionButton: !_isLoading && !_tableMissing
        ? FloatingActionButton.extended(
            heroTag: 'crop_creator_fab',
            onPressed: _addCrop,
            label: const Text('Add New Category'),
            icon: const Icon(Icons.add),
            backgroundColor: AppColors.primary,
          )
        : null,
    );
  }

  Widget _buildSetupGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Hierarchical Database Setup Required',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'The required tables for Crops and Varieties were not found (or their relationship is missing). Please run this combined SQL in your Supabase Editor:',
            style: TextStyle(color: AppColors.textGray, height: 1.5),
          ),
          const SizedBox(height: 32),
          _stepItem(1, 'Go to Supabase SQL Editor'),
          _stepItem(2, 'Paste and Run the following SQL:'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const SelectableText(
              '-- 1. Create table for Crop Names\n'
              'create table public.master_crops (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  name text not null unique,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              '-- 2. Create table for Varieties\n'
              'create table public.master_crop_varieties (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  crop_id bigint references public.master_crops(id) on delete cascade,\n'
              '  variety_name text not null,\n'
              '  life text,\n'
              '  created_at timestamptz default now()\n'
              ');',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _tableMissing = false;
                _isLoading = true;
              });
              _fetchCrops();
            },
            child: const Text('I have run the SQL, check again'),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(num.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
