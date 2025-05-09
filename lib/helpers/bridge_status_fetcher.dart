import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

/// A single closure window.
class ClosurePeriod {
  final DateTime start;
  final DateTime end;
  ClosurePeriod({required this.start, required this.end});
}

/// The aggregated bridge status for “today”.
class BridgeStatus {
  /// All closure windows (today).
  final List<ClosurePeriod> closures;

  /// True if we’re inside one of those windows right now.
  final bool isClosed;

  /// If open: the next closure start; if closed: null.
  final DateTime? nextClosure;

  /// If closed: the end of current window; if open: null.
  final DateTime? nextOpening;

  /// Time until that next change.
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
  final closures = _extractClosureTimes(text, now);

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

List<ClosurePeriod> _extractClosureTimes(String text, DateTime refDate) {
  final regex = RegExp(
    r'(\d{1,2}(?:[:\.]\d{2})\s*[ap]m)\s+to\s+(\d{1,2}(?:[:\.]\d{2})\s*[ap]m)',
    caseSensitive: false,
  );

  final List<ClosurePeriod> periods = [];
  for (final m in regex.allMatches(text)) {
    final start = _parseTime(m.group(1)!, refDate);
    var end   = _parseTime(m.group(2)!, refDate);

    if (start != null && end != null) {
      // normalize cross-midnight spans:
      if (!end.isAfter(start)) {
        end = end.add(Duration(days: 1));
      }

      final candidate = ClosurePeriod(start: start, end: end);
      if (!periods.any((p) =>
      p.start == candidate.start && p.end == candidate.end
      )) {
        periods.add(candidate);
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
