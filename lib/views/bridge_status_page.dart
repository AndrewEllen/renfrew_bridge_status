import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
      // You can handle the error here however you like
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
      // swallow errors here; the FutureBuilder will show them
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
                          const Text('Today’s closure times:'),
                          ...status.closures.map((c) {
                            final fmt = TimeOfDay.fromDateTime(c.start)
                                .format(context);
                            final fte = TimeOfDay.fromDateTime(c.end)
                                .format(context);
                            return Text('• $fmt – $fte');
                          }),
                          const SizedBox(height: 16),
                        ] else
                          const Text('No closures listed for today.'),
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