import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  AppLocalizations(this.locale);
  
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Tartheeb',
      'tagline': 'Madrasa Management App',
      'login': 'Login',
      'register': 'Register',
      'dashboard': 'Dashboard',
      'students': 'Students',
      'teachers': 'Teachers',
      'batches': 'Batches',
      'attendance': 'Attendance',
      'fees': 'Fees',
      'settings': 'Settings',
      'logout': 'Logout',
      'biometrics': 'Biometrics',
      'more': 'More',
      'home': 'Home',
    },
    'ml': {
      'app_name': 'തർത്തീബ്',
      'tagline': 'മദ്രസ മാനേജ്മെന്റ് ആപ്പ്',
      'login': 'ലോഗിൻ',
      'register': 'രജിസ്റ്റർ ചെയ്യുക',
      'dashboard': 'ഡാഷ്ബോർഡ്',
      'students': 'വിദ്യാർത്ഥികൾ',
      'teachers': 'അധ്യാപകർ',
      'batches': 'ബാച്ചുകൾ',
      'attendance': 'ഹാജർ',
      'fees': 'ഫീസ്',
      'settings': 'സെറ്റിങ്സ്',
      'logout': 'ലോഗൗട്ട്',
      'biometrics': 'ബയോമെട്രിക്സ്',
      'more': 'കൂടുതൽ',
      'home': 'ഹോം',
    },
  };

  String t(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ml'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class AppLocale extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  AppLocale() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString('language_code');
    if (savedLanguageCode != null) {
      _currentLocale = Locale(savedLanguageCode);
      notifyListeners();
    }
  }

  Future<void> switchLocale(String languageCode) async {
    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }
}
