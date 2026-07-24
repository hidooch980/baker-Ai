import 'package:flutter/material.dart';
import '../../core/localization/fa_numbers.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// مدیریت محصولات: فهرست، افزودن، ویرایش و حذف محصول.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get('/products');
      setState(() {
        _products = (response.data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  double _priceOf(Map<String, dynamic> product) {
    return double.tryParse(product['price']?.toString() ?? '') ?? 0;
  }

  Future<void> _showProductForm({Map<String, dynamic>? product}) async {
    final isEdit = product != null;
    final codeController = TextEditingController(text: product?['code']?.toString() ?? '');
    final nameController = TextEditingController(text: product?['name']?.toString() ?? '');
    final typeController = TextEditingController(text: product?['type']?.toString() ?? '');
    final weightController = TextEditingController(text: product?['weightGrams']?.toString() ?? '');
    final unitController = TextEditingController(text: product?['unit']?.toString() ?? 'عدد');
    final priceController = TextEditingController(text: isEdit ? _priceOf(product).toStringAsFixed(0) : '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'ویرایش محصول' : 'محصول جدید'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'کد محصول *')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام محصول *')),
              TextField(controller: typeController, decoration: const InputDecoration(labelText: 'نوع (مثلاً سنگک، بربری)')),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'وزن (گرم)'),
              ),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: 'واحد')),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'قیمت فروش (تومان) *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
        ],
      ),
    );
    if (saved != true) return;

    final code = codeController.text.trim();
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    if (code.isEmpty || name.isEmpty || price == null || price <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد، نام و قیمت معتبر الزامی است.')));
      return;
    }

    final weight = double.tryParse(weightController.text.trim());
    final payload = {
      'code': code,
      'name': name,
      if (typeController.text.trim().isNotEmpty) 'type': typeController.text.trim(),
      if (weight != null) 'weightGrams': weight,
      if (unitController.text.trim().isNotEmpty) 'unit': unitController.text.trim(),
      'price': price,
    };

    try {
      if (isEdit) {
        await ApiClient.instance.dio.patch('/products/${product['id']}', data: payload);
      } else {
        await ApiClient.instance.dio.post('/products', data: payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'محصول ویرایش شد.' : 'محصول ثبت شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف محصول'),
        content: Text('آیا از حذف «${product['name']}» مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.instance.dio.delete('/products/${product['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('محصول حذف شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت محصولات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(),
        icon: const Icon(Icons.add),
        label: const Text('محصول جدید'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _products.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('محصولی ثبت نشده است.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final weight = product['weightGrams'];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.breakfast_dining_outlined),
                                title: Text('${product['name']} (${product['code']})'),
                                subtitle: Text(
                                  '${FaNumbers.formatCurrency(_priceOf(product))} تومان / ${product['unit'] ?? 'عدد'}'
                                  '${weight != null ? ' — ${weight.toString()} گرم' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'ویرایش',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _showProductForm(product: product),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteProduct(product),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
