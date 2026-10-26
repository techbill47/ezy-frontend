class AppUser {
  const AppUser({required this.id, required this.matricule, required this.fullName, required this.role, required this.departmentId, required this.departmentName, required this.year});
  final String id, matricule, fullName, role, departmentName;
  final int departmentId, year;
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final department = json['department'];
    return AppUser(id: '${json['id'] ?? ''}', matricule: '${json['matricule'] ?? ''}', fullName: '${json['fullName'] ?? ''}', role: '${json['role'] ?? 'student'}', departmentId: int.tryParse('${json['departmentId'] ?? (department is Map ? department['id'] : '')}') ?? 0, departmentName: '${json['departmentName'] ?? (department is Map ? department['name'] : '') ?? ''}', year: int.tryParse('${json['year'] ?? 1}') ?? 1);
  }
  Map<String, dynamic> toJson() => {'id': id, 'matricule': matricule, 'fullName': fullName, 'role': role, 'departmentId': departmentId, 'departmentName': departmentName, 'year': year};
}
