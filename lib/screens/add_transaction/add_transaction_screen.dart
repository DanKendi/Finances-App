import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../utils/providers.dart';
import '../../utils/constants.dart';
import '../../main.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  String _paymentMethod = 'pix';
  bool _isExpense = true;
  bool _isInstallment = false;
  int _installmentCount = 2;

  final List<String> _paymentMethods = ['pix', 'débito', 'cartão', 'dinheiro'];

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
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma categoria')),
        );
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    if (_isInstallment && _isExpense) {
      await db.transactionDao.insertInstallmentPurchase(
        InstallmentPurchasesCompanion.insert(
          description: _descriptionController.text,
          totalAmount: amount,
          totalInstallments: _installmentCount,
          startDate: _selectedDate,
          categoryId: _selectedCategoryId!,
          paymentMethod: Value(_paymentMethod),
        ),
      );
    } else {
      await db.transactionDao.insertTransaction(
        TransactionsCompanion.insert(
          description: _descriptionController.text,
          amount: amount,
          date: _selectedDate,
          isExpense: Value(_isExpense),
          categoryId: _selectedCategoryId!,
          paymentMethod: Value(_paymentMethod),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpense ? 'Adicionar gasto' : 'Adicionar receita'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Toggle gasto/receita
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isExpense = true;
                        _selectedCategoryId = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isExpense ? Colors.redAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward,
                                size: 16,
                                color: _isExpense ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Gasto',
                              style: TextStyle(
                                color: _isExpense ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isExpense = false;
                        _selectedCategoryId = null;
                        _isInstallment = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isExpense ? Colors.greenAccent.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward,
                                size: 16,
                                color: !_isExpense ? Colors.white : Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Receita',
                              style: TextStyle(
                                color: !_isExpense ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Descrição
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

            // Valor
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Data
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

            // Forma de pagamento
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

            // Categorias filtradas por tipo
            categoriesAsync.when(
              data: (cats) {
                final filtered =
                    cats.where((c) => c.isExpense == _isExpense).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categoria',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filtered.map((cat) {
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
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
            ),
            const SizedBox(height: 16),

            // Parcelamento (só para gastos)
            if (_isExpense) ...[
              SwitchListTile(
                value: _isInstallment,
                onChanged: (v) => setState(() => _isInstallment = v),
                title: const Text('Compra parcelada'),
                secondary: const Icon(Icons.credit_card),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              if (_isInstallment) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Número de parcelas:'),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        if (_installmentCount > 2) {
                          setState(() => _installmentCount--);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_installmentCount x',
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      onPressed: () {
                        if (_installmentCount < 24) {
                          setState(() => _installmentCount++);
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (_amountController.text.isNotEmpty)
                  Text(
                    '${_installmentCount}x de R\$ ${((double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0) / _installmentCount).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isExpense ? 'Salvar gasto' : 'Salvar receita'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    _isExpense ? Colors.redAccent : Colors.greenAccent.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}