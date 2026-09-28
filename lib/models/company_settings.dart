import '../core/constants/app_constants.dart';

class CompanySettings {
  final String companyName;
  final String companySubtitle;
  final String phone;
  final String address;
  final String email;
  final String gstNumber;
  final String website;
  final String termsAndConditions;
  final String invoicePrefix;
  final int startingInvoiceNumber;
  final String financialYear;
  final String? customLogoPath;

  const CompanySettings({
    this.companyName = AppConstants.defaultCompanyName,
    this.companySubtitle = AppConstants.defaultCompanySubtitle,
    this.phone = AppConstants.defaultCompanyPhone,
    this.address = AppConstants.defaultCompanyAddress,
    this.email = AppConstants.defaultCompanyEmail,
    this.gstNumber = AppConstants.defaultCompanyGst,
    this.website = '',
    this.termsAndConditions = AppConstants.defaultTerms,
    this.invoicePrefix = AppConstants.defaultInvoicePrefix,
    this.startingInvoiceNumber = 1,
    this.financialYear = '26-27',
    this.customLogoPath,
  });

  CompanySettings copyWith({
    String? companyName,
    String? companySubtitle,
    String? phone,
    String? address,
    String? email,
    String? gstNumber,
    String? website,
    String? termsAndConditions,
    String? invoicePrefix,
    int? startingInvoiceNumber,
    String? financialYear,
    String? customLogoPath,
    bool clearCustomLogo = false,
  }) {
    return CompanySettings(
      companyName: companyName ?? this.companyName,
      companySubtitle: companySubtitle ?? this.companySubtitle,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      website: website ?? this.website,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      startingInvoiceNumber: startingInvoiceNumber ?? this.startingInvoiceNumber,
      financialYear: financialYear ?? this.financialYear,
      customLogoPath: clearCustomLogo ? null : (customLogoPath ?? this.customLogoPath),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companySubtitle': companySubtitle,
      'phone': phone,
      'address': address,
      'email': email,
      'gstNumber': gstNumber,
      'website': website,
      'termsAndConditions': termsAndConditions,
      'terms': termsAndConditions,
      'invoicePrefix': invoicePrefix,
      'startingInvoiceNumber': startingInvoiceNumber,
      'financialYear': financialYear,
      'customLogoPath': customLogoPath,
    };
  }

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      companyName: (map['companyName'] as String?) ?? AppConstants.defaultCompanyName,
      companySubtitle: (map['companySubtitle'] as String?) ?? AppConstants.defaultCompanySubtitle,
      phone: (map['phone'] as String?) ?? AppConstants.defaultCompanyPhone,
      address: (map['address'] as String?) ?? AppConstants.defaultCompanyAddress,
      email: (map['email'] as String?) ?? AppConstants.defaultCompanyEmail,
      gstNumber: (map['gstNumber'] as String?) ?? AppConstants.defaultCompanyGst,
      website: (map['website'] as String?) ?? '',
      termsAndConditions: (map['termsAndConditions'] as String?) ?? (map['terms'] as String?) ?? AppConstants.defaultTerms,
      invoicePrefix: (map['invoicePrefix'] as String?) ?? AppConstants.defaultInvoicePrefix,
      startingInvoiceNumber: (map['startingInvoiceNumber'] as int?) ?? 1,
      financialYear: (map['financialYear'] as String?) ?? '26-27',
      customLogoPath: map['customLogoPath'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory CompanySettings.fromFirestore(Map<String, dynamic> data) => CompanySettings.fromMap(data);
}
