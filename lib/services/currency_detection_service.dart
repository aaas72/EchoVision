import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ── Arabic numeral mapping ──
const _arabicDigits = {
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

// ── Currency denomination → Turkish speech ──
const _turkishLira = <int, String>{
  5: 'beş Türk Lirası',
  10: 'on Türk Lirası',
  20: 'yirmi Türk Lirası',
  50: 'elli Türk Lirası',
  100: 'yüz Türk Lirası',
  200: 'iki yüz Türk Lirası',
};

const _usDollar = <int, String>{
  1: 'bir Amerikan Doları',
  2: 'iki Amerikan Doları',
  5: 'beş Amerikan Doları',
  10: 'on Amerikan Doları',
  20: 'yirmi Amerikan Doları',
  50: 'elli Amerikan Doları',
  100: 'yüz Amerikan Doları',
};

const _euro = <int, String>{
  5: 'beş Euro',
  10: 'on Euro',
  20: 'yirmi Euro',
  50: 'elli Euro',
  100: 'yüz Euro',
  200: 'iki yüz Euro',
  500: 'beş yüz Euro',
};

const _saudiRiyal = <int, String>{
  1: 'bir Suudi Riyali',
  5: 'beş Suudi Riyali',
  10: 'on Suudi Riyali',
  50: 'elli Suudi Riyali',
  100: 'yüz Suudi Riyali',
  200: 'iki yüz Suudi Riyali',
  500: 'beş yüz Suudi Riyali',
};

/// Keywords found on real banknotes that identify the currency.
const _currencyKeywords = <String, String>{
  // Saudi Riyal
  'المملكة العربية السعودية': 'SAR',
  'saudi arabian': 'SAR',
  'saudi arabia': 'SAR',
  'monetary agency': 'SAR',
  'monetary authority': 'SAR',
  'ريال': 'SAR',
  'riyal': 'SAR',
  'riyals': 'SAR',
  'sar': 'SAR',
  // US Dollar
  'federal reserve': 'USD',
  'united states': 'USD',
  'dollar': 'USD',
  'dollars': 'USD',
  'the united states of america': 'USD',
  'in god we trust': 'USD',
  'this note is legal tender': 'USD',
  'washington': 'USD',
  'franklin': 'USD',
  // Euro
  'european central bank': 'EUR',
  'euro': 'EUR',
  'ecb': 'EUR',
  'bce': 'EUR',
  'ezb': 'EUR',
  // Turkish Lira
  'türkiye cumhuriyet': 'TRY',
  'merkez bankasi': 'TRY',
  'türk lirasi': 'TRY',
  'lira': 'TRY',
  'türkiye': 'TRY',
  'turkiye': 'TRY',
  'cumhuriyet': 'TRY',
};

/// Which denomination table to use for each currency code.
final _denominationTables = <String, Map<int, String>>{
  'SAR': _saudiRiyal,
  'USD': _usDollar,
  'EUR': _euro,
  'TRY': _turkishLira,
};

/// Service for detecting currency banknotes using ML Kit Text Recognition.
class CurrencyDetectionService {
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _textRecognizer = TextRecognizer();
    _isInitialized = true;
  }

  /// Convert Arabic/Eastern numerals to Western digits.
  String _normalizeDigits(String text) {
    var result = text;
    _arabicDigits.forEach((arabic, western) {
      result = result.replaceAll(arabic, western);
    });
    return result;
  }

  /// Extract all numbers from text (both isolated and adjacent to letters).
  List<int> _extractNumbers(String text) {
    final normalized = _normalizeDigits(text);
    final matches = RegExp(r'(\d+)').allMatches(normalized);
    final numbers = <int>[];
    for (final m in matches) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 0 && n <= 1000) {
        numbers.add(n);
      }
    }
    return numbers;
  }

  /// Identify which currency the banknote belongs to by scanning keywords.
  String? _identifyCurrency(String text) {
    final lower = text.toLowerCase();
    for (final entry in _currencyKeywords.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Analyze a captured image for currency banknote.
  Future<String?> analyzeImage(XFile imageFile) async {
    if (!_isInitialized || _textRecognizer == null) return null;

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer!.processImage(inputImage);

    final allText = recognizedText.text;
    print('Currency OCR raw: "$allText"');

    if (allText.trim().isEmpty) return null;

    // 1. Identify the currency from keywords on the banknote
    final currencyCode = _identifyCurrency(allText);
    print('Currency identified: $currencyCode');

    // 2. Extract all numbers from the text
    final numbers = _extractNumbers(allText);
    print('Numbers found: $numbers');

    // 3. If we identified a currency, look up the denomination
    if (currencyCode != null) {
      final table = _denominationTables[currencyCode];
      if (table != null) {
        // Try each number, preferring valid denominations
        for (final n in numbers) {
          if (table.containsKey(n)) {
            return table[n];
          }
        }
        // If currency keyword found but no exact denomination match,
        // use the largest number as an approximation
        if (numbers.isNotEmpty) {
          final largest = numbers.reduce((a, b) => a > b ? a : b);
          // Find the closest denomination
          final closest = _findClosestDenomination(largest, table);
          if (closest != null) return closest;
          // Fall back to raw number + currency name
          return _rawCurrencyName(largest, currencyCode);
        }
      }
    }

    // 4. No currency keyword → try all tables for matching denomination
    if (numbers.isNotEmpty) {
      // Default to TRY since app is in Turkish
      for (final n in numbers) {
        if (_turkishLira.containsKey(n)) return _turkishLira[n];
      }
      for (final n in numbers) {
        if (_usDollar.containsKey(n)) return _usDollar[n];
      }
      for (final n in numbers) {
        if (_euro.containsKey(n)) return _euro[n];
      }
      for (final n in numbers) {
        if (_saudiRiyal.containsKey(n)) return _saudiRiyal[n];
      }
    }

    // 5. If text was found but nothing matched, return readable text
    final cleaned = allText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 2) {
      return 'Okunan metin: $cleaned';
    }

    return null;
  }

  /// Find the closest denomination in a table.
  String? _findClosestDenomination(int value, Map<int, String> table) {
    final keys = table.keys.toList()..sort();
    for (final k in keys) {
      if ((k - value).abs() <= 2) return table[k];
    }
    return null;
  }

  /// Fallback: raw number + currency name in Turkish.
  String _rawCurrencyName(int value, String code) {
    switch (code) {
      case 'TRY':
        return '$value Türk Lirası';
      case 'USD':
        return '$value Amerikan Doları';
      case 'EUR':
        return '$value Euro';
      case 'SAR':
        return '$value Suudi Riyali';
      default:
        return '$value';
    }
  }

  Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
    _isInitialized = false;
  }
}
