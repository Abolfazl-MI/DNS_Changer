// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dns_changer/model/dns_model.dart';
import 'package:dns_changer/service/dns_service.dart';

class FastestDNSPage extends StatefulWidget {
  final void Function(DnsModel) onApply;
  final void Function() onClear;

  const FastestDNSPage(
      {super.key, required this.onApply, required this.onClear});

  @override
  _FastestDNSPageState createState() => _FastestDNSPageState();
}

class _FastestDNSPageState extends State<FastestDNSPage> {
  final dnsService = DNSService();
  List<DnsModel> dnsOptions = [];
  List<DnsModel> sortedDnsOptions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDNSOptions();
  }

  Future<void> _loadDNSOptions() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final dnsList = prefs.getStringList('dns_options') ?? [];

    dnsOptions = dnsList.map((dnsString) {
      final parts = dnsString.split(',');
      return DnsModel(name: parts[0], primary: parts[1], secondary: parts[2]);
    }).toList();

    if (dnsOptions.isNotEmpty) {
      await _updatePingTimes();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updatePingTimes() async {
    final pingTimes = <DnsModel, int>{};

    for (var dns in dnsOptions) {
      final primaryPing = await dnsService.pingDNS(dns.primary);
      final secondaryPing = await dnsService.pingDNS(dns.secondary);
      final averagePing = ((primaryPing ?? 0) + (secondaryPing ?? 0)) / 2;

      if (!mounted) return;

      dns.primaryPingTime = primaryPing;
      dns.secondaryPingTime = secondaryPing;

      pingTimes[dns] = averagePing.toInt();
    }

    if (mounted) {
      setState(() {
        sortedDnsOptions = pingTimes.keys.toList()
          ..sort((a, b) => pingTimes[a]!.compareTo(pingTimes[b]!));
      });
    }
  }

  Future<void> _applyFastestDNS() async {
    if (sortedDnsOptions.isNotEmpty) {
      final fastestDNS = sortedDnsOptions.first;
      widget.onApply(fastestDNS);
      await dnsService.setDNS(fastestDNS.primary, fastestDNS.secondary);

      _showConfirmationDialog('DNS set to ${fastestDNS.name}');
    } else {
      _showConfirmationDialog('No DNS options available to apply.');
    }
  }

  void _applyDNS(DnsModel dns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply DNS'),
        content: Text('Do you want to apply DNS: ${dns.name}?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              widget.onApply(dns);
              await dnsService.setDNS(dns.primary, dns.secondary);
              _showConfirmationDialog('DNS set to ${dns.name}');
            },
            child: const Text('Yes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
        ],
      ),
    );
  }

  void _clearDNS() {
    widget.onClear();
    _showConfirmationDialog('DNS has been cleared.');
  }

  void _showConfirmationDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('DNS Update',
            style: Theme.of(context).textTheme.headlineSmall),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('DNS Ping Results', style: theme.textTheme.bodySmall),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.iconTheme.color),
            onPressed: _loadDNSOptions,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedDnsOptions.isEmpty
              ? Center(
                  child: Text('No DNS options available',
                      style: theme.textTheme.bodyMedium))
              : ListView.builder(
                  itemCount: sortedDnsOptions.length,
                  itemBuilder: (context, index) {
                    final dns = sortedDnsOptions[index];
                    return GestureDetector(
                      onTap: () => _applyDNS(dns),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light
                              ? theme.inputDecorationTheme.fillColor
                              : Colors.grey[850],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dns.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.brightness == Brightness.light
                                    ? theme.textTheme.headlineMedium?.color
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Primary DNS: ${dns.primary}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.brightness == Brightness.light
                                    ? theme.textTheme.bodyMedium?.color
                                    : Colors.white70,
                              ),
                            ),
                            Text(
                              'Secondary DNS: ${dns.secondary}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.brightness == Brightness.light
                                    ? theme.textTheme.bodyMedium?.color
                                    : Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Primary Ping: ${dns.primaryPingTime ?? 'N/A'} ms',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? theme.textTheme.bodyMedium?.color
                                        : Colors.white70,
                                  ),
                                ),
                                Text(
                                  'Secondary Ping: ${dns.secondaryPingTime ?? 'N/A'} ms',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.brightness == Brightness.light
                                        ? theme.textTheme.bodyMedium?.color
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _applyFastestDNS,
              tooltip: 'Apply Fastest DNS',
              backgroundColor: theme.primaryColor,
              child: Icon(Icons.speed,
                  color: theme.floatingActionButtonTheme.foregroundColor),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 48,
            child: FloatingActionButton(
              onPressed: _clearDNS,
              tooltip: 'Clear DNS',
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.clear,
                  color: theme.floatingActionButtonTheme.foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}
