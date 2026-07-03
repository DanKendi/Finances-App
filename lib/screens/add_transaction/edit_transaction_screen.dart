import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../utils/providers.dart';
import '../../utils/constants.dart';
import '../../main.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final Transaction transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState
    extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  late int _selectedCategoryId;
  late String _paymentMethod;

  final List<String> _paymentMethods = ['pix', 'débito', 'cartão', 'dinheiro'];

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _descriptionController = TextEditingController(text: t.description);
    _amountController =
        TextEditingController(text: t.amount.toStringAsFixed(2));
    _selectedDate = t.date;
    _selectedCategoryId = t.categoryId;
    _paymentMethod = t.paymentMethod;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final amount =
        double.parse(_amountController.text.replaceAll(',', '.'));

    await db.transactionDao.updateTransactionById(
      id: widget.transaction.id,
      description: _descriptionController.text,
      amount: amount,
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      paymentMethod: _paymentMethod,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: _paymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (cats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categoria',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      final color = hexToColor(cat.color);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(cat.name),
                        avatar: Icon(
                          categoryIcons[cat.icon] ?? Icons.category,
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                        selectedColor: color,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = cat.id),
                      );
                    }).toList(),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Salvar alterações'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}