import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:nature_biotic/features/reports/screens/report_generator_screen.dart';
import 'package:signature/signature.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateReportScreen extends StatefulWidget {
  final String? preSelectedFarmId;
  final String? preSelectedCropId;

  const CreateReportScreen({
    super.key,
    this.preSelectedFarmId,
    this.preSelectedCropId,
  });

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _productOptions = [];
  List<Map<String, dynamic>> _applicationOptions = [];
  List<Map<String, dynamic>> _doseUnitOptions = [];
  List<Map<String, dynamic>> _fillerUnitOptions = [];
  List<Map<String, dynamic>> _fillerMaterialOptions = [];
  List<Map<String, dynamic>> _perUnitOptions = [];
  List<String> _suggestedProblems = [];

  // Selection
  String? _selectedFarmId;
  String? _selectedCropId;
  String? _activeProblemCategory;
  String _problemSearchQuery = '';
  final Set<String> _selectedProblems = {};
  final Map<String, Uint8List?> _problemImages = {};
  final Map<String, String> _problemImageNames = {};
  final ImagePicker _picker = ImagePicker();

  // Agricultural Problem Categories
  Map<String, List<String>> _problemCategories = {
    'Pests': [
      'Mites',
      'Aphids',
      'Thrips',
      'Leaf Miner',
      'S Borer',
      'F Borer',
      'Worm',
      'Caterpillar',
      'W.Fly',
      'F Fly',
      'M.Bug',
      'Beetle',
    ],
    'Diseases': [
      'Root Rot',
      'Wilt',
      'Leaf Blight',
      'Powdery Mildew',
      'Leaf Curl',
      'Little Leaf',
      'Early Blight',
      'Downy Mildew',
      'Rust Spot',
      'Fusarium',
      'Flower Blight',
      'Nematode',
    ],
    'Deficiency': [
      'Nitrogen (N)',
      'Phosphorous (P)',
      'Potassium (K)',
      'Calcium (Ca)',
      'Sulfur (S)',
      'Magnesium (Mg)',
      'Zinc (Zn)',
      'Iron (Fe)',
      'Manganese (Mn)',
      'Copper (Cu)',
      'Boron (B)',
      'Chlorine (Cl)',
    ],
    'Others': [
      'Drought',
      'Water Logging',
      'Weed',
      'Uvar Soil',
      'Poor Maintenance',
    ],
  };

  // Inputs
  final _additionalNotesController = TextEditingController();

  // Previous Inputs Categories
  Map<String, List<PreviousInputRow>> _previousInputsMap = {
    'Pesticides': [PreviousInputRow()],
    'Fungicides': [PreviousInputRow()],
    'Fertilizers': [PreviousInputRow()],
    'Bio Stimulant': [PreviousInputRow()],
    'Herbicide': [PreviousInputRow()],
  };

  // Crop/Farm Metadata for Calculations
  double _cropAcre = 0.0;
  int _cropCount = 0;

  // Recommendations Categories
  final List<RecommendationRow> _recommendationsList = [];

  // Cost Estimations Categories
  final List<CostEstimationRow> _costEstimations = [];
  DateTime? _nextVisitDate;

  final _costController =
      TextEditingController(); // To be removed or used for summary

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
    if (widget.preSelectedCropId != null) {
      _loadCropDetails(widget.preSelectedCropId!);
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _additionalNotesController.dispose();
    for (var rows in _previousInputsMap.values) {
      for (var row in rows) {
        row.controller.dispose();
      }
    }
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
    final validProductNames =
        _recommendationsList
            .where((r) => r.product.text.trim().isNotEmpty)
            .map((r) => r.product.text.trim())
            .toList();

    setState(() {
      // Keep existing data if the product name matches
      final existingMap = {
        for (var row in _costEstimations) row.productName: row,
      };
      _costEstimations.clear();

      for (var name in validProductNames) {
        if (existingMap.containsKey(name)) {
          _costEstimations.add(existingMap[name]!);
        } else {
          final newRow = CostEstimationRow(productName: name);
          // Auto-fill prices from product catalog
          final product = _productOptions.firstWhere(
            (p) => p['label'] == name,
            orElse: () => {},
          );
          if (product.isNotEmpty) {
            if (product['mrp'] != null)
              newRow.mrp.text = product['mrp'].toString();
            if (product['offer_price'] != null)
              newRow.offerPrice.text = product['offer_price'].toString();
          }
          _costEstimations.add(newRow);
        }
      }
      
      _autoCalculateQuantities();
    });
  }

  void _autoCalculateQuantities() {
    for (var row in _costEstimations) {
      // Find matching recommendation
      final rec = _recommendationsList.firstWhere(
        (r) => r.product.text == row.productName,
        orElse: () => RecommendationRow(),
      );

      if (rec.product.text.isEmpty) continue;

      final double dose = double.tryParse(rec.dose.text) ?? 0;
      if (dose == 0) continue;

      double totalRequired = 0;
      final perUnit = rec.perUnit?.toLowerCase() ?? '';
      
      if (perUnit.contains('acre')) {
        totalRequired = dose * _cropAcre;
      } else if (perUnit.contains('plant')) {
        totalRequired = dose * _cropCount;
      } else {
        // Default to 1 if no unit matched
        totalRequired = dose;
      }

      // Match with package size
      final pkgSizeStr = row.pkgSize.text;
      if (pkgSizeStr.isEmpty) continue;

      // Parse pkg size (e.g. "250ml" or "1kg")
      final double pkgValue =
          double.tryParse(pkgSizeStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (pkgValue == 0) continue;

      // Calculate quantity
      final double qty = totalRequired / pkgValue;
      row.qty.text = qty.ceil().toString();
    }
  }

  Future<void> _loadCropDetails(String cropId) async {
    try {
      final crops = await SupabaseService.getCrops(_selectedFarmId ?? widget.preSelectedFarmId ?? '');
      final crop = crops.firstWhere((c) => c['id'].toString() == cropId);
      
      setState(() {
        // Parse acre (e.g. "2.5 Acres")
        final acreStr = crop['acre'] as String? ?? '';
        _cropAcre = double.tryParse(acreStr.split(' ')[0]) ?? 0.0;
        
        // Parse count (e.g. "500 Plants")
        final countStr = crop['count'] as String? ?? '';
        _cropCount = int.tryParse(countStr.split(' ')[0]) ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading crop details for calculation: $e');
    }
  }

  Future<void> _loadFarms() async {
    final farms = await SupabaseService.getFarms();
    setState(() {
      _farms = farms;
      if (widget.preSelectedFarmId != null) {
        _selectedFarmId = widget.preSelectedFarmId;
        _loadCrops(_selectedFarmId!);
      }
    });
  }

  Future<void> _loadCrops(String farmId) async {
    final crops = await SupabaseService.getCrops(farmId);
    setState(() {
      _crops = crops;
      if (widget.preSelectedCropId != null) {
        _selectedCropId = widget.preSelectedCropId;
        _loadLastReportData(farmId, _selectedCropId!);

        // Find crop to load suggested problems
        final crop = _crops.firstWhere(
          (c) => c['id'].toString() == _selectedCropId,
          orElse: () => {},
        );
        if (crop.isNotEmpty && crop['dropdown_options'] != null) {
          final cropIntId = int.tryParse(
            crop['dropdown_options']['id'].toString(),
          );
          if (cropIntId != null) _loadSuggestedProblems(cropIntId);
        }
        if (widget.preSelectedFarmId != null && widget.preSelectedCropId != null) {
          _currentStep = 1;
        }
      } else {
        _selectedCropId = null;
        _suggestedProblems = [];
      }
    });
  }

  Future<void> _loadSuggestedProblems(int cropId) async {
    try {
      final mappings = await SupabaseService.getProblemsByCrop(cropId);
      setState(() {
        _suggestedProblems =
            mappings
                .map((m) => m['dropdown_options']?['label']?.toString())
                .whereType<String>()
                .toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchProblemData() async {
    try {
      final categories = await SupabaseService.getDropdownOptions(
        'problem_category',
      );
      final products = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      final applications = await SupabaseService.getDropdownOptions(
        'application_method',
      );
      final doseUnits = await SupabaseService.getDropdownOptions('dose_unit');
      final fillerUnits = await SupabaseService.getDropdownOptions(
        'filler_unit',
      );
      final fillerMaterials = await SupabaseService.getDropdownOptions(
        'filler_material',
      );
      final perUnits = await SupabaseService.getDropdownOptions('per_unit');

      setState(() {
        _productOptions = products;
        _applicationOptions = applications;
        _doseUnitOptions = doseUnits;
        _fillerUnitOptions = fillerUnits;
        _fillerMaterialOptions = fillerMaterials;
        _perUnitOptions = perUnits;
      });

      if (categories.isEmpty) return;

      Map<String, List<String>> dynamicProblems = {};

      for (var cat in categories) {
        final items = await SupabaseService.getDropdownOptions(
          'problem_item',
          parentId: cat['id'],
        );
        dynamicProblems[cat['label']] =
            items.map((e) => e['label'].toString()).toList();
      }

      if (dynamicProblems.isNotEmpty) {
        setState(() {
          _problemCategories = dynamicProblems;
        });
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _lastReport;

  Future<void> _loadLastReportData(String farmId, String cropId) async {
    if (_cropAcre == 0 && _cropCount == 0) {
      await _loadCropDetails(cropId);
    }
    final lastReport = await SupabaseService.getLastReportForCrop(
      farmId,
      cropId,
    );
    setState(() => _lastReport = lastReport);
  }

  void _importLastReportData() {
    if (_lastReport == null) return;
    final history = _lastReport!['previous_inputs'] as String?;

    setState(() {
      if (history != null && history.isNotEmpty) {
        // Clear existing and import
        _previousInputsMap = {
          'Pesticides': [],
          'Fungicides': [],
          'Fertilizers': [],
          'Bio Stimulant': [],
          'Herbicide': [],
        };

        final lines = history.split('\n');
        for (var line in lines) {
          String category = '';
          String content = '';
          if (line.startsWith('Pesticides:')) {
            category = 'Pesticides';
            content = line.replaceFirst('Pesticides:', '').trim();
          } else if (line.startsWith('Fungicides:')) {
            category = 'Fungicides';
            content = line.replaceFirst('Fungicides:', '').trim();
          } else if (line.startsWith('Fertilizers:')) {
            category = 'Fertilizers';
            content = line.replaceFirst('Fertilizers:', '').trim();
          } else if (line.startsWith('Bio Stimulant:')) {
            category = 'Bio Stimulant';
            content = line.replaceFirst('Bio Stimulant:', '').trim();
          } else if (line.startsWith('Herbicide:')) {
            category = 'Herbicide';
            content = line.replaceFirst('Herbicide:', '').trim();
          }

          if (category.isNotEmpty) {
            // Split by comma if there are multiple items
            final items = content.split(',');
            for (var item in items) {
              final trimmed = item.trim();
              if (trimmed.isNotEmpty) {
                final row = PreviousInputRow();
                row.controller.text = trimmed;
                _previousInputsMap[category]!.add(row);
              }
            }
          }
        }

        // Ensure at least one row exists if empty
        for (var cat in _previousInputsMap.keys) {
          if (_previousInputsMap[cat]!.isEmpty) {
            _previousInputsMap[cat]!.add(PreviousInputRow());
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Last visit data imported'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a signature to proceed'),
          backgroundColor: Colors.orange,
        ),
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
        signatureUrl = await SupabaseService.uploadImage(
          signatureBytes,
          sigFileName,
          'reports',
        );
      }

      // Handle Image Uploads
      Map<String, String> uploadedImageUrls = {};
      for (var entry in _problemImages.entries) {
        if (entry.value != null) {
          try {
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_${_problemImageNames[entry.key] ?? 'image.jpg'}';
            final url = await SupabaseService.uploadImage(
              entry.value!,
              fileName,
              'reports',
            );
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
        problemDataWithImages = problemDataWithImages.substring(
          0,
          problemDataWithImages.length - 2,
        );
      }
      if (_additionalNotesController.text.isNotEmpty) {
        problemDataWithImages +=
            '\nNotes: ${_additionalNotesController.text.trim()}';
      }

      String finalHistory = '';

      for (var entry in _previousInputsMap.entries) {
        final category = entry.key;
        final rows = entry.value;
        String categoryContent = '';

        for (var row in rows) {
          final text = row.controller.text.trim();
          if (text.isEmpty && row.image == null && row.date == null) continue;

          String itemString = text;
          if (row.date != null) {
            itemString += (itemString.isEmpty ? '' : ' ') + '[Date: ${_formatDate(row.date)}]';
          }

          if (row.image != null) {
            try {
              final fileName =
                  'prev_${DateTime.now().millisecondsSinceEpoch}_${row.imageName ?? 'image.jpg'}';
              final url = await SupabaseService.uploadImage(
                row.image!,
                fileName,
                'reports',
              );
              itemString += (itemString.isEmpty ? '' : ' ') + '{img: $url}';
            } catch (e) {
              debugPrint('Error uploading previous input image: $e');
            }
          }

          if (itemString.isNotEmpty) {
            categoryContent += (categoryContent.isEmpty ? '' : ', ') + itemString;
          }
        }

        if (categoryContent.isNotEmpty) {
          finalHistory += '$category: $categoryContent\n';
        }
      }

      String finalRecommendations = '';
      for (var row in _recommendationsList) {
        if (row.product.text.isNotEmpty) {
          finalRecommendations +=
              '${row.product.text} (${row.application.text}) - '
              'Dose: ${row.dose.text} ${row.doseUnit ?? ""} per ${row.perUnit ?? ""}, '
              'Filler: ${row.filler.text} ${row.fillerQty.text} ${row.fillerUnit ?? ""}\n';
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

        finalCost +=
            '${row.productName} (Pkg: ${row.pkgSize.text}) - '
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
        'follow_up_date': _nextVisitDate?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        // Only keep local bytes if upload failed (to save memory and prevent CursorWindow overflow)
        '_local_signature': signatureUrl == null ? signatureBytes : null,
        '_local_images': _problemImages.map((k, v) {
          // If we have an uploaded URL for this specific problem image, don't store bytes locally
          return MapEntry(k, uploadedImageUrls.containsKey(k) ? null : v);
        }),
      };

      if (kIsWeb) {
        await SupabaseService.addReport(reportData);
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'reports',
          data: reportData,
          operation: 'INSERT',
        );
        // Trigger sync
        SyncManager().sync();
      }

      if (mounted) {
        final farm = _farms.firstWhere(
          (f) => f['id'] == _selectedFarmId,
          orElse: () => {},
        );
        final crop = _crops.firstWhere(
          (c) => c['id'] == _selectedCropId,
          orElse: () => {},
        );
        final farmerNameForPdf = farm['farmers']?['name'] ?? 'Valued Farmer';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ReportGeneratorScreen(
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
    final pwSubtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_costEstimations.isNotEmpty)
          Text(
            'Grand Total: ₹${_calculateGrandTotal()}',
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        if (_nextVisitDate != null)
          Text(
            'Next Visit: ${_formatDate(_nextVisitDate)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create Analysis Report')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Stepper(
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
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text(
                                  _currentStep == 5
                                      ? 'Generate Analysis'
                                      : 'Next Step',
                                ),
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
                subtitle:
                    _selectedFarmId != null
                        ? Text(
                          '${_farms.firstWhere((f) => f['id'] == _selectedFarmId, orElse: () => {'name': 'Selected'})['name']} • '
                          '${_selectedCropId != null ? _crops.firstWhere((c) => c['id'] == _selectedCropId, orElse: () => {'name': 'Selected'})['name'] : 'Select Crop'}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 0,
                content: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFarmId,
                      decoration: const InputDecoration(
                        labelText: 'Choose Farm',
                      ),
                      items:
                          _farms
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f['id'].toString(),
                                  child: Text(f['name'] ?? 'Unknown'),
                                ),
                              )
                              .toList(),
                      onChanged:
                          widget.preSelectedFarmId != null
                              ? null
                              : (v) {
                                setState(() => _selectedFarmId = v);
                                _loadCrops(v!);
                              },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCropId,
                      decoration: const InputDecoration(
                        labelText: 'Choose Crop',
                      ),
                      items:
                          _crops
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'].toString(),
                                  child: Text(c['name'] ?? 'Unknown'),
                                ),
                              )
                              .toList(),
                      onChanged:
                          widget.preSelectedCropId != null
                              ? null
                              : (value) {
                                setState(() {
                                  _selectedCropId = value;
                                  _suggestedProblems = [];
                                });
                                if (value != null) {
                                  final cropIntId = int.tryParse(value);
                                  if (cropIntId != null) {
                                    _loadSuggestedProblems(cropIntId);
                                    _loadCropDetails(value);
                                  }
                                  if (_selectedFarmId != null) {
                                    _loadLastReportData(
                                      _selectedFarmId!,
                                      value,
                                    );
                                  }
                                }
                              },
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Identify Problem'),
                subtitle:
                    _selectedProblems.isNotEmpty
                        ? Text(
                          _selectedProblems.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 1,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose category and select problems found',
                      style: TextStyle(color: AppColors.textGray, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Category Cards
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          ['Pests', 'Diseases', 'Deficiency', 'Others']
                              .map(
                                (cat) => _buildCategoryCard(
                                  cat,
                                  cat == 'Pests'
                                      ? Icons.pest_control_rounded
                                      : cat == 'Diseases'
                                      ? Icons.coronavirus_rounded
                                      : cat == 'Deficiency'
                                      ? Icons.science_rounded
                                      : Icons.more_horiz_rounded,
                                ),
                              )
                              .toList(),
                    ),

                    if (_activeProblemCategory != null) ...[
                      const SizedBox(height: 24),

                      // Search Bar for Problems
                      TextField(
                        onChanged:
                            (v) => setState(() => _problemSearchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search in $_activeProblemCategory...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Problem Selection List (Cards)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.3),
                          ),
                        ),
                        child: _buildProblemItemList(),
                      ),
                    ],

                    if (_selectedProblems.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Selected Problems:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => setState(() => _selectedProblems.clear()),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _selectedProblems
                                .map((p) => _selectedProblemChip(p))
                                .toList(),
                      ),
                    ],

                    const SizedBox(height: 32),
                    const Text(
                      'Additional Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _additionalNotesController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Any other specific observations...',
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Previous Inputs'),
                subtitle: const Text(
                  'List products used since last visit',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
                isActive: _currentStep >= 2,
                content: Column(
                  children: [
                    if (_lastReport != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: _importLastReportData,
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Import from Last Visit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ),
                    ..._previousInputsMap.keys.map((category) => _buildPreviousInputCategory(category)),
                  ],
                ),
              ),
              Step(
                title: const Text('Recommendations'),
                subtitle:
                    _recommendationsList.any((r) => r.product.text.isNotEmpty)
                        ? Text(
                          '${_recommendationsList.where((r) => r.product.text.isNotEmpty).length} Products Recommended',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        )
                        : null,
                isActive: _currentStep >= 3,
                content: Column(
                  children: [
                    ..._recommendationsList.asMap().entries.map(
                      (entry) =>
                          _recommendationRowWidget(entry.key, entry.value),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _addRecommendationRow,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Product Recommendation'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('Estimated Cost'),
                subtitle:
                    _costEstimations.isNotEmpty || _nextVisitDate != null
                        ? pwSubtitle
                        : null,
                isActive: _currentStep >= 4,
                content: Column(
                  children: [
                    ..._costEstimations.map(
                      (row) => _costEstimationRowWidget(row),
                    ),
                    if (_costEstimations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Add products in Step 4 to see them here.',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Grand Total: ₹${_calculateGrandTotal()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null)
                            setState(() => _nextVisitDate = date);
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
                                  const Text(
                                    'Next Visit Date',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nextVisitDate == null
                                        ? 'Set Follow-up Date'
                                        : _formatDate(_nextVisitDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _nextVisitDate == null
                                              ? AppColors.textGray
                                              : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.event_repeat_rounded,
                                color: AppColors.primary,
                              ),
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
                subtitle: const Text(
                  'Sign below to finalize report',
                  style: TextStyle(fontSize: 10),
                ),
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
                          icon: const Icon(
                            Icons.clear_all_rounded,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Clear Signature',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '(Mandatory)',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    bool isSelected = _activeProblemCategory == title;
    int selectedCount =
        _selectedProblems.where((p) {
          return _problemCategories[title]?.contains(p) ?? false;
        }).length;

    return GestureDetector(
      onTap:
          () => setState(() {
            _activeProblemCategory = title;
            _problemSearchQuery = '';
          }),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.secondary.withOpacity(0.3),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 28,
                ),
                if (selectedCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$selectedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textBlack,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemItemList() {
    final items = _problemCategories[_activeProblemCategory] ?? [];
    final filtered =
        items
            .where(
              (item) => item.toLowerCase().contains(
                _problemSearchQuery.toLowerCase(),
              ),
            )
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No problems found in $_activeProblemCategory',
            style: const TextStyle(color: AppColors.textGray),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        bool isChecked = _selectedProblems.contains(item);
        bool isSuggested = _suggestedProblems.contains(item);

        return CheckboxListTile(
          value: isChecked,
          activeColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          title: Row(
            children: [
              Text(item, style: const TextStyle(fontSize: 14)),
              if (isSuggested) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Suggested',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedProblems.add(item);
              } else {
                _selectedProblems.remove(item);
              }
            });
          },
        );
      },
    );
  }

  Widget _selectedProblemChip(String item) {
    final hasImage = _problemImages[item] != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _pickImage(item, ImageSource.camera),
            icon: Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: hasImage ? Colors.green : AppColors.primary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            item,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap:
                () => setState(() {
                  _selectedProblems.remove(item);
                  _problemImages.remove(item);
                }),
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(String problem, ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _problemImages[problem] = bytes;
        _problemImageNames[problem] = image.name;
      });
    }
  }

  Widget _costEstimationRowWidget(CostEstimationRow row) {
    // Find the product and its variants
    final product = _productOptions.firstWhere(
      (p) => p['label'] == row.productName,
      orElse: () => {},
    );
    final List variants = product['variants'] ?? [];

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
          Text(
            row.productName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      variants.any((v) => v['label'] == row.pkgSize.text)
                          ? row.pkgSize.text
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Pkg Size',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items:
                      variants.map((v) {
                        return DropdownMenuItem<String>(
                          value: v['label'].toString(),
                          child: Text(
                            v['label'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    final variant = variants.firstWhere(
                      (v) => v['label'] == val,
                      orElse: () => {},
                    );
                    if (variant.isNotEmpty) {
                      setState(() {
                        row.pkgSize.text = val ?? '';
                        if (variant['mrp'] != null)
                          row.mrp.text = variant['mrp'].toString();
                        if (variant['offer_price'] != null)
                          row.offerPrice.text =
                              variant['offer_price'].toString();
                        _autoCalculateQuantities();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _miniField(row.qty, 'Qty #', isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniField(row.mrp, 'MRP', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(
                  row.offerPrice,
                  'Offer Price',
                  isNumber: true,
                ),
              ),
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
                child: Text(
                  'Total: ₹${q * offer}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
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

  Widget _miniField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _productOptions.any(
                              (p) => p['label'] == row.product.text,
                            )
                            ? row.product.text
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items:
                        _productOptions.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['label'].toString(),
                            child: Text(
                              p['label'].toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() {
                        row.product.text = val ?? '';
                      });
                      _syncCostEstimations();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_recommendationsList.length > 1)
                IconButton(
                  onPressed: () => _removeRecommendationRow(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _applicationOptions.any(
                            (a) => a['label'] == row.application.text,
                          )
                          ? row.application.text
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'Application',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  items:
                      _applicationOptions.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['label'].toString(),
                          child: Text(
                            a['label'].toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    setState(() {
                      row.application.text = val ?? '';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dose and Filler stacked vertically to prevent overflow
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.dose,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dose',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => _syncCostEstimations(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _doseUnitOptions.any(
                                  (u) => u['label'] == row.doseUnit,
                                )
                                ? row.doseUnit
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            _doseUnitOptions.map((u) {
                              return DropdownMenuItem<String>(
                                value: u['label'].toString(),
                                child: Text(
                                  u['label'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                        onChanged: (val) {
                          setState(() => row.doseUnit = val);
                          _syncCostEstimations();
                        },
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _perUnitOptions.any(
                                  (u) => u['label'] == row.perUnit,
                                )
                                ? row.perUnit
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Per',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            _perUnitOptions.map((u) {
                              return DropdownMenuItem<String>(
                                value: u['label'].toString(),
                                child: Text(
                                  u['label'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                        onChanged: (val) {
                          setState(() => row.perUnit = val);
                          _syncCostEstimations();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Filler Material Dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _fillerMaterialOptions.any(
                                  (m) => m['label'] == row.filler.text,
                                )
                                ? row.filler.text
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Filler (Material)',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            _fillerMaterialOptions.map((m) {
                              return DropdownMenuItem<String>(
                                value: m['label'].toString(),
                                child: Text(
                                  m['label'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (val) =>
                                setState(() => row.filler.text = val ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filler Qty
                    Expanded(
                      flex: 2,
                      child: _miniField(row.fillerQty, 'Qty', isNumber: true),
                    ),
                    const SizedBox(width: 8),
                    // Filler Unit Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _fillerUnitOptions.any(
                                  (u) => u['label'] == row.fillerUnit,
                                )
                                ? row.fillerUnit
                                : null,
                        decoration: const InputDecoration(
                          labelText: 'Qty/Unit',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            _fillerUnitOptions.map((u) {
                              return DropdownMenuItem<String>(
                                value: u['label'].toString(),
                                child: Text(
                                  u['label'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (val) => setState(() => row.fillerUnit = val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousInputCategory(String category) {
    final rows = _previousInputsMap[category] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textBlack,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _previousInputsMap[category]!.add(PreviousInputRow());
                });
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.controller,
                        decoration: InputDecoration(
                          hintText: 'Product Name...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (row.image != null)
                                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              IconButton(
                                icon: Icon(
                                  row.image == null ? Icons.camera_alt_rounded : Icons.image_rounded,
                                  size: 20,
                                  color: row.image == null ? AppColors.textGray : AppColors.primary,
                                ),
                                onPressed: () => _pickPreviousInputImage(category, index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (rows.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _previousInputsMap[category]!.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: row.date ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => row.date = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: row.date == null ? Colors.transparent : AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: row.date == null ? AppColors.secondary.withOpacity(0.5) : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: row.date == null ? AppColors.textGray : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          row.date == null ? 'Select Input Date' : _formatDate(row.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: row.date == null ? AppColors.textGray : AppColors.primary,
                            fontWeight: row.date == null ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _pickPreviousInputImage(String category, int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _previousInputsMap[category]![index].image = bytes;
        _previousInputsMap[category]![index].imageName = image.name;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class PreviousInputRow {
  final controller = TextEditingController();
  Uint8List? image;
  String? imageName;
  DateTime? date;
}

class RecommendationRow {
  final product = TextEditingController();
  final application = TextEditingController();
  final dose = TextEditingController();
  String? doseUnit;
  String? perUnit;
  final fillerQty = TextEditingController();
  final filler = TextEditingController();
  String? fillerUnit;
}

class CostEstimationRow {
  final String productName;
  final pkgSize = TextEditingController();
  final qty = TextEditingController();
  final mrp = TextEditingController();
  final offerPrice = TextEditingController();

  CostEstimationRow({required this.productName});
}
