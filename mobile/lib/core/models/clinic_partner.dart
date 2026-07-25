class ClinicPartner {
  final String id;
  final String clinicName;
  final String? phone;
  final String? address;

  const ClinicPartner({
    required this.id,
    required this.clinicName,
    this.phone,
    this.address,
  });

  factory ClinicPartner.fromJson(Map<String, dynamic> json) => ClinicPartner(
        id: json['id'] as String,
        clinicName: json['clinic_name'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
      );
}
