import 'package:flutter/material.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddFarmScreen extends StatefulWidget {
  final Map<String, dynamic>? farm;
  final String? farmerId;
  const AddFarmScreen({super.key, this.farm, this.farmerId});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  final _areaController = TextEditingController();
  
  String _soilType = 'Loomy';
  String _irrigationType = 'Flood';
  String _waterSource = 'Well';
  String _waterQty = 'Ample';
  String _powerSource = 'EB';

  List<String> _soilTypes = ['Red', 'Black', 'Loomy', 'Aluvial'];
  List<String> _irrigationTypes = ['Flood', 'Drip irrigation'];
  List<String> _waterSources = ['Well', 'Borewell', 'canal/Pond', 'River/Stream'];
  List<String> _waterQtys = ['Ample', 'surplus', 'Scarcity'];
  List<String> _powerSources = ['EB', 'Diesel Pump', 'Solar'];

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
    if (widget.farm != null) {
      _isEdit = true;
      _nameController.text = widget.farm!['name'] ?? '';
      _placeController.text = widget.farm!['place'] ?? '';
      _areaController.text = (widget.farm!['area'] ?? '').toString();
      _soilType = widget.farm!['soil_type'] ?? 'Loomy';
      _irrigationType = widget.farm!['irrigation_type'] ?? 'Flood';
      _waterSource = widget.farm!['water_source'] ?? 'Well';
      _waterQty = widget.farm!['water_quantity'] ?? 'Ample';
      _powerSource = widget.farm!['power_source'] ?? 'EB';
    }
  }

  Future<void> _fetchOptions() async {
    try {
      final results = await Future.wait([
        SupabaseService.getDropdownOptions('soil_type'),
        SupabaseService.getDropdownOptions('irrigation_type'),
        SupabaseService.getDropdownOptions('water_source'),
        SupabaseService.getDropdownOptions('water_quantity'),
        SupabaseService.getDropdownOptions('power_source'),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].isNotEmpty) _soilTypes = results[0].map((e) => e['label'].toString()).toList();
          if (results[1].isNotEmpty) _irrigationTypes = results[1].map((e) => e['label'].toString()).toList();
          if (results[2].isNotEmpty) _waterSources = results[2].map((e) => e['label'].toString()).toList();
          if (results[3].isNotEmpty) _waterQtys = results[3].map((e) => e['label'].toString()).toList();
          if (results[4].isNotEmpty) _powerSources = results[4].map((e) => e['label'].toString()).toList();
          
          // Ensure selected values are in the lists
          if (!_soilTypes.contains(_soilType)) _soilType = _soilTypes.first;
          if (!_irrigationTypes.contains(_irrigationType)) _irrigationType = _irrigationTypes.first;
          if (!_waterSources.contains(_waterSource)) _waterSource = _waterSources.first;
          if (!_waterQtys.contains(_waterQty)) _waterQty = _waterQtys.first;
          if (!_powerSources.contains(_powerSource)) _powerSource = _powerSources.first;
        });
      }
    } catch (_) {}
  }

  Future<String> _getAddressFromCoordinatesWeb(double lat, double lng) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng');
      // Nominatim requires a user-agent
      final response = await http.get(url, headers: {'User-Agent': 'NatureBioticApp/1.0'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? "$lat, $lng";
      }
    } catch (_) {}
    return "$lat, $lng";
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      } 

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      // Web does not support reverse geocoding with this plugin
      if (kIsWeb) {
        final address = await _getAddressFromCoordinatesWeb(position.latitude, position.longitude);
        setState(() {
          _placeController.text = address;
        });
        return;
      }

      // Reverse geocoding (Mobile only)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}";
          // Clean up address (remove double commas/spaces)
          address = address.replaceAll(RegExp(r',\s*,'), ',').trim();
          if (address.startsWith(',')) address = address.substring(1).trim();
          
          setState(() {
            _placeController.text = address;
          });
        } else {
          setState(() {
            _placeController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
          });
        }
      } catch (_) {
        // If geocoding fails, fallback to coordinates
        setState(() {
          _placeController.text = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final farmData = {
        'name': _nameController.text.trim(),
        'place': _placeController.text.trim(),
        'area': double.tryParse(_areaController.text) ?? 0.0,
        'soil_type': _soilType,
        'irrigation_type': _irrigationType,
        'water_source': _waterSource,
        'water_quantity': _waterQty,
        'power_source': _powerSource,
        'farmer_id': widget.farmerId ?? widget.farm?['farmer_id'],
      };

      if (_isEdit) {
        await SupabaseService.updateFarm(widget.farm!['id'], farmData);
      } else {
        await SupabaseService.addFarm(farmData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Farm Updated Successfully' : 'Farm Registered Successfully'), 
            backgroundColor: AppColors.primary
          ),
        );
        Navigator.pop(context);
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
        title: Text(_isEdit ? 'Edit Farm' : 'Add Farm'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Farm Details',
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Farm Name',
                        hintText: 'e.g. Green Valley Farm',
                        fillColor: Colors.white,
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _placeController,
                      decoration: InputDecoration(
                        labelText: 'Farm Location / Place',
                        hintText: 'Enter farm location',
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: _isLocationLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                          onPressed: _isLocationLoading ? null : _fetchCurrentLocation,
                          tooltip: 'Get Current Location',
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Total Area (Acres)',
                        hintText: 'Enter area in acres',
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown('Soil Type', _soilTypes, _soilType, (v) => setState(() => _soilType = v ?? _soilType)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Infrastructure & Resources',
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
                    _buildDropdown('Irrigation Type', _irrigationTypes, _irrigationType, (v) => setState(() => _irrigationType = v ?? _irrigationType)),
                    const SizedBox(height: 16),
                    _buildDropdown('Water Source', _waterSources, _waterSource, (v) => setState(() => _waterSource = v ?? _waterSource)),
                    const SizedBox(height: 16),
                    _buildDropdown('Water Quantity', _waterQtys, _waterQty, (v) => setState(() => _waterQty = v ?? _waterQty)),
                    const SizedBox(height: 16),
                    _buildDropdown('Power Source', _powerSources, _powerSource, (v) => setState(() => _powerSource = v ?? _powerSource)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Soil & Water Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2), style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload PDF or Image',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Max size 5MB',
                      style: TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Browse Files'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEdit ? 'Update Farm Details' : 'Save Farm Details'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        fillColor: Colors.white,
      ),
      items: items.map((String item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
