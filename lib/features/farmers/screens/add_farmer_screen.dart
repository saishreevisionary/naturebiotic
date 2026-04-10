import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class AddFarmerScreen extends StatefulWidget {
  final Map<String, dynamic>? farmer;
  const AddFarmerScreen({super.key, this.farmer});

  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _villageController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCategory = 'Warm';
  List<String> _categories = ['Hot', 'Warm', 'Cold'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.farmer != null) {
      _nameController.text = widget.farmer!['name'] ?? '';
      _villageController.text = widget.farmer!['village'] ?? '';
      _mobileController.text = widget.farmer!['mobile'] ?? '';
      _addressController.text = widget.farmer!['address'] ?? '';
      _selectedCategory = widget.farmer!['category'] ?? 'Warm';
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final options = await SupabaseService.getDropdownOptions('farmer_category');
      if (options.isNotEmpty) {
        setState(() {
          _categories = options.map((e) => e['label'].toString()).toList();
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'village': _villageController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'address': _addressController.text.trim(),
        'category': _selectedCategory,
      };

      if (widget.farmer != null) {
        await SupabaseService.updateFarmer(widget.farmer!['id'].toString(), data);
      } else {
        await SupabaseService.addFarmer(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.farmer != null ? 'Farmer Updated Successfully' : 'Farmer Added Successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
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

  Future<void> _pickAndUploadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        setState(() => _isLoading = true);
        
        final file = result.files.first;
        String input;
        
        if (file.bytes != null) {
          input = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          input = await File(file.path!).readAsString();
        } else {
          throw 'File could not be read';
        }
        
        List<List<dynamic>> rows = const CsvToListConverter().convert(input);
        
        if (rows.isEmpty) throw 'CSV is empty';
        
        // Assume first row is header
        final headers = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
        final dataRows = rows.sublist(1);
        
        List<Map<String, dynamic>> farmers = [];
        for (var row in dataRows) {
          if (row.isEmpty) continue;
          
          Map<String, dynamic> farmer = {};
          for (int i = 0; i < headers.length; i++) {
            if (i < row.length) {
              String key = headers[i];
              String? dbKey;
              
              if (key.contains('name')) dbKey = 'name';
              else if (key.contains('mobile') || key.contains('phone')) dbKey = 'mobile';
              else if (key.contains('village')) dbKey = 'village';
              else if (key.contains('address')) dbKey = 'address';
              else if (key.contains('category')) dbKey = 'category';
              
              if (dbKey != null) {
                String val = row[i].toString().trim();
                if (dbKey == 'category') {
                  // DB requires exact case: Hot, Warm, or Cold
                  String normalized = val.toLowerCase();
                  if (normalized.contains('hot')) val = 'Hot';
                  else if (normalized.contains('warm')) val = 'Warm';
                  else if (normalized.contains('cold')) val = 'Cold';
                  else val = 'Warm'; // Fallback
                }
                farmer[dbKey] = val;
              }
            }
          }
          
          // Basic validation: name is required
          if (farmer['name'] != null && farmer['name'].toString().isNotEmpty) {
            // Ensure all recognized keys exist in every map to maintain consistent schema
            for (var k in ['mobile', 'village', 'address', 'category']) {
              farmer[k] ??= (k == 'category' ? 'Warm' : null);
            }
            farmers.add(farmer);
          }
        }
        
        if (farmers.isEmpty) throw 'No valid farmer records found. Ensure CSV has a "name" column.';
        
        await SupabaseService.addFarmersBulk(farmers);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${farmers.length} Farmers Uploaded Successfully'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pop(context);
        }
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

  Future<void> _downloadTemplate() async {
    try {
      setState(() => _isLoading = true);
      
      const headers = ['name', 'mobile', 'village', 'address', 'category'];
      const exampleRow = ['John Doe', '9876543210', 'Greenfield', '123 Main St', 'Warm'];
      
      String csvContent = const ListToCsvConverter().convert([headers, exampleRow]);
      
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Template',
        fileName: 'farmer_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(csvContent),
      );

      if (outputPath != null && !kIsWeb) {
        final file = File(outputPath);
        await file.writeAsString(csvContent);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template Downloaded Successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading template: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.farmer != null ? 'Edit Farmer' : 'Add Farmer'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _downloadTemplate,
            icon: const Icon(Icons.file_download),
            tooltip: 'Download CSV Template',
          ),
          IconButton(
            onPressed: _isLoading ? null : _pickAndUploadCsv,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload CSV',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Farmer Information',
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
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter farmer name',
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter mobile number',
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _villageController,
                      decoration: const InputDecoration(
                        labelText: 'Village',
                        hintText: 'Enter village name',
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Other Details',
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
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter complete address',
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        fillColor: Colors.white,
                      ),
                       items: _categories.map((String category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.farmer != null ? 'Update Farmer Details' : 'Submit Farmer Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
