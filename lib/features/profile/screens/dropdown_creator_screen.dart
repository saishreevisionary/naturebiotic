import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class DropdownCreatorScreen extends StatefulWidget {
  const DropdownCreatorScreen({super.key});

  @override
  State<DropdownCreatorScreen> createState() => _DropdownCreatorScreenState();
}

class _DropdownCreatorScreenState extends State<DropdownCreatorScreen> {
  bool _isLoading = false;
  String? _selectedType;
  List<Map<String, dynamic>> _options = [];
  List<Map<String, dynamic>> _problemCategories = [];
  int? _selectedParentId;
  bool _tableMissing = false;

  final Map<String, String> _typeLabels = {
    'farmer_category': 'Farmer Categories',
    'soil_type': 'Soil Types',
    'irrigation_type': 'Irrigation Types',
    'water_source': 'Water Sources',
    'water_quantity': 'Water Quantities',
    'power_source': 'Power Sources',
    'problem_category': 'Problem Categories',
    'problem_item': 'Problem Items (Specific)',
    'master_crop': 'Crops & Varieties',
    'age_unit': 'Age Units',
    'life_unit': 'Life Units',
    'count_unit': 'Count Units',
    'acre_unit': 'Acre/Scale Units',
    'yield_unit': 'Yield Units',
  };

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchOptions() async {
    if (_selectedType == null) return;
    
    setState(() => _isLoading = true);
    try {
      if (_selectedType == 'problem_item') {
        if (_problemCategories.isEmpty) {
          _problemCategories = await SupabaseService.getDropdownOptions('problem_category');
        }
        
        if (_selectedParentId == null && _problemCategories.isNotEmpty) {
          _selectedParentId = _problemCategories[0]['id'];
        }
        
        if (_selectedParentId != null) {
          _options = await SupabaseService.getDropdownOptions(_selectedType!, parentId: _selectedParentId);
        } else {
          _options = [];
        }
      } else if (_selectedType == 'master_crop') {
        _options = await SupabaseService.getMasterCrops();
      } else {
        _options = await SupabaseService.getDropdownOptions(_selectedType!);
      }
      setState(() => _tableMissing = false);
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('PGRST205') || errorStr.contains('PGRST200') || 
            errorStr.contains('dropdown_options') || errorStr.contains('master_crops')) {
          setState(() => _tableMissing = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching options: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOption() async {
    if (_selectedType == 'master_crop') {
      _addMasterCrop();
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${_typeLabels[_selectedType]}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Label Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.addDropdownOption(_selectedType!, result, parentId: _selectedParentId);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding option: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- Hierarchical Crop Methods ---
  
  Future<void> _addMasterCrop() async {
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
        await _fetchOptions();
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
        await _fetchOptions();
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

  Future<void> _deleteMasterCrop(Map<String, dynamic> crop) async {
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
        await _fetchOptions();
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

  Future<void> _deleteMasterVariety(Map<String, dynamic> variety) async {
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
        await _fetchOptions();
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

  // --- End Hierarchical Crop Methods ---

  Future<void> _editOption(Map<String, dynamic> option) async {
    final controller = TextEditingController(text: option['label']);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_typeLabels[_selectedType]}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Label Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != option['label']) {
      setState(() => _isLoading = true);
      try {
        await SupabaseService.updateDropdownOption(option['id'], result);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating option: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteOption(Map<String, dynamic> option) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${option['label']}"?'),
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
        await SupabaseService.deleteDropdownOption(option['id']);
        await _fetchOptions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting option: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Drop down Creator'),
      ),
      body: _tableMissing ? _buildSetupGuide() : Column(
        children: [
          // Header / Type Selector
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Dropdown Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Choose a category to manage'),
                  items: _typeLabels.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedType = v;
                      _selectedParentId = null;
                      _options = [];
                    });
                    _fetchOptions();
                  },
                ),
                if (_selectedType == 'problem_item') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Select Parent Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _selectedParentId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: _problemCategories.map((c) => DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(c['label']),
                    )).toList(),
                    onChanged: (v) {
                      setState(() => _selectedParentId = v);
                      _fetchOptions();
                    },
                  ),
                ],
              ],
            ),
          ),
          
