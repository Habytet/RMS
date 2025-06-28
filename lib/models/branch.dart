// lib/models/branch.dart

class Branch {
  final String id;
  final String name;

  Branch({
    required this.id,
    required this.name,
  });

  // A factory constructor to create a Branch from a Firestore document.
  // It takes the document's ID and its data map.
  factory Branch.fromFirestore(String docId, Map<String, dynamic> data) {
    return Branch(
      id: docId,
      name: data['name'] ?? '', // Safely get the name, default to empty string if null
    );
  }
}
