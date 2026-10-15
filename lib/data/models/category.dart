/// A product category (row of the `categories` table).
class Category {
  const Category({required this.id, required this.name, this.isActive = true});

  final int id;
  final String name;
  final bool isActive;

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
