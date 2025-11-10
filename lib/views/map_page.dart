import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cc/utils/colors.dart'; // Assuming this path is correct
import '../widgets/navbar.dart'; // Assuming this path is correct
import '../models/models.dart'; // Import the new models file

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
  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  BinLocation? selectedBin;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _generateMarkers();
  }

  void _generateMarkers() {
    Set<Marker> markers = {};

    // Use widget.binLocations to access data from the parent
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
    mapController = controller;
  }

  void _createRoute(BinLocation bin) {
    List<LatLng> routePoints = [
      // Use widget.driverLat/Lng
      LatLng(widget.driverLat, widget.driverLng),
      LatLng(bin.lat, bin.lng),
    ];

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_to_bin'),
          points: routePoints,
          color: AppCol.btnbacks,
          width: 5,
        ),
      };
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(_getBounds(routePoints), 100),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Route created to ${bin.id}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
      extendBody: true, // Make navbar float
      appBar: AppBar(
        automaticallyImplyLeading: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        ),
        backgroundColor: AppCol.btnbacks,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 50, bottom: 10),
                child: Center(
                  child: Image.asset(
                    'assets/cc_logo.png', // Make sure this asset is available
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48), // Spacer
          ],
        ),
      ),
      body: Stack(
        // <-- 1. WAS: Column
        children: [
          // This is the base layer (bottom of the stack)
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(40.7145, -74.0055),
              zoom: 15.5,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,

            // <-- 2. (CRITICAL) Add this padding
            // This moves the map's UI (like My Location button) up
            // so it's not hidden by your floating bin list.
            padding: const EdgeInsets.only(bottom: 150.0),
          ),

          // This is the overlay (top of the stack)
          Align(
            alignment: Alignment.bottomCenter,
            // 1. Wrap the Container with Padding
            child: Padding(
              // 2. Add padding to the bottom. This pushes the list UP
              // from the navbar. Adjust 90.0 to be higher or lower.
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

      // 👇 --- END OF CHANGES --- 👇
      bottomNavigationBar: NavBar(
        currentPage: widget.currentPage,
        onNavigate: widget.onNavigate,
      ),
    );
  }
}
