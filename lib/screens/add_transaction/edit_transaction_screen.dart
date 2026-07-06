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

    // Remove o sufixo "(recorrente X/Y)" para exibir só a descrição base
    String displayDescription = t.description;
    if (t.isRecurring) {
      displayDescription =
          t.description.replaceAll(RegExp(r'\s*\(recorrente \d+/\d+\)'), '');
    }

    _descriptionController = TextEditingController(text: displayDescription);
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

  // Diálogo de escolha para recorrentes
  Future<String?> _showRecurringEditDialog() async {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar evento recorrente'),
        content: const Text('O que você deseja alterar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'single'),
            child: const Text('Apenas este'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'subsequent'),
            child: const Text('Este e os seguintes'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final amount =
        double.parse(_amountController.text.replaceAll(',', '.'));
    final t = widget.transaction;

    if (t.isRecurring) {
      // Mostra diálogo de escolha
      final choice = await _showRecurringEditDialog();
      if (choice == null) return;

      if (choice == 'single') {
        await db.transactionDao.updateSingleRecurring(
          id: t.id,
          description: _descriptionController.text,
          amount: amount,
          date: _selectedDate,
          categoryId: _selectedCategoryId,
          paymentMethod: _paymentMethod,
        );
      } else {
        await db.transactionDao.updateSubsequentRecurring(
          groupId: t.installmentGroupId!,
          fromInstallmentNumber: t.installmentNumber!,
          baseDescription: _descriptionController.text,
          amount: amount,
          categoryId: _selectedCategoryId,
          paymentMethod: _paymentMethod,
        );
      }
    } else {
      // Edição normal (não recorrente)
      await db.transactionDao.updateTransactionById(
        id: t.id,
        description: _descriptionController.text,
        amount: amount,
        date: _selectedDate,
        categoryId: _selectedCategoryId,
        paymentMethod: _paymentMethod,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isRecurring = widget.transaction.isRecurring;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRecurring ? 'Editar recorrente' : 'Editar gasto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner informativo para recorrentes
            if (isRecurring)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.repeat, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transação recorrente — ${widget.transaction.installmentNumber}/${widget.transaction.totalInstallments}',
                        style: const TextStyle(
                            color: Colors.blueAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

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

            // Data só editável para transações não recorrentes
            if (!isRecurring)
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child:
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
            if (!isRecurring) const SizedBox(height: 16),

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
              data: (cats) {
                final isExpense = widget.transaction.isExpense;
                final filtered =
                    cats.where((c) => c.isExpense == isExpense).toList();
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