import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../tools/street_discovery_tool.dart';

class StreetDiscoveryScreen extends StatefulWidget {
  @override
  _StreetDiscoveryScreenState createState() => _StreetDiscoveryScreenState();
}

class _StreetDiscoveryScreenState extends State<StreetDiscoveryScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _knownNameController = TextEditingController();
  
  StreetDiscoveryResult? _lastResult;
  bool _isLoading = false;
  final List<StreetDiscoveryResult> _allResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Street Discovery Tool'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.location_on),
            onPressed: _useCurrentLocation,
            tooltip: 'Use Current Location',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructions(),
            SizedBox(height: 20),
            _buildInputSection(),
            SizedBox(height: 20),
            _buildTestButton(),
            if (_lastResult != null) ...[
              SizedBox(height: 20),
              _buildResultSection(),
            ],
            if (_allResults.isNotEmpty) ...[
              SizedBox(height: 20),
              _buildAllResultsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 How to Use This Tool',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Enter GPS coordinates of a street in your city\n'
              '2. Optionally enter what you call that street\n'
              '3. Tap "Discover Street Names"\n'
              '4. See what names the geocoding services return\n'
              '5. Use those exact names in your zones.json config',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              '💡 Tip: Walk to different streets in your city and use "Current Location" button',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Coordinates:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g. 40.7128',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g. -74.0060',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _knownNameController,
              decoration: InputDecoration(
                labelText: 'Street Name (Optional)',
                hintText: 'What do you call this street?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _discoverStreet,
      icon: _isLoading 
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(Icons.search),
      label: Text(_isLoading ? 'Discovering...' : 'Discover Street Names'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildResultSection() {
    final result = _lastResult!;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 Results for: ${result.latitude}, ${result.longitude}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 12),
            
            if (result.yourKnownName != null) ...[
              _buildResultRow('🤔 Your Name:', result.yourKnownName!),
            ],
            
            _buildResultRow(
              '📱 Flutter Geocoding:', 
              result.flutterGeocodingName ?? 'Not found'
            ),
            
            _buildResultRow(
              '🌍 Nominatim:', 
              result.nominatimName ?? 'Not found'
            ),
            
            if (result.detailedStreet != null) ...[
              _buildResultRow('📋 Detailed:', result.detailedStreet!),
            ],
            
            SizedBox(height: 12),
            
            // Best recommendation
            final bestName = result.getBestStreetName();
            if (bestName != null) {
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ Use in zones.json:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 4),
                    SelectableText(
                      '"$bestName"',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(bestName),
                      icon: Icon(Icons.copy, size: 16),
                      label: Text('Copy Street Name'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  '❌ No street name detected\n'
                  'You may need to use manual geofencing for this location.',
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResultsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📊 All Discovered Streets (${_allResults.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _generateConfig,
                  icon: Icon(Icons.file_download),
                  label: Text('Generate Config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...(_allResults.map((result) {
              final bestName = result.getBestStreetName();
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '${_allResults.indexOf(result) + 1}. ',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Expanded(
                      child: Text(
                        '${result.yourKnownName ?? "Unknown"} → ${bestName ?? "Not detected"}',
                        style: TextStyle(
                          color: bestName != null ? Colors.black : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  void _useCurrentLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (locationProvider.currentPosition != null) {
      setState(() {
        _latController.text = locationProvider.currentPosition!.latitude.toString();
        _lngController.text = locationProvider.currentPosition!.longitude.toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location not available. Make sure GPS is enabled.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _discoverStreet() async {
    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter latitude and longitude'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter valid coordinates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StreetDiscoveryTool.discoverStreetAt(
        latitude: lat,
        longitude: lng,
        yourKnownStreetName: _knownNameController.text.isNotEmpty 
          ? _knownNameController.text 
          : null,
      );

      setState(() {
        _lastResult = result;
        _allResults.add(result);
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error discovering street: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _generateConfig() {
    final config = StreetDiscoveryTool.generateZonesConfig(_allResults);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generated zones.json Config'),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              config,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: config));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Config copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Copy All'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _knownNameController.dispose();
    super.dispose();
  }
} 