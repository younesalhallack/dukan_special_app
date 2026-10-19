/// A supplier (row of the `suppliers` table).
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final String createdAt;

  factory Supplier.fromMap(Map<String, Object?> map) {
    return Supplier(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAt: map['created_at'] as String,
    );
  }
}

/// Editable fields of a supplier.
class SupplierInput {
  const SupplierInput({required this.name, this.phone, this.notes});

  final String name;
  final String? phone;
  final String? notes;
}
