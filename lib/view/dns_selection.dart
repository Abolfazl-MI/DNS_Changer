// lib/view/dns_selection.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dns_changer/component/bottom_sheet.dart';
import 'package:dns_changer/component/dns_details.dart';
import 'package:dns_changer/component/dropdown_dns.dart';
import 'package:dns_changer/model/dns_model.dart';
import 'package:dns_changer/service/dns_provider.dart';
import 'package:dns_changer/service/dns_service.dart';

class DnsSelection extends StatefulWidget {
  final void Function(DnsModel?) onSelect;
  final void Function(DnsModel) onRemove;
  final void Function() onDNSChange;

  const DnsSelection({
    super.key,
    required this.onSelect,
    required this.onRemove,
    required this.onDNSChange,
  });

  @override
  _DnsSelectionState createState() => _DnsSelectionState();
}

class _DnsSelectionState extends State<DnsSelection> {
  DnsModel? selectedDNS;
  int? primaryPingTime;
  int? secondaryPingTime;
  bool _isLoadingPing = false;

  final dnsService = DNSService();

  final TextEditingController primaryController = TextEditingController();
  final TextEditingController secondaryController = TextEditingController();
  List<DnsModel> dnsOptions = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _savePreferences();
    primaryController.dispose();
    secondaryController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final dnsList = prefs.getStringList('dns_options') ?? [];
    final selectedDnsName = prefs.getString('selected_dns');

    dnsOptions = dnsList.map((dnsString) {
      final parts = dnsString.split(',');
      return DnsModel(name: parts[0], primary: parts[1], secondary: parts[2]);
    }).toList();

    selectedDNS = dnsOptions.firstWhere(
      (dns) => dns.name == selectedDnsName,
      orElse: () => dnsOptions.isNotEmpty
          ? dnsOptions[0]
          : DnsModel(name: '', primary: '0.0.0.0', secondary: '0.0.0.0'),
    );

    if (selectedDNS != null) {
      primaryController.text = selectedDNS!.primary;
      secondaryController.text = selectedDNS!.secondary;
      await _updatePingTime(selectedDNS!.primary, selectedDNS!.secondary);
    } else {
      primaryController.clear();
      secondaryController.clear();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'dns_options',
        dnsOptions
            .map((dns) => '${dns.name},${dns.primary},${dns.secondary}')
            .toList());
    await prefs.setString('selected_dns', selectedDNS?.name ?? '');
  }

  Future<void> _updatePingTime(String primaryDNS, String secondaryDNS) async {
    setState(() {
      _isLoadingPing = true;
    });

    final primaryPing = await dnsService.pingDNS(primaryDNS);
    final secondaryPing = await dnsService.pingDNS(secondaryDNS);

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        primaryPingTime = primaryPing;
        secondaryPingTime = secondaryPing;
        _isLoadingPing = false;
      });
    }
  }

  Future<void> _pingSelectedDNS() async {
    if (selectedDNS != null) {
      setState(() {
        _isLoadingPing = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      await _updatePingTime(selectedDNS!.primary, selectedDNS!.secondary);

      if (mounted) {
        setState(() {
          _isLoadingPing = false;
        });
      }
    }
  }

  void _showAddDNSSheet(BuildContext context, {DnsModel? dnsToEdit}) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return DNSBottomSheet(
          dnsToEdit: dnsToEdit,
          onSave: (DnsModel newDns) {
            setState(() {
              if (dnsToEdit != null) {
                final index = dnsOptions.indexOf(dnsToEdit);
                if (index != -1) {
                  dnsOptions[index] = newDns;
                }
              } else {
                dnsOptions.add(newDns);
              }

              selectedDNS = newDns;
              primaryController.text = newDns.primary;
              secondaryController.text = newDns.secondary;
              _pingSelectedDNS();

              _savePreferences();

              Provider.of<DNSProvider>(context, listen: false).setDNS(newDns);
            });
          },
        );
      },
    );
  }

  Future<void> _removeDNSFromPreferences(DnsModel dns) async {
    final prefs = await SharedPreferences.getInstance();
    final dnsList = prefs.getStringList('dns_options') ?? [];
    dnsList.removeWhere((dnsString) {
      final parts = dnsString.split(',');
      return parts[0] == dns.name &&
          parts[1] == dns.primary &&
          parts[2] == dns.secondary;
    });
    await prefs.setStringList('dns_options', dnsList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDNSSheet(context),
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Select DNS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DNSDropdownButton(
              dnsOptions: dnsOptions,
              selectedDNS: selectedDNS,
              onChanged: (DnsModel? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedDNS = newValue;
                    primaryController.text = newValue.primary;
                    secondaryController.text = newValue.secondary;
                  });
                  _savePreferences();
                  widget.onSelect(newValue);
                  _pingSelectedDNS();
                }
              },
              onEdit: (DnsModel dns) =>
                  _showAddDNSSheet(context, dnsToEdit: dns),
              onDelete: (DnsModel dns) {
                setState(() {
                  dnsOptions.remove(dns);
                  if (selectedDNS == dns) {
                    selectedDNS = dnsOptions.isNotEmpty ? dnsOptions[0] : null;
                    if (selectedDNS != null) {
                      primaryController.text = selectedDNS!.primary;
                      secondaryController.text = selectedDNS!.secondary;
                      _updatePingTime(
                          selectedDNS!.primary, selectedDNS!.secondary);
                    } else {
                      primaryController.clear();
                      secondaryController.clear();
                      widget.onSelect(null);
                    }
                  }
                });
                _removeDNSFromPreferences(dns);
                _savePreferences();
                widget.onRemove(dns);

                Provider.of<DNSProvider>(context, listen: false).clearDNS();
              },
            ),
            const SizedBox(height: 20),
            if (selectedDNS != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DNSDetailRow(
                    label: 'Primary DNS:',
                    pingTime: primaryPingTime,
                    isLoading: _isLoadingPing,
                    controller: primaryController,
                    copyLabel: 'Primary DNS',
                  ),
                  const SizedBox(height: 20),
                  DNSDetailRow(
                    label: 'Secondary DNS:',
                    pingTime: secondaryPingTime,
                    isLoading: _isLoadingPing,
                    controller: secondaryController,
                    copyLabel: 'Secondary DNS',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _pingSelectedDNS,
                        child: const Text('Ping'),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
