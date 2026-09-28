import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/company_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/company_settings.dart';

class SettingsRepository {
  static const String _kCompanyName = 'company_name';
  static const String _kCompanySubtitle = 'company_subtitle';
  static const String _kPhone = 'company_phone';
  static const String _kAddress = 'company_address';
  static const String _kEmail = 'company_email';
  static const String _kGstNumber = 'company_gst';
  static const String _kWebsite = 'company_website';
  static const String _kTerms = 'company_terms';
  static const String _kInvoicePrefix = 'invoice_prefix';
  static const String _kStartingSeq = 'starting_invoice_number';
  static const String _kFinancialYear = 'financial_year';
  static const String _kCustomLogoPath = 'custom_logo_path';

  DocumentReference<Map<String, dynamic>> get _docRef =>
      CompanyConfig.settingsDoc();

  Future<CompanySettings> loadSettings() async {
    // First try Firestore
    try {
      final doc = await _docRef.get();
      if (doc.exists && doc.data() != null) {
        final settings = CompanySettings.fromFirestore(doc.data()!);
        // Save to SharedPreferences for instant local fallback
        await _saveToLocalPrefs(settings);
        return settings;
      }
    } catch (_) {
      // Offline or network error: fallback to SharedPreferences
    }

    return _loadFromLocalPrefs();
  }

  Future<CompanySettings> _loadFromLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return CompanySettings(
      companyName: prefs.getString(_kCompanyName) ?? AppConstants.defaultCompanyName,
      companySubtitle: prefs.getString(_kCompanySubtitle) ?? AppConstants.defaultCompanySubtitle,
      phone: prefs.getString(_kPhone) ?? AppConstants.defaultCompanyPhone,
      address: prefs.getString(_kAddress) ?? AppConstants.defaultCompanyAddress,
      email: prefs.getString(_kEmail) ?? AppConstants.defaultCompanyEmail,
      gstNumber: prefs.getString(_kGstNumber) ?? AppConstants.defaultCompanyGst,
      website: prefs.getString(_kWebsite) ?? '',
      termsAndConditions: prefs.getString(_kTerms) ?? AppConstants.defaultTerms,
      invoicePrefix: prefs.getString(_kInvoicePrefix) ?? AppConstants.defaultInvoicePrefix,
      startingInvoiceNumber: prefs.getInt(_kStartingSeq) ?? 1,
      financialYear: prefs.getString(_kFinancialYear) ?? '26-27',
      customLogoPath: prefs.getString(_kCustomLogoPath),
    );
  }

  Future<void> _saveToLocalPrefs(CompanySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompanyName, settings.companyName);
    await prefs.setString(_kCompanySubtitle, settings.companySubtitle);
    await prefs.setString(_kPhone, settings.phone);
    await prefs.setString(_kAddress, settings.address);
    await prefs.setString(_kEmail, settings.email);
    await prefs.setString(_kGstNumber, settings.gstNumber);
    await prefs.setString(_kWebsite, settings.website);
    await prefs.setString(_kTerms, settings.termsAndConditions);
    await prefs.setString(_kInvoicePrefix, settings.invoicePrefix);
    await prefs.setInt(_kStartingSeq, settings.startingInvoiceNumber);
    await prefs.setString(_kFinancialYear, settings.financialYear);
    if (settings.customLogoPath != null) {
      await prefs.setString(_kCustomLogoPath, settings.customLogoPath!);
    } else {
      await prefs.remove(_kCustomLogoPath);
    }
  }

  Future<void> saveSettings(CompanySettings settings) async {
    // 1. Update SharedPreferences
    await _saveToLocalPrefs(settings);

    // 2. Update Firestore
    try {
      await _docRef.set(
        settings.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      // Offline persistence will queue the write
    }
  }
}
