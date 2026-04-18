import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:uuid/uuid.dart';

class StockTransactionForm extends StatefulWidget {
  final String transactionType; // PURCHASE, DELIVERY, RETURN

  const StockTransactionForm({super.key, required this.transactionType});

  @override
  State<StockTransactionForm> createState() => _StockTransactionFormState();
}

class _StockTransactionFormState extends State<StockTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingData = true;

  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'Units');
  final _vendorNameController = TextEditingController();

  String? _selectedExecutiveId;
  String? _userRole;
  List<Map<String, dynamic>> _executives = [];

  // Product Dropdown Data
  List<Map<String, dynamic>> _masterProducts = [];
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = SupabaseService.client.auth.currentUser;
    final profile = await SupabaseService.getProfile();

    if (mounted) {
      setState(() {
        _userRole = profile?['role'];
        if (_userRole == 'executive') {
          _selectedExecutiveId = user?.id;
        }
      });
    }

    // Fetch Products (Hierarchical: Product -> Sizes)
    try {
      final products = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      if (mounted) setState(() => _masterProducts = products);
    } catch (e) {
      debugPrint('Error loading products: $e');
    }

    if (widget.transactionType == 'DELIVERY' ||
        widget.transactionType == 'RETURN') {
      // For Store users, show the dropdown. For Executives, we already set the ID.
      if (_userRole != 'executive') {
        final execs = await SupabaseService.getExecutives();
        if (mounted) {
          setState(() {
            _executives = execs;
            _isLoadingData = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingData = false);
      }
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      final transactionId = const Uuid().v4();

      final data = {
        'id': transactionId,
        'item_name': _itemNameController.text,
        'transaction_type': widget.transactionType,
        'quantity': double.parse(_quantityController.text),
        'unit': _unitController.text,
        'executive_id': _selectedExecutiveId,
        'vendor_name': _vendorNameController.text,
        'status': widget.transactionType == 'PURCHASE' ? 'ACCEPTED' : 'PENDING',
        'created_by': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (kIsWeb) {
        // Direct push for Web since local DB is disabled
        await SupabaseService.addStoreTransaction(data);
      } else {
        await LocalDatabaseService.saveAndQueue(
          tableName: 'store_transactions',
          data: data,
          operation: 'INSERT',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Record Stock';
    if (widget.transactionType == 'PURCHASE') title = 'Stock Purchase';
    if (widget.transactionType == 'DELIVERY') title = 'Stock Delivery';
    if (widget.transactionType == 'RETURN') title = 'Stock Return';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body:
          _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSectionTitle('Select Product'),
                    const SizedBox(height: 16),
                    _buildProductDropdown(),
                    if (_selectedProduct != null) ...[
                      const SizedBox(height: 16),
                      _buildVariantDropdown(),
                    ],
                    const SizedBox(height: 24),

                    _buildSectionTitle('Inventory Details'),
                    const SizedBox(height: 16),
                    _textField(
                      _itemNameController,
                      'Item Name',
                      'Select Product first',
                      Icons.inventory_2_rounded,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            _quantityController,
                            'Quantity',
                            '0.0',
                            Icons.numbers_rounded,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _textField(
                            _unitController,
                            'Unit',
                            'Select Product Size',
                            Icons.straighten_rounded,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (widget.transactionType == 'PURCHASE') ...[
                      _buildSectionTitle('Vendor Details'),
                      const SizedBox(height: 16),
                      _textField(
                        _vendorNameController,
                        'Vendor Name',
                        'Supplier Name',
                        Icons.store_rounded,
                      ),
                    ],

                    if (widget.transactionType == 'DELIVERY' ||
                        widget.transactionType == 'RETURN') ...[
                      if (_userRole != 'executive') ...[
                        _buildSectionTitle(
                          widget.transactionType == 'DELIVERY'
                              ? 'Delivery Target'
                              : 'Returning From',
                        ),
                        const SizedBox(height: 16),
                        _dropdownField(),
                      ],
                    ],

                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Record Transaction',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transaction will be marked as PENDING until verified by the other party.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isNumeric = false,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: readOnly ? Colors.grey[100] : Colors.white,
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildProductDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      initialValue: _selectedProduct,
      hint: const Text('Select Brand / Product'),
      decoration: InputDecoration(
        labelText: 'Product',
        prefixIcon: const Icon(Icons.shopping_bag_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          (_masterProducts).map((p) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: p,
              child: Text(p['label'] ?? 'Unknown'),
            );
          }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedProduct = val;
          _selectedVariant = null;
          _itemNameController.text = val?['label'] ?? '';
          _unitController.text = 'Units'; // Default
        });
      },
      validator: (val) => val == null ? 'Selection required' : null,
    );
  }

  Widget _buildVariantDropdown() {
    final List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(
      _selectedProduct?['variants'] ?? [],
    );

    return DropdownButtonFormField<Map<String, dynamic>>(
      initialValue: _selectedVariant,
      hint: const Text('Select Pocket/Pouch Size'),
      decoration: InputDecoration(
        labelText: 'Size',
        prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          (variants).map((v) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: v,
              child: Text(v['label'] ?? 'Unknown'),
            );
          }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedVariant = val;
          _unitController.text = val?['label'] ?? 'Units';
        });
      },
      validator: (val) => val == null ? 'Selection required' : null,
    );
  }

  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedExecutiveId,
      decoration: InputDecoration(
        labelText: 'Select Executive',
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          (_executives).map((exec) {
            return DropdownMenuItem<String>(
              value: exec['id'],
              child: Text(exec['full_name'] ?? 'Unknown'),
            );
          }).toList(),
      onChanged: (val) => setState(() => _selectedExecutiveId = val),
      validator: (val) => val == null ? 'Please select an executive' : null,
    );
  }
}
