// ignore_for_file: file_names

class LanguageOption {
  final String flag;
  final String name;
  final String code;

  LanguageOption({required this.flag, required this.name, required this.code});
}

class LangOptions {
  static final List<LanguageOption> languages = [
    LanguageOption(flag: '🇬🇧', name: 'English (UK)', code: 'en_GB'),
    LanguageOption(flag: '🇺🇸', name: 'English (US)', code: 'en_US'),
    LanguageOption(flag: '🇻🇳', name: 'Vietnam', code: 'vi'),
    LanguageOption(flag: '🇹🇭', name: 'Thailand', code: 'th'),
    LanguageOption(flag: '🇧🇪', name: 'Belgium', code: 'nl'),
    LanguageOption(flag: '🇫🇷', name: 'French', code: 'fr'),
    LanguageOption(flag: '🇰🇷', name: 'Korea', code: 'ko'),
    LanguageOption(flag: '🇮🇳', name: 'India', code: 'hi'),
    LanguageOption(flag: '🇯🇵', name: 'Japan', code: 'ja'),
    LanguageOption(flag: '🇨🇳', name: 'China', code: 'zh'),
    LanguageOption(flag: '🇩🇪', name: 'Germany', code: 'de'),
    LanguageOption(flag: '🇪🇸', name: 'Spanish', code: 'es'),
    LanguageOption(flag: '🇷🇺', name: 'Rusia', code: 'ru'),
    LanguageOption(flag: '🇮🇹', name: 'Italia', code: 'it'),
    LanguageOption(flag: '🇵🇹', name: 'Portuguese', code: 'pt'),
    LanguageOption(flag: '🇮🇩', name: 'Indonesia', code: 'id'),
    LanguageOption(flag: '🇲🇾', name: 'Malaysia', code: 'ms'),
  ];
}
