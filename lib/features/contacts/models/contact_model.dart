class ContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String relation;
  final int priority;
  final bool isPrimary;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relation,
    required this.priority,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'relation': relation,
    'priority': priority,
    'isPrimary': isPrimary,
  };

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      relation: json['relation'] ?? '',
      priority: json['priority'] ?? 1,
      isPrimary: json['isPrimary'] ?? false,
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? relation,
    int? priority,
    bool? isPrimary,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relation: relation ?? this.relation,
      priority: priority ?? this.priority,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
