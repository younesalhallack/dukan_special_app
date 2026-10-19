import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/supplier.dart';
import '../../../l10n/l10n.dart';
import '../providers/suppliers_providers.dart';

/// Add or edit a supplier. An existing supplier can be hidden here (only
/// when he owes nothing).
class SupplierFormScreen extends ConsumerStatefulWidget {
  const SupplierFormScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.supplier;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final input = SupplierInput(
        name: _name.text,
        phone: _phone.text,
        notes: _notes.text,
      );
      final existing = widget.supplier;
      if (existing == null) {
        await repo.create(input);
      } else {
        await repo.update(existing.id, input);
      }
      ref.refreshSuppliers();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  Future<void> _hide() async {
    final l10n = context.l10n;
    final existing = widget.supplier;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hideSupplier),
        content: Text(l10n.hideSupplierConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(supplierRepositoryProvider).setActive(existing.id, false);
      ref.refreshSuppliers();
      if (!mounted) return;
      // Close this form and the statement of the hidden supplier.
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = widget.supplier != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editSupplier : l10n.addSupplier),
        actions: [
          if (isEdit)
            PopupMenuButton<int>(
              onSelected: (_) => _hide(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(l10n.hideSupplier)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.supplierName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.errInvalidName : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.phone,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.notes,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
