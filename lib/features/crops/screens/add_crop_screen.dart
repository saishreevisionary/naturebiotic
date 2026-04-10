import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';

class AddCropScreen extends StatefulWidget {
  final String farmId;
  const AddCropScreen({super.key, required this.farmId});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _lifeController = TextEditingController();
  final _countController = TextEditingController();
  final _acreController = TextEditingController();
  final _yieldController = TextEditingController();
  
  bool _isLoading = true;
  bool _isConfigLoading = true;
  
  List<Map<String, dynamic>> _masterCrops = [];
  int? _selectedCropId;
  int? _selectedVarietyId;

  // Unit Lists
  List<String> _ageUnits = ['Years', 'Months'];
  List<String> _lifeUnits = ['Years', 'Months'];
  List<String> _acreUnits = ['Acres', 'Cent'];
  List<String> _yieldUnits = ['Tons', 'Kg', 'Quintals'];
  List<String> _countUnits = ['Plants', 'Saplings'];

  // Selected Units
  String _selectedAgeUnit = 'Years';
  String _selectedLifeUnit = 'Years';
  String _selectedAcreUnit = 'Acres';
  String _selectedYieldUnit = 'Tons';
  String _selectedCountUnit = 'Plants';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isConfigLoading = true;
      _isLoading = true;
    });
    await Future.wait([
      _loadMasterData(),
      _loadDropdownUnits(),
    ]);
    if (mounted) {
      setState(() {
        _isConfigLoading = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDropdownUnits() async {
    try {
      final results = await Future.wait([
        SupabaseService.getDropdownOptions('age_unit'),
        SupabaseService.getDropdownOptions('life_unit'),
        SupabaseService.getDropdownOptions('count_unit'),
        SupabaseService.getDropdownOptions('acre_unit'),
        SupabaseService.getDropdownOptions('yield_unit'),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].isNotEmpty) _ageUnits = results[0].map((e) => e['label'] as String).toList();
          if (results[1].isNotEmpty) _lifeUnits = results[1].map((e) => e['label'] as String).toList();
          if (results[2].isNotEmpty) _countUnits = results[2].map((e) => e['label'] as String).toList();
          if (results[3].isNotEmpty) _acreUnits = results[3].map((e) => e['label'] as String).toList();
          if (results[4].isNotEmpty) _yieldUnits = results[4].map((e) => e['label'] as String).toList();

          _selectedAgeUnit = _ageUnits.first;
          _selectedLifeUnit = _lifeUnits.first;
          _selectedCountUnit = _countUnits.first;
          _selectedAcreUnit = _acreUnits.first;
          _selectedYieldUnit = _yieldUnits.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading units: $e');
    }
  }

  Future<void> _loadMasterData() async {
    try {
      final crops = await SupabaseService.getMasterCrops();
      if (mounted) {
        setState(() {
          _masterCrops = crops;
          _isConfigLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback or warning
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _lifeController.dispose();
    _countController.dispose();
    _acreController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCropId == null || _selectedVarietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Crop and Variety'), backgroundColor: Colors.orange),
      );
      return;
    }

    final crop = _masterCrops.firstWhere(
      (c) => c['id'] == _selectedCropId,
      orElse: () => <String, dynamic>{'name': 'Unknown'},
    );
    final varieties = List<Map<String, dynamic>>.from(crop['master_crop_varieties'] ?? []);
    final variety = varieties.firstWhere(
      (v) => v['id'] == _selectedVarietyId,
      orElse: () => <String, dynamic>{'variety_name': 'Unknown'},
    );

    setState(() => _isLoading = true);
    try {
      await SupabaseService.addCrop({
        'farm_id': widget.farmId,
        'name': crop['name'],
        'variety': variety['variety_name'],
        'age': '${_ageController.text.trim()} $_selectedAgeUnit',
        'life': '${_lifeController.text.trim()} $_selectedLifeUnit',
        'count': '${_countController.text.trim()} $_selectedCountUnit',
        'acre': '${_acreController.text.trim()} $_selectedAcreUnit',
        'expected_yield': '${_yieldController.text.trim()} $_selectedYieldUnit',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Crop Added Successfully'), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Crop'),
      ),
      body: _isConfigLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Crop Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _selectedCropId,
                          decoration: const InputDecoration(
                            labelText: 'Crop Name',
                            fillColor: Colors.white,
                          ),
                          items: _masterCrops.map((crop) => DropdownMenuItem<int>(
                            value: crop['id'],
                            child: Text(crop['name']),
                          )).toList(),
                          onChanged: (id) {
                            setState(() {
                              _selectedCropId = id;
                              _selectedVarietyId = null;
                              _lifeController.clear();
                              _selectedLifeUnit = 'Years';
                            });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedVarietyId,
                          decoration: const InputDecoration(
                            labelText: 'Variety',
                            fillColor: Colors.white,
                          ),
                          hint: const Text('Select a variety'),
                          items: (_masterCrops.firstWhere(
                            (c) => c['id'] == _selectedCropId,
                            orElse: () => {'master_crop_varieties': []},
                          )['master_crop_varieties'] as List).map((v) => DropdownMenuItem<int>(
                            value: v['id'],
                            child: Text(v['variety_name']),
                          )).toList(),
                          onChanged: _selectedCropId == null ? null : (id) {
                            setState(() {
                              _selectedVarietyId = id;
                              if (id != null) {
                                final crop = _masterCrops.firstWhere((c) => c['id'] == _selectedCropId);
                                final varieties = List<Map<String, dynamic>>.from(crop['master_crop_varieties'] ?? []);
                                  final variety = varieties.firstWhere(
                                    (v) => v['id'] == id,
                                    orElse: () => <String, dynamic>{'life': ''},
                                  );
                                  
                                  String lifeVal = variety['life'] ?? '';
                                  if (lifeVal.contains(' ')) {
                                    final parts = lifeVal.split(' ');
                                    _lifeController.text = parts[0];
                                    if (_lifeUnits.contains(parts[1])) {
                                      _selectedLifeUnit = parts[1];
                                    }
                                  } else {
                                    _lifeController.text = lifeVal;
                                    _selectedLifeUnit = 'Years';
                                  }
                                }
                            });
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Growth & Yield',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildUnitTextField(
                          controller: _ageController,
                          label: 'Age',
                          units: _ageUnits,
                          selectedUnit: _selectedAgeUnit,
                          onUnitChanged: (v) => setState(() => _selectedAgeUnit = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildUnitTextField(
                          controller: _lifeController,
                          label: 'Life',
                          units: _lifeUnits,
                          selectedUnit: _selectedLifeUnit,
                          onUnitChanged: (v) => setState(() => _selectedLifeUnit = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildUnitTextField(
                          controller: _countController,
                          label: 'Count',
                          units: _countUnits,
                          selectedUnit: _selectedCountUnit,
                          onUnitChanged: (v) => setState(() => _selectedCountUnit = v!),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildUnitTextField(
                          controller: _acreController,
                          label: 'Scale/Acre',
                          units: _acreUnits,
                          selectedUnit: _selectedAcreUnit,
                          onUnitChanged: (v) => setState(() => _selectedAcreUnit = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildUnitTextField(
                          controller: _yieldController,
                          label: 'Expected Yield',
                          units: _yieldUnits,
                          selectedUnit: _selectedYieldUnit,
                          onUnitChanged: (v) => setState(() => _selectedYieldUnit = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Crop Data'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildUnitTextField({
    required TextEditingController controller,
    required String label,
    required List<String> units,
    required String selectedUnit,
    required Function(String?) onUnitChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        fillColor: Colors.white,
        suffixIcon: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedUnit,
              isExpanded: true,
              items: units.map((unit) => DropdownMenuItem(
                value: unit,
                child: Text(unit, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: onUnitChanged,
            ),
          ),
        ),
      ),
    );
  }
}
