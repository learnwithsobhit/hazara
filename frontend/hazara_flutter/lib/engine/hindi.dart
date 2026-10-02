import '../model/playing_card.dart';
import 'classifier.dart';

/// Table words in Hindi, shown beside the English names.
const List<String> kHindiSetNames = [
  'सबसे मजबूत',
  'दूसरा',
  'तीसरा',
  'चौथा सेट',
];

const String kHindiTapSet = 'पत्ती चुनें, फिर इस सेट पर टैप करें';
const String kHindiPlaceAll = 'सभी 13 पत्ते सेट में रखें';
const String kHindiSparePoints =
    'बाकी की पत्ती — यह सेट जीतने पर इसके अंक मिलते हैं';
const String kHindiCountsForRank = 'मजबूती इन्हीं पत्तों से तय होती है';

const _rank = <Rank, String>{
  Rank.ace: 'इक्का',
  Rank.king: 'बादशाह',
  Rank.queen: 'रानी',
  Rank.jack: 'गुलाम',
  Rank.ten: 'दहला',
  Rank.nine: 'नहला',
  Rank.eight: 'अट्ठा',
  Rank.seven: 'सत्ता',
  Rank.six: 'छक्का',
  Rank.five: 'पंज',
  Rank.four: 'चौका',
  Rank.three: 'तीगा',
  Rank.two: 'दुक्की',
};

const _plural = <Rank, String>{
  Rank.ace: 'इक्के',
  Rank.king: 'बादशाह',
  Rank.queen: 'रानियाँ',
  Rank.jack: 'गुलाम',
  Rank.ten: 'दहले',
  Rank.nine: 'नहले',
  Rank.eight: 'अट्ठे',
  Rank.seven: 'सत्ते',
  Rank.six: 'छक्के',
  Rank.five: 'पंज',
  Rank.four: 'चौके',
  Rank.three: 'तीगे',
  Rank.two: 'दुक्की',
};

const _englishPlural = <String, Rank>{
  'Aces': Rank.ace,
  'Kings': Rank.king,
  'Queens': Rank.queen,
  'Jacks': Rank.jack,
  'Tens': Rank.ten,
  'Nines': Rank.nine,
  'Eights': Rank.eight,
  'Sevens': Rank.seven,
  'Sixes': Rank.six,
  'Fives': Rank.five,
  'Fours': Rank.four,
  'Threes': Rank.three,
  'Twos': Rank.two,
};

const _englishToken = <String, Rank>{
  'A': Rank.ace,
  'K': Rank.king,
  'Q': Rank.queen,
  'J': Rank.jack,
  '10': Rank.ten,
  '9': Rank.nine,
  '8': Rank.eight,
  '7': Rank.seven,
  '6': Rank.six,
  '5': Rank.five,
  '4': Rank.four,
  '3': Rank.three,
  '2': Rank.two,
};

String? hindiFromLabel(String label) {
  if (label.startsWith('Troy of ')) {
    final word = _pluralWord(label.substring('Troy of '.length));
    return word == null ? null : 'ट्रॉय · तीन $word';
  }
  if (label.startsWith('Pair of ')) {
    final word = _pluralWord(label.substring('Pair of '.length));
    return word == null ? null : 'जोड़ी · दो $word';
  }
  if (label.startsWith('Colour Run: ')) {
    final ranks = _rankRun(label.substring('Colour Run: '.length));
    return ranks == null ? null : 'कलर रन · $ranks · एक रंग';
  }
  if (label.startsWith('Run: ')) {
    final ranks = _rankRun(label.substring('Run: '.length));
    return ranks == null ? null : 'रन · $ranks';
  }
  if (label.startsWith('Colour: ')) {
    final ranks = _rankRun(label.substring('Colour: '.length));
    return ranks == null ? null : 'कलर · $ranks · एक रंग';
  }
  if (label.startsWith('Indi: ')) {
    final ranks = _rankRun(label.substring('Indi: '.length));
    return ranks == null ? null : 'इंडी · $ranks';
  }
  return null;
}

String hindiCombo(Combo combo) => hindiFromLabel(combo.label) ?? combo.label;

String? hindiSetDetail({
  required int placed,
  required int size,
  required String status,
}) {
  if (placed == 0) return kHindiTapSet;
  if (placed < 3) return '$size में से $placed पत्ते';
  return hindiFromLabel(status);
}

String hindiOrderWarning(int inversion) {
  if (inversion == 2) {
    return 'चौथा सेट तीसरे से मजबूत है। चौथा सेट सबसे कमजोर रहना चाहिए।';
  }
  final lower = kHindiSetNames[inversion + 1];
  final upper = kHindiSetNames[inversion];
  return '$lower $upper से मजबूत है। जगह बदलें।';
}

String? _pluralWord(String english) {
  final rank = _englishPlural[english.trim()];
  if (rank == null) return null;
  return _plural[rank];
}

String? _rankRun(String joined) {
  final parts = joined.split('\u2013');
  final names = <String>[];
  for (final part in parts) {
    final rank = _englishToken[part.trim()];
    if (rank == null) return null;
    names.add(_rank[rank]!);
  }
  return names.join('\u2013');
}
