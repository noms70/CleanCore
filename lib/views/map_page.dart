import 'dart:convert';
import 'package:cc/widgets/appbar.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cc/utils/colors.dart';
import '../widgets/navbar.dart';
import '../models/models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  final String currentPage;
  final Function(String) onNavigate;
  final List<BinLocation> binLocations;
  final double driverLat;
  final double driverLng;

  const MapPage({
    super.key,
    required this.currentPage,
    required this.onNavigate,
    required this.binLocations,
    required this.driverLat,
    required this.driverLng,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // --- STATE VARIABLES ---
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  BinLocation? selectedBin;
  Set<Polyline> _polylines = {};

  CameraPosition? _initialPosition;
  bool _isLoading = true;
  Position? _currentPosition;

  late PolylinePoints _polylinePoints;

  @override
  void initState() {
    super.initState();
    _polylinePoints = PolylinePoints(
      apiKey: "AIzaSyBzGVNtpx96mevl5hXFpx7n-ZeAeM3u1k8",
    ); // No API key needed
    _setupMap();
  }

  void _setupMap() async {
    try {
      _currentPosition = await _determinePosition();
      _initialPosition = CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14.5,
      );
    } catch (e) {
      print("Error getting location: $e");
      // Fallback to the driver location passed from HomePage if permission denied
      _initialPosition = CameraPosition(
        target: LatLng(widget.driverLat, widget.driverLng),
        zoom: 11.5,
      );
    }

    _generateBinMarkers();

    setState(() {
      _isLoading = false;
    });
  }

  // --- NEW FUNCTION: Manually re-center on user location ---
  void _recenterMap() async {
    try {
      Position position = await _determinePosition();
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
    }
  }

  void _generateBinMarkers() {
    Set<Marker> markers = {};
    for (var bin in widget.binLocations) {
      Color markerColor;
      if (bin.isCritical) {
        markerColor = Colors.red;
      } else if (bin.fullness > 70) {
        markerColor = Colors.yellow;
      } else {
        markerColor = Colors.green;
      }

      markers.add(
        Marker(
          markerId: MarkerId(bin.id),
          position: LatLng(bin.lat, bin.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            markerColor == Colors.red
                ? BitmapDescriptor.hueRed
                : markerColor == Colors.yellow
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: bin.id,
            snippet: '${bin.fullness}% Full - ${bin.area}',
          ),
          onTap: () {
            _showBinDetails(bin);
          },
        ),
      );
    }
    setState(() {
      _markers = markers;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // ✅ NEW: Alternative _createRoute function using OSRM
  void _createRoute(BinLocation bin) async {
    LatLng origin;
    if (_currentPosition != null) {
      origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      origin = LatLng(widget.driverLat, widget.driverLng);
    }

    LatLng destination = LatLng(bin.lat, bin.lng);

    // OSRM API URL
    // Format: http://router.project-osrm.org/route/v1/driving/{lng1},{lat1};{lng2},{lat2}?overview=full&geometries=polyline
    String url =
        'http://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline';

    List<LatLng> polylineCoordinates = [];

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String encodedPolyline = data['routes'][0]['geometry'];

        // Use the flutter_polyline_points package just to decode the string
        List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(
          encodedPolyline,
        );
        polylineCoordinates = decodedPoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      } else {
        print("Error with OSRM API: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching route from OSRM: $e");
    }

    // Fallback to straight line if API call fails
    if (polylineCoordinates.isEmpty) {
      polylineCoordinates = [origin, destination];
    }

    setState(() {
      _polylines.clear();
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_to_bin'),
          points: polylineCoordinates,
          color: AppCol.btnbacks,
          width: 5,
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_getBounds([origin, destination]), 100),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Route created to ${bin.id}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showBinDetails(BinLocation bin) {
    setState(() {
      selectedBin = bin;
    });
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBinDetailsSheet(bin),
    );
  }

  Widget _buildBinDetailsSheet(BinLocation bin) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Bin Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btntext,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow('ID', bin.id),
          const SizedBox(height: 12),
          _buildDetailRow('Area', bin.area),
          const SizedBox(height: 12),
          _buildDetailRow('Status', bin.status),
          const SizedBox(height: 12),
          _buildDetailRow('Fullness', '${bin.fullness}%'),
          const SizedBox(height: 12),
          _buildDetailRow('Capacity', '${bin.capacity}L'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: bin.fullness / 100,
              minHeight: 8,
              backgroundColor: AppCol.btnbacks.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                bin.isCritical ? Colors.red : AppCol.btnbacks,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createRoute(bin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppCol.btnbacks,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Create Route to Bin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppCol.btnbacke,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppCol.textGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppCol.btntext,
          ),
        ),
      ],
    );
  }

  Widget _buildBinTile(BinLocation bin) {
    bool isSelected = selectedBin?.id == bin.id;
    Color tileColor = bin.isCritical ? Colors.red : Colors.green;

    return GestureDetector(
      onTap: () => _showBinDetails(bin),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppCol.btnbacks : tileColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tileColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: tileColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              bin.id,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppCol.btntext,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${bin.fullness}%',
              style: TextStyle(
                fontSize: 11,
                color: tileColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppCol.btnbacks),
      )
          : _initialPosition == null
          ? const Center(
        child: Text("Error: Could not load map. Location disabled?"),
      )
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: _initialPosition!,
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 10.0),
          ),
          Positioned(
            right: 16,
            bottom: 250, // Position above the bin list
            child: FloatingActionButton(
              heroTag: 'recenter_btn',
              onPressed: _recenterMap,
              backgroundColor: Colors.white,
              mini: true,
              // Smaller button
              child: const Icon(Icons.my_location, color: AppCol.btntext),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: widget.binLocations.length,
                  itemBuilder: (context, index) {
                    final bin = widget.binLocations[index];
                    return _buildBinTile(bin);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentPage: widget.currentPage,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition();
  }
}
