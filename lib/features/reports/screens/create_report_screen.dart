import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:signature/signature.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _crops = [];
  
  // Selection
  String? _selectedFarmId;
  String? _selectedCropId;
  final Set<String> _selectedProblems = {};
  final Map<String, Uint8List?> _problemImages = {};
  final Map<String, String> _problemImageNames = {};
  final ImagePicker _picker = ImagePicker();

  // Agricultural Problem Categories
  Map<String, List<String>> _problemCategories = {
    'Pests': ['Mites', 'Aphids', 'Thrips', 'Leaf Miner', 'S Borer', 'F Borer', 'Worm', 'Caterpillar', 'W.Fly', 'F Fly', 'M.Bug', 'Beetle'],
    'Diseases': ['Root Rot', 'Wilt', 'Leaf Blight', 'Powdery Mildew', 'Leaf Curl', 'Little Leaf', 'Early Blight', 'Downy Mildew', 'Rust Spot', 'Fusarium', 'Flower Blight', 'Nematode'],
    'Deficiency': ['Nitrogen (N)', 'Phosphorous (P)', 'Potassium (K)', 'Calcium (Ca)', 'Sulfur (S)', 'Magnesium (Mg)', 'Zinc (Zn)', 'Iron (Fe)', 'Manganese (Mn)', 'Copper (Cu)', 'Boron (B)', 'Chlorine (Cl)'],
    'Others': ['Drought', 'Water Logging', 'Weed', 'Uvar Soil', 'Poor Maintenance'],
  };

  // Inputs
  final _additionalNotesController = TextEditingController();
  
  // Previous Inputs Categories
  final _pesticidesController = TextEditingController();
  final _fungicidesController = TextEditingController();
  final _fertilizersController = TextEditingController();
  final _stimulantController = TextEditingController();
  final _herbicideController = TextEditingController();
  DateTime? _selectedInputDate;

  // Recommendations Categories
  final List<RecommendationRow> _recommendationsList = [];
  
  // Cost Estimations Categories
  final List<CostEstimationRow> _costEstimations = [];
  DateTime? _nextVisitDate;
  
  final _costController = TextEditingController(); // To be removed or used for summary
  
  // Signature
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.primary,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _loadFarms();
    _fetchProblemData();
    _addRecommendationRow();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _additionalNotesController.dispose();
    _pesticidesController.dispose();
    _fungicidesController.dispose();
    _fertilizersController.dispose();
    _stimulantController.dispose();
    _herbicideController.dispose();
    super.dispose();
  }

  void _addRecommendationRow() {
    setState(() {
      _recommendationsList.add(RecommendationRow());
    });
  }

  void _removeRecommendationRow(int index) {
    if (_recommendationsList.length > 1) {
      setState(() {
        _recommendationsList.removeAt(index);
      });
    }
  }

  void _syncCostEstimations() {
    final validProductNames = _recommendationsList
        .where((r) => r.product.text.trim().isNotEmpty)
        .map((r) => r.product.text.trim())
        .toList();

    setState(() {
      // Keep existing data if the product name matches
      final existingMap = {for (var row in _costEstimations) row.productName: row};
      _costEstimations.clear();

      for (var name in validProductNames) {
        if (existingMap.containsKey(name)) {
          _costEstimations.add(existingMap[name]!);
        } else {
          _costEstimations.add(CostEstimationRow(productName: name));
        }
      }
    });
  }

  Future<void> _loadFarms() async {
    final farms = await SupabaseService.getFarms();
    setState(() => _farms = farms);
  }

  Future<void> _loadCrops(String farmId) async {
    final crops = await SupabaseService.getCrops(farmId);
    setState(() {
      _crops = crops;
      _selectedCropId = null;
    });
  }

  Future<void> _fetchProblemData() async {
    try {
      final categories = await SupabaseService.getDropdownOptions('problem_category');
      if (categories.isEmpty) return;

      Map<String, List<String>> dynamicProblems = {};
      
      for (var cat in categories) {
        final items = await SupabaseService.getDropdownOptions('problem_item', parentId: cat['id']);
        dynamicProblems[cat['label']] = items.map((e) => e['label'].toString()).toList();
      }

      if (dynamicProblems.isNotEmpty) {
        setState(() {
          _problemCategories = dynamicProblems;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLastReportData(String farmId, String cropId) async {
    final lastReport = await SupabaseService.getLastReportForCrop(farmId, cropId);
    if (lastReport == null) return;

    final history = lastReport['previous_inputs'] as String?;
    final createdAt = lastReport['created_at'];
    
    setState(() {
      if (createdAt != null) {
        try {
          _selectedInputDate = DateTime.parse(createdAt.toString());
        } catch (_) {}
      }

      if (history != null && history.isNotEmpty) {
        final lines = history.split('\n');
        for (var line in lines) {
          if (line.startsWith('Date:')) {
            // Optional: specifically parse the date string if it differs from createdAt
          } else if (line.startsWith('Pesticides:')) {
            _pesticidesController.text = line.replaceFirst('Pesticides:', '').trim();
          } else if (line.startsWith('Fungicides:')) {
            _fungicidesController.text = line.replaceFirst('Fungicides:', '').trim();
          } else if (line.startsWith('Fertilizers:')) {
            _fertilizersController.text = line.replaceFirst('Fertilizers:', '').trim();
          } else if (line.startsWith('Bio Stimulant:')) {
            _stimulantController.text = line.replaceFirst('Bio Stimulant:', '').trim();
          } else if (line.startsWith('Herbicide:')) {
            _herbicideController.text = line.replaceFirst('Herbicide:', '').trim();
          }
        }
      }
    });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Last visit history pre-filled automatically'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
  }

  Future<void> _handleSave() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature to proceed'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String finalProblem = _selectedProblems.join(', ');
      if (_additionalNotesController.text.isNotEmpty) {
        finalProblem += '\nNotes: ${_additionalNotesController.text.trim()}';
      }

      // Handle Signature Upload
      String? signatureUrl;
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes != null) {
        final sigFileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
        signatureUrl = await SupabaseService.uploadImage(signatureBytes, sigFileName, 'reports');
      }

      // Handle Image Uploads
      Map<String, String> uploadedImageUrls = {};
      for (var entry in _problemImages.entries) {
        if (entry.value != null) {
          try {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_problemImageNames[entry.key] ?? 'image.jpg'}';
            final url = await SupabaseService.uploadImage(entry.value!, fileName, 'reports');
            uploadedImageUrls[entry.key] = url;
          } catch (e) {
            debugPrint('Error uploading image for ${entry.key}: $e');
          }
        }
      }

      // Store image mapping in problem string for now or a separate field if it exists
      // Format: "Problem {img: URL}, Problem2 {img: URL}"
      // This allows PdfService and ReportGenerator to parse it easily
      String problemDataWithImages = '';
      for (var p in _selectedProblems) {
        if (uploadedImageUrls.containsKey(p)) {
          problemDataWithImages += '$p {img: ${uploadedImageUrls[p]}}, ';
        } else {
          problemDataWithImages += '$p, ';
        }
      }
      if (problemDataWithImages.endsWith(', ')) {
        problemDataWithImages = problemDataWithImages.substring(0, problemDataWithImages.length - 2);
      }
      if (_additionalNotesController.text.isNotEmpty) {
        problemDataWithImages += '\nNotes: ${_additionalNotesController.text.trim()}';
      }

      String finalHistory = '';
      if (_selectedInputDate != null) {
        finalHistory += 'Date: ${_formatDate(_selectedInputDate)}\n';
      }
      if (_pesticidesController.text.isNotEmpty) finalHistory += 'Pesticides: ${_pesticidesController.text.trim()}\n';
      if (_fungicidesController.text.isNotEmpty) finalHistory += 'Fungicides: ${_fungicidesController.text.trim()}\n';
      if (_fertilizersController.text.isNotEmpty) finalHistory += 'Fertilizers: ${_fertilizersController.text.trim()}\n';
      if (_stimulantController.text.isNotEmpty) finalHistory += 'Bio Stimulant: ${_stimulantController.text.trim()}\n';
      if (_herbicideController.text.isNotEmpty) finalHistory += 'Herbicide: ${_herbicideController.text.trim()}\n';

      String finalRecommendations = '';
      for (var row in _recommendationsList) {
        if (row.product.text.isNotEmpty) {
          finalRecommendations += '${row.product.text} (${row.application.text}) - '
              'Dose: ${row.dose.text}, Filler: ${row.filler.text}\n';
        }
      }

      String finalCost = '';
      double grandTotal = 0;
      for (var row in _costEstimations) {
        final double qty = double.tryParse(row.qty.text) ?? 0;
        final double mrp = double.tryParse(row.mrp.text) ?? 0;
        final double offer = double.tryParse(row.offerPrice.text) ?? mrp;
        final double total = qty * offer;
        grandTotal += total;
        
        finalCost += '${row.productName} (Pkg: ${row.pkgSize.text}) - '
            'Qty: ${row.qty.text}, MRP: ${row.mrp.text}, Offer: ${row.offerPrice.text}, Total: $total\n';
      }
      if (_nextVisitDate != null) {
        finalCost += 'Next Visit: ${_formatDate(_nextVisitDate)}\n';
      }
      finalCost += 'Grand Total: ₹$grandTotal';

      final reportData = {
        'farm_id': _selectedFarmId,
        'crop_id': _selectedCropId,
        'problem': problemDataWithImages, // Enhanced string with image markers
        'previous_inputs': finalHistory.trim(),
        'recommendations': finalRecommendations.trim(),
        'estimated_cost': finalCost,
        'signature_url': signatureUrl,
      };

      await SupabaseService.addReport(reportData);

      if (mounted) {
        final farm = _farms.firstWhere((f) => f['id'] == _selectedFarmId, orElse: () => {});
        final crop = _crops.firstWhere((c) => c['id'] == _selectedCropId, orElse: () => {});
        final farmerNameForPdf = farm['farmers']?['name'] ?? 'Valued Farmer';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReportGeneratorScreen(
              report: reportData,
              farmName: farm['name'] ?? 'Unknown Farm',
              cropName: crop['name'] ?? 'Unknown Crop',
              farmerName: farmerNameForPdf,
            ),
          ),
        );
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
    final pw_subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_costEstimations.isNotEmpty) Text('Grand Total: ₹${_calculateGrandTotal()}', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
        if (_nextVisitDate != null) Text('Next Visit: ${_formatDate(_nextVisitDate)}', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Analysis Report'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 5) {
            if (_currentStep == 3) _syncCostEstimations();
            setState(() => _currentStep += 1);
          } else {
            _handleSave();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_currentStep == 5 ? 'Generate Analysis' : 'Next Step'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Select Farm & Crop'),
            subtitle: _selectedFarmId != null ? Text(
              '${_farms.firstWhere((f) => f['id'] == _selectedFarmId)['name']} • '
              '${_selectedCropId != null ? _crops.firstWhere((c) => c['id'] == _selectedCropId)['name'] : 'Select Crop'}',
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ) : null,
            isActive: _currentStep >= 0,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedFarmId,
                  decoration: const InputDecoration(labelText: 'Choose Farm'),
                  items: _farms.map((f) => DropdownMenuItem(
                    value: f['id'].toString(),
                    child: Text(f['name'] ?? 'Unknown'),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => _selectedFarmId = v);
                    _loadCrops(v!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCropId,
                  decoration: const InputDecoration(labelText: 'Choose Crop'),
                  items: _crops.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['name'] ?? 'Unknown'),
                  )).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCropId = value);
                        if (value != null && _selectedFarmId != null) {
                          _loadLastReportData(_selectedFarmId!, value);
                        }
                      },
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Identify Problem'),
            subtitle: _selectedProblems.isNotEmpty ? Text(
              _selectedProblems.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ) : null,
            isActive: _currentStep >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._problemCategories.entries.map((category) => _categorySection(category.key, category.value)),
                const SizedBox(height: 20),
                const Text('Additional Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _additionalNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Any other specific notes...',
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Previous Inputs'),
            subtitle: _selectedInputDate != null ? Text(
              'Date: ${_formatDate(_selectedInputDate)}',
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ) : null,
            isActive: _currentStep >= 2,
            content: Column(
              children: [
                _inputField(_pesticidesController, 'Pesticides'),
                _inputField(_fungicidesController, 'Fungicides'),
                _inputField(_fertilizersController, 'Fertilizers'),
                _inputField(_stimulantController, 'Bio Stimulant'),
                _inputField(_herbicideController, 'Herbicide'),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedInputDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedInputDate == null 
                            ? 'Select Crop Input Date' 
                            : 'Date: ${_formatDate(_selectedInputDate)}',
                          style: TextStyle(
                            color: _selectedInputDate == null ? AppColors.textGray : AppColors.primary,
                            fontWeight: _selectedInputDate != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Recommendations'),
            subtitle: _recommendationsList.any((r) => r.product.text.isNotEmpty) ? Text(
              '${_recommendationsList.where((r) => r.product.text.isNotEmpty).length} Products Recommended',
              style: const TextStyle(color: AppColors.primary, fontSize: 12),
            ) : null,
            isActive: _currentStep >= 3,
            content: Column(
              children: [
                ..._recommendationsList.asMap().entries.map((entry) => _recommendationRowWidget(entry.key, entry.value)),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _addRecommendationRow,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add Product Recommendation'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Estimated Cost'),
            subtitle: _costEstimations.isNotEmpty || _nextVisitDate != null ? pw_subtitle : null,
            isActive: _currentStep >= 4,
            content: Column(
              children: [
                ..._costEstimations.map((row) => _costEstimationRowWidget(row)),
                if (_costEstimations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Add products in Step 4 to see them here.', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Grand Total: ₹${_calculateGrandTotal()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setState(() => _nextVisitDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.secondary),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Next Visit Date', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _nextVisitDate == null ? 'Set Follow-up Date' : _formatDate(_nextVisitDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: _nextVisitDate == null ? AppColors.textGray : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.event_repeat_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Step(
            title: const Text('Executive Signature'),
            subtitle: const Text('Sign below to finalize report', style: TextStyle(fontSize: 10)),
            isActive: _currentStep >= 5,
            content: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.secondary),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Signature(
                      controller: _signatureController,
                      height: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _signatureController.clear(),
                      icon: const Icon(Icons.clear_all_rounded, color: Colors.red),
                      label: const Text('Clear Signature', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    const Text('(Mandatory)', style: TextStyle(color: AppColors.textGray, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(String problem, ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _problemImages[problem] = bytes;
        _problemImageNames[problem] = image.name;
      });
    }
  }

  Widget _categorySection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = _selectedProblems.contains(item);
            final hasImage = _problemImages[item] != null;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterChip(
                  label: Text(item, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedProblems.add(item);
                      } else {
                        _selectedProblems.remove(item);
                        _problemImages.remove(item);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                ),
                if (isSelected)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _pickImage(item, ImageSource.camera),
                        icon: Icon(Icons.camera_alt_rounded, 
                          size: 18, 
                          color: hasImage ? AppColors.primary : Colors.grey),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _pickImage(item, ImageSource.gallery),
                        icon: Icon(Icons.photo_library_rounded, 
                          size: 18, 
                          color: hasImage ? AppColors.primary : Colors.grey),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                      ],
                    ],
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _costEstimationRowWidget(CostEstimationRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.secondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniField(row.pkgSize, 'Pkg Size')),
              const SizedBox(width: 8),
              Expanded(child: _miniField(row.qty, 'Qty #', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: _miniField(row.mrp, 'MRP', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: _miniField(row.offerPrice, 'Offer Price', isNumber: true)),
            ],
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (context, setInternalState) {
              row.qty.addListener(() => setInternalState(() {}));
              row.mrp.addListener(() => setInternalState(() {}));
              row.offerPrice.addListener(() => setInternalState(() {}));
              
              final double q = double.tryParse(row.qty.text) ?? 0;
              final double p = double.tryParse(row.mrp.text) ?? 0;
              final double offer = double.tryParse(row.offerPrice.text) ?? p;
              return Align(
                alignment: Alignment.centerRight,
                child: Text('Total: ₹${q * offer}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              );
            }
          ),
        ],
      ),
    );
  }

  double _calculateGrandTotal() {
    double total = 0;
    for (var row in _costEstimations) {
      final double q = double.tryParse(row.qty.text) ?? 0;
      final double p = double.tryParse(row.mrp.text) ?? 0;
      final double offer = double.tryParse(row.offerPrice.text) ?? p;
      total += (q * offer);
    }
    return total;
  }

  Widget _miniField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _recommendationRowWidget(int index, RecommendationRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.secondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _miniField(row.product, 'Product Name')),
              const SizedBox(width: 8),
              if (_recommendationsList.length > 1)
                IconButton(
                  onPressed: () => _removeRecommendationRow(index),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniField(row.application, 'Application')),
              const SizedBox(width: 8),
              Expanded(child: _miniField(row.dose, 'Dose')),
              const SizedBox(width: 8),
              Expanded(child: _miniField(row.filler, 'Filler Qty')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class RecommendationRow {
  final product = TextEditingController();
  final application = TextEditingController();
  final dose = TextEditingController();
  final filler = TextEditingController();
}

class CostEstimationRow {
  final String productName;
  final pkgSize = TextEditingController();
  final qty = TextEditingController();
  final mrp = TextEditingController();
  final offerPrice = TextEditingController();

  CostEstimationRow({required this.productName});
}
