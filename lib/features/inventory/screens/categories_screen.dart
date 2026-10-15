import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../data/models/category.dart';
import '../../../l10n/l10n.dart';
import '../providers/inventory_providers.dart';
import '../widgets/name_dialog.dart';

/// Add, rename and delete categories.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.refreshInventory();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l10n, e))));
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await showNameDialog(
      context,
      title: l10n.newCategory,
      label: l10n.categoryName,
    );
    if (name == null || !context.mounted) return;
    await _run(context, ref, () => ref.read(categoryRepositoryProvider).create(name));
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final l10n = context.l10n;
    final name = await showNameDialog(
      context,
      title: l10n.rename,
      label: l10n.categoryName,
      initial: category.name,
    );
    if (name == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(categoryRepositoryProvider).rename(category.id, name),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category.name),
        content: Text(l10n.deleteCategoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(categoryRepositoryProvider).delete(category.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(categoriesProvider);
    final categories = async.value;

    Widget body;
    if (categories == null) {
      body = async.hasError
          ? Center(child: Text('${async.error}'))
          : const Center(child: CircularProgressIndicator());
    } else if (categories.isEmpty) {
      body = Center(child: Text(l10n.noCategories));
    } else {
      body = ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ListTile(
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.rename,
                  onPressed: () => _rename(context, ref, category),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: () => _delete(context, ref, category),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, ref),
        tooltip: l10n.newCategory,
        child: const Icon(Icons.add),
      ),
      body: body,
    );
  }
}
