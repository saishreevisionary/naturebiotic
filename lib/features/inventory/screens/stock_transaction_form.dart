import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:nature_biotic/core/theme.dart';
import 'package:nature_biotic/services/supabase_service.dart';
import 'package:nature_biotic/services/local_database_service.dart';
import 'package:nature_biotic/services/sync_manager.dart';
import 'package:uuid/uuid.dart';

class StockTransactionForm extends StatefulWidget {
  final String transactionType; // PURCHASE, DELIVERY, RETURN
  final Map<String, dynamic>? initialData;

  const StockTransactionForm({
    super.key, 
    required this.transactionType,
    this.initialData,
  });

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
  final _buyerNameController = TextEditingController();

  String? _selectedExecutiveId;
  String? _userRole;
  List<Map<String, dynamic>> _executives = [];
  Map<int, String> _productVendors = {};
  Map<String, Map<String, double>> _detailedStock = {};

  // Product Dropdown Data
  List<Map<String, dynamic>> _masterProducts = [];
  List<_StockItem> _items = [];

  @override
  void initState() {
    super.initState();
    _items = [ _StockItem() ];
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

    try {
      final products = await SupabaseService.getHierarchicalDropdownOptions(
        'product_name',
      );
      final vendorMappings = await SupabaseService.getDropdownOptions(
        'product_vendor_map',
      );

      final Map<int, String> vendorMap = {};
      for (var mapping in vendorMappings) {
        if (mapping['parent_id'] != null) {
          vendorMap[mapping['parent_id'] as int] = mapping['label'] ?? '';
        }
      }

      if (mounted) {
        setState(() {
          _masterProducts = products;
          _productVendors = vendorMap;

          // If editing, populate the form
          if (widget.initialData != null) {
            final data = widget.initialData!;
            _vendorNameController.text = data['vendor_name'] ?? '';
            _selectedExecutiveId = data['executive_id'];

            _items = [];
            // Find and set selected product and variant
            for (var p in products) {
              if (p['label'] == data['item_name']) {
                final item = _StockItem(
                  product: p,
                  qty: data['quantity']?.toString(),
                  unit: data['unit']?.toString(),
                );
                
                final variants = List<Map<String, dynamic>>.from(p['variants'] ?? []);
                for (var v in variants) {
                  if (v['label'] == item.unitController.text) {
                    item.variant = v;
                    break;
                  }
                }
                _items.add(item);
                break;
              }
            }
            if (_items.isEmpty) _items = [ _StockItem() ];
          }
        });
      }
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
        // Fetch detailed stock for validation
        final stock = await SupabaseService.getDetailedExecutiveStock();
        if (mounted) {
          setState(() {
            _detailedStock = stock;
            _isLoadingData = false;
          });
        }
      }
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submit() async {
    // Custom validation check
    if (widget.transactionType == 'DELIVERY' && _userRole == 'store') {
      if (_selectedExecutiveId == null && _buyerNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an executive or enter buyer name'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;

    // --- VALIDATION ---
    for (var item in _items) {
      if (item.product == null || item.variant == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select product and size for all items'), backgroundColor: Colors.red),
        );
        return;
      }
      
      final double qty = double.tryParse(item.quantityController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity for all items'), backgroundColor: Colors.red),
        );
        return;
      }

      if (_userRole == 'executive' && widget.transactionType == 'RETURN') {
        final productName = item.product?['label'] ?? '';
        final variantName = item.variant?['label'] ?? '';
        final availableQty = _detailedStock[productName]?[variantName] ?? 0.0;
        
        if (qty > availableQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Insufficient stock for $productName ($variantName). Available: $availableQty'),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      final transactionId = const Uuid().v4();

      final isDirectPurchase = widget.transactionType == 'DELIVERY' && 
                               _userRole == 'store' && 
                               _selectedExecutiveId == null &&
                               _buyerNameController.text.trim().isNotEmpty;

      final List<Map<String, dynamic>> transactionList = [];
      
      for (var item in _items) {
        final transactionId = const Uuid().v4();
        transactionList.add({
          'id': widget.initialData?['id'] ?? transactionId,
          'item_name': item.product?['label'] ?? '',
          'transaction_type': widget.transactionType,
          'quantity': double.parse(item.quantityController.text),
          'unit': item.unitController.text,
          'executive_id': isDirectPurchase ? null : _selectedExecutiveId,
          'vendor_name': isDirectPurchase ? _buyerNameController.text.trim() : _vendorNameController.text,
          'status': (widget.transactionType == 'PURCHASE' || isDirectPurchase) ? 'ACCEPTED' : 'PENDING',
          'created_by': user?.id,
          'created_at': widget.initialData?['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          if (isDirectPurchase) 'accepted_at': DateTime.now().toIso8601String(),
        });
      }

      if (kIsWeb) {
        if (widget.initialData != null) {
          await SupabaseService.updateStoreTransaction(transactionList.first['id'], transactionList.first);
        } else {
          for (var data in transactionList) {
            await SupabaseService.addStoreTransaction(data);
          }
        }
      } else {
        for (var data in transactionList) {
          await LocalDatabaseService.saveAndQueue(
            tableName: 'store_transactions',
            data: data,
            operation: widget.initialData != null ? 'UPDATE' : 'INSERT',
          );
        }
        // Trigger immediate sync to push the transaction to Supabase for the receiver
        SyncManager().sync();
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
                    if (widget.transactionType == 'PURCHASE') ...[
                      _buildSectionTitle('Vendor Details'),
                      const SizedBox(height: 16),
                      _textField(
                        _vendorNameController,
                        'Vendor Name',
                        'Supplier Name',
                        Icons.store_rounded,
                      ),
                      const SizedBox(height: 24),
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
                        const SizedBox(height: 24),
                        
                        if (_userRole == 'store' && widget.transactionType == 'DELIVERY') ...[
                          _buildSectionTitle('Direct Purchase (Optional)'),
                          const SizedBox(height: 8),
                          Text(
                            'Enter buyer name ONLY if selling directly from store without an executive.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 12),
                          AbsorbPointer(
                            absorbing: _selectedExecutiveId != null,
                            child: Opacity(
                              opacity: _selectedExecutiveId != null ? 0.5 : 1.0,
                              child: _textField(
                                _buyerNameController,
                                'Buyer Name',
                                _selectedExecutiveId != null ? 'Clear executive to use direct sale' : 'Who bought this?',
                                Icons.person_add_alt_1_rounded,
                                optional: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ],

                    _buildSectionTitle('Product Items'),
                    const SizedBox(height: 16),
                    ..._items.asMap().entries.map((entry) => _buildItemCard(entry.key, entry.value)),
                    
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _items.add(_StockItem())),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Another Product'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),

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

  Widget _buildQuantityUnitFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle('Inventory Details'),
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
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isNumeric = false,
    bool readOnly = false,
    bool optional = false,
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
      validator: (value) {
        if (optional) return null;
        return value == null || value.isEmpty ? 'Required' : null;
      },
    );
  }

  Widget _dropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedExecutiveId,
      decoration: InputDecoration(
        labelText: 'Select Executive',
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: (_executives).map((exec) {
        return DropdownMenuItem<String>(
          value: exec['id'],
          child: Text(exec['full_name'] ?? 'Unknown'),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedExecutiveId = val);
        if (val != null) {
          _buyerNameController.clear();
        }
      },
      validator: (val) {
        if (widget.transactionType == 'DELIVERY' && _userRole == 'store') {
          return null;
        }
        return val == null ? 'Please select an executive' : null;
      },
    );
  }

  Widget _buildItemCard(int index, _StockItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              if (_items.length > 1)
                IconButton(
                  onPressed: () => setState(() => _items.removeAt(index)),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProductDropdownFor(item),
          if (item.product != null) ...[
            const SizedBox(height: 12),
            _buildVariantDropdownFor(item),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _textField(
                  item.quantityController,
                  'Quantity',
                  '0.0',
                  Icons.numbers_rounded,
                  isNumeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  item.unitController,
                  'Unit',
                  'Size',
                  Icons.straighten_rounded,
                  readOnly: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdownFor(_StockItem item) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: item.product,
      hint: const Text('Select Product'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Product',
        prefixIcon: const Icon(Icons.shopping_bag_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _masterProducts.map((p) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: p,
          child: Text(p['label'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          item.product = val;
          item.variant = null;
          item.unitController.text = 'Units';
          if (val != null && _productVendors.containsKey(val['id'])) {
             if (_vendorNameController.text.isEmpty) {
               _vendorNameController.text = _productVendors[val['id']]!;
             }
          }
        });
      },
    );
  }

  Widget _buildVariantDropdownFor(_StockItem item) {
    final List<Map<String, dynamic>> variants = List<Map<String, dynamic>>.from(
      item.product?['variants'] ?? [],
    );
    
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: item.variant,
      hint: const Text('Select Size'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Size',
        prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: variants.map((v) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: v,
          child: Text(v['label'] ?? 'Unknown', style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          item.variant = val;
          item.unitController.text = val?['label'] ?? 'Units';
        });
      },
    );
  }
}

class _StockItem {
  Map<String, dynamic>? product;
  Map<String, dynamic>? variant;
  final quantityController = TextEditingController();
  final unitController = TextEditingController(text: 'Units');
  
  _StockItem({this.product, this.variant, String? qty, String? unit}) {
    if (qty != null) quantityController.text = qty;
    if (unit != null) unitController.text = unit;
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
  }
}