          // List View (Combined for flat and hierarchical)
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedType == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list_alt_rounded, size: 64, color: AppColors.secondary),
                        SizedBox(height: 16),
                        Text('Please select a dropdown type above', style: TextStyle(color: AppColors.textGray)),
                      ],
                    ),
                  )
                : _options.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No options found for this category'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Option'),
                          ),
                        ],
                      ),
                    )
                  : _selectedType == 'master_crop' 
                    ? _buildCropListView()
                    : _buildFlatListView(),
          ),
        ],
      ),
      floatingActionButton: _selectedType != null && !_isLoading && !_tableMissing
        ? FloatingActionButton.extended(
            onPressed: _addOption,
            label: Text(_selectedType == 'master_crop' ? 'Add New Category' : 'Add Option'),
            icon: const Icon(Icons.add),
            backgroundColor: AppColors.primary,
          )
        : null,
    );
  }

  Widget _buildFlatListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                option['label'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                onPressed: () => _editOption(option),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () => _deleteOption(option),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCropListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final crop = _options[index];
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
                    onPressed: () => _deleteMasterCrop(crop),
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
                        onPressed: () => _deleteMasterVariety(v),
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
            'Database Setup Required',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'The required tables (dropdown_options, master_crops, or varieties) were not found. Please run this combined SQL in your Supabase Editor:',
            style: TextStyle(color: AppColors.textGray, height: 1.5),
          ),
          const SizedBox(height: 32),
          _stepItem(1, 'Open your Supabase Dashboard'),
          _stepItem(2, 'Go to the SQL Editor'),
          _stepItem(3, 'Paste the following SQL and click "Run":'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const SelectableText(
              '-- 1. Create main dropdown table\n'
              'create table if not exists public.dropdown_options (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  type text not null,\n'
              '  label text not null,\n'
              '  parent_id bigint references public.dropdown_options(id) on delete cascade,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              '-- 2. Create hierarchical crop tables\n'
              'create table if not exists public.master_crops (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  name text not null unique,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              'create table if not exists public.master_crop_varieties (\n'
              '  id bigint generated by default as identity primary key,\n'
              '  crop_id bigint references public.master_crops(id) on delete cascade,\n'
              '  variety_name text not null,\n'
              '  life text,\n'
              '  created_at timestamptz default now()\n'
              ');\n\n'
              '-- 3. Insert initial dropdown data\n'
              'insert into public.dropdown_options (type, label) values \n'
              "('farmer_category', 'Hot'), ('farmer_category', 'Warm'), ('farmer_category', 'Cold'),\n"
              "('soil_type', 'Red'), ('soil_type', 'Black'), ('soil_type', 'Loomy'), ('soil_type', 'Aluvial'),\n"
              "('irrigation_type', 'Flood'), ('irrigation_type', 'Drip irrigation'),\n"
              "('water_source', 'Well'), ('water_source', 'Borewell'), ('water_source', 'canal/Pond'), ('water_source', 'River/Stream'),\n"
              "('water_quantity', 'Ample'), ('water_quantity', 'surplus'), ('water_quantity', 'Scarcity'),\n"
              "('power_source', 'EB'), ('power_source', 'Diesel Pump'), ('power_source', 'Solar'),\n"
              "('problem_category', 'Pests'), ('problem_category', 'Diseases'), ('problem_category', 'Deficiency'), ('problem_category', 'Others'),\n"
              "('age_unit', 'Years'), ('age_unit', 'Months'),\n"
              "('life_unit', 'Years'), ('life_unit', 'Months'),\n"
              "('count_unit', 'Plants'), ('count_unit', 'Saplings'),\n"
              "('acre_unit', 'Acres'), ('acre_unit', 'Cent'),\n"
              "('yield_unit', 'Tons'), ('yield_unit', 'Kg'), ('yield_unit', 'Quintals')\n"
              'on conflict do nothing;',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() => _tableMissing = false);
              _fetchOptions();
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
