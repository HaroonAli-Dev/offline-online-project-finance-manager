class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.fullName,
    required this.isActive,
    required this.roleCodes,
    required this.roleNames,
    this.phoneNumber,
    this.email,
    this.address,
    this.notes,
  });

  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final List<String> roleCodes;
  final List<String> roleNames;
}
