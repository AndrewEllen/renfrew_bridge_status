import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../helpers/bridge_status_fetcher.dart';
import '../widgets/smart_refresh_indicator.dart';

class BridgeStatusPage extends StatefulWidget {
  const BridgeStatusPage({Key? key}) : super(key: key);

  @override
  State<BridgeStatusPage> createState() => _BridgeStatusPageState();
}

class _BridgeStatusPageState extends State<BridgeStatusPage> {
  late Future<BridgeStatus> _statusFuture;
  Timer? _refreshTimer;

  final String _url = 'https://www.renfrewshire.gov.uk/renfrew-bridge';

  Future<void> _launchURL() async {
    final uri = Uri.parse(_url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {

      throw 'Could not launch $_url';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchStatus();

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 2, seconds: 30),
          (_) => _fetchStatus(),
    );
  }

  void _fetchStatus() {
    setState(() {
      _statusFuture = checkRenfrewBridgeStatus();
    });
  }

  Future<void> _handleRefresh() async {
    _fetchStatus();
    try {
      // wait for the new fetch to complete so the indicator disappears at the right time
      await _statusFuture;
    } catch (_) {
      debugPrint("Refresh Error");
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }


  /// Returns “Today”, “Tomorrow”, or a full day-of-week + date.
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEEE, d MMMM').format(dateOnly);
  }

  /// Groups closures by their start‐date and builds a list of Widgets.
  List<Widget> _buildClosureGroups(
      List<ClosurePeriod> closures, BuildContext context) {
    // 1) group by date
    final Map<DateTime, List<ClosurePeriod>> groups = {};
    for (var c in closures) {
      final key = DateTime(c.start.year, c.start.month, c.start.day);
      groups.putIfAbsent(key, () => []).add(c);
    }
    // 2) sort dates
    final dates = groups.keys.toList()..sort();
    final widgets = <Widget>[];

    for (var date in dates) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '${_formatDateHeader(date)} closures:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (var c in groups[date]!) {
        final startFmt = TimeOfDay.fromDateTime(c.start).format(context);
        final endFmt   = TimeOfDay.fromDateTime(c.end).format(context);
        widgets.add(Text('• $startFmt – $endFmt'));
      }
    }

    return widgets;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Renfrew Bridge Status"),
        actions: [
          TextButton(
            onPressed: _launchURL,
            child: Text("Check Website"),
          )
        ],
      ),
      body: SmartRefreshIndicator(
        onRefresh: _handleRefresh,
        child: Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: FutureBuilder<BridgeStatus>(
              future: _statusFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: CircularProgressIndicator(),
                  );
                } else if (snap.hasError) {
                  return Text("Error: ${snap.error}");
                } else if (!snap.hasData) {
                  return const Text("No data");
                }
                final status = snap.data!;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status.isClosed ? 'CLOSED' : 'OPEN',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color:
                            status.isClosed ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (status.closures.isNotEmpty) ...[
                          ..._buildClosureGroups(status.closures, context),
                          const SizedBox(height: 16),
                        ] else
                          const Text('No closures listed.'),
                        if (status.timeUntilNextChange != null) ...[
                          status.isClosed
                              ? Text(
                            'Opens in ${_formatDuration(status.timeUntilNextChange!)}',
                          )
                              : Text(
                            'Closes in ${_formatDuration(status.timeUntilNextChange!)}',
                          ),
                        ] else
                          const Text('No more changes today.'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '$h h $m m';
    if (h > 0) return '$h h';
    return '$m m';
  }
}