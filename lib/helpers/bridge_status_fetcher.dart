import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;


int _monthFromString(String m) {
  switch (m.toLowerCase()) {
    case 'january':
    case 'jan': return 1;
    case 'february':
    case 'feb': return 2;
    case 'march':
    case 'mar': return 3;
    case 'april':
    case 'apr': return 4;
    case 'may': return 5;
    case 'june':
    case 'jun': return 6;
    case 'july':
    case 'jul': return 7;
    case 'august':
    case 'aug': return 8;
    case 'september':
    case 'sep':
    case 'sept': return 9;
    case 'october':
    case 'oct': return 10;
    case 'november':
    case 'nov': return 11;
    case 'december':
    case 'dec': return 12;
    default: throw ArgumentError('Unknown month: $m');
  }
}


class ClosurePeriod {
  final DateTime start;
  final DateTime end;
  ClosurePeriod({required this.start, required this.end});
}


class BridgeStatus {

  final List<ClosurePeriod> closures;


  final bool isClosed;


  final DateTime? nextClosure;


  final DateTime? nextOpening;


  final Duration? timeUntilNextChange;

  BridgeStatus({
    required this.closures,
    required this.isClosed,
    this.nextClosure,
    this.nextOpening,
    this.timeUntilNextChange,
  });
}

/// Fetches and computes the full BridgeStatus.
Future<BridgeStatus> checkRenfrewBridgeStatus() async {
  const url = 'https://www.renfrewshire.gov.uk/renfrew-bridge';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Page load failed (${response.statusCode})');
  }

  final document = parse(response.body);
  final container = document.querySelector('main') ?? document.body;
  if (container == null) {
    throw Exception('Could not find page content');
  }
  final text = container.text;

  final now = DateTime.now();
  final closures = _extractClosureTimes(text);

  print(closures.length);

  // sort by start
  closures.sort((a, b) => a.start.compareTo(b.start));

  bool isClosed = false;
  DateTime? nextClosure;
  DateTime? nextOpening;
  Duration? timeUntilNextChange;

  // find if we're in a closure
  for (final period in closures) {
    if (now.isAfter(period.start) && now.isBefore(period.end)) {
      isClosed = true;
      nextOpening = period.end;
      timeUntilNextChange = period.end.difference(now);
      break;
    }
    if (now.isBefore(period.start)) {
      // first upcoming closure
      nextClosure = period.start;
      timeUntilNextChange = period.start.difference(now);
      break;
    }
  }
  // if we passed all closures and still open => no more closures today
  if (!isClosed && nextClosure == null) {
    timeUntilNextChange = null;
  }

  return BridgeStatus(
    closures: closures,
    isClosed: isClosed,
    nextClosure: nextClosure,
    nextOpening: nextOpening,
    timeUntilNextChange: timeUntilNextChange,
  );
}

List<ClosurePeriod> _extractClosureTimes(String text) {
  //find the date header: “Friday 9 May” or “Friday 9th May”
  final dateRe = RegExp(
    r'(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)',
    caseSensitive: false,
  );
  final dateMatch = dateRe.firstMatch(text);
  final now    = DateTime.now();
  late DateTime scheduleDate;
  if (dateMatch != null) {
    final day   = int.parse(dateMatch.group(1)!);
    final month = _monthFromString(dateMatch.group(2)!);
    scheduleDate = DateTime(now.year, month, day);
  } else {
    // fallback to today if we can’t find it
    scheduleDate = DateTime(now.year, now.month, now.day);
  }

  //pull out all “hh:mm am to hh:mm pm” spans
  final timeRe = RegExp(
    r'(\d{1,2}(?:[:\.]\d{2})\s*[ap]m)\s+to\s+(\d{1,2}(?:[:\.]\d{2})\s*[ap]m)',
    caseSensitive: false,
  );
  final periods = <ClosurePeriod>[];

  for (final m in timeRe.allMatches(text)) {
    final start = _parseTime(m.group(1)!, scheduleDate);
    var   end   = _parseTime(m.group(2)!, scheduleDate);
    if (start != null && end != null) {
      //if it didn’t move forward, it must cross midnight
      if (!end.isAfter(start)) {
        end = end.add(Duration(days: 1));
      }
      //dedupe
      if (!periods.any((p) => p.start == start && p.end == end)) {
        periods.add(ClosurePeriod(start: start, end: end));
      }
    }
  }

  return periods;
}



DateTime? _parseTime(String timestr, DateTime ref) {
  final fmt = RegExp(r'(\d{1,2})[:\.](\d{2})\s*([ap]m)', caseSensitive: false);
  final m = fmt.firstMatch(timestr.toLowerCase());
  if (m == null) return null;

  int h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ap = m.group(3)!; // "am"/"pm"
  if (ap == 'pm' && h != 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;

  final datePart = DateTime(ref.year, ref.month, ref.day, h, min);
  return datePart;
}
