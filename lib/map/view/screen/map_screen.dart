import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  LocationData? currentLocation;
  List<Marker> markers = [];
  List<LatLng> routePoints = [];
  final String orsApiKey = 'enter your api key';
  final LatLng destination = LatLng(30.7865, 31.0004); // محطة قطار طنطا

  Future<void> getCurrentLocation() async {
    var location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    try {
      var userLocation = await location.getLocation();
      setState(() {
        currentLocation = userLocation;
        markers.add(
          Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(userLocation.latitude!, userLocation.longitude!),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
          ),
        );
        final lat = currentLocation!.latitude!;
        final lng = currentLocation!.longitude!;
        print("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
      });

      getRoute(destination);
    } catch (e) {
      print("❌ Error getting location: $e");
      currentLocation = null;
    }

    location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        currentLocation = newLocation;
      });
    });
  }

  Future<void> getRoute(LatLng destination) async {
    if (currentLocation == null) return;

    final startPoint = LatLng(
      currentLocation!.latitude!,
      currentLocation!.longitude!,
    );

    final distance = haversineDistance(startPoint, destination);
    print('📏 Distance: $distance meters');

    if (distance > 6000000.0) {
      print('❌ Distance exceeds API limit');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The Distance Is Too Long'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final response = await http.get(
      Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${startPoint.longitude},${startPoint.latitude}&end=${destination.longitude},${destination.latitude}',
      ),
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> coords =
          data['features'][0]['geometry']['coordinates'];

      setState(() {
        routePoints =
            coords.map((coord) => LatLng(coord[1], coord[0])).toList();
        markers.add(
          Marker(
            width: 80.0,
            height: 80.0,
            point: destination,
            child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
          ),
        );
      });
    } else {
      print('❌ Failed to fetch route');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فشل في جلب المسار من الخريطة، حاول مرة تانية لاحقًا',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void addDestinationMarker(LatLng point) {
    setState(() {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: point,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40.0),
        ),
      );
    });
    getRoute(point);
  }

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Distination", style: TextStyle(fontSize: 24)),
        backgroundColor: Colors.grey[400],
      ),
      body:
          currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        currentLocation!.latitude!,
                        currentLocation!.longitude!,
                      ),
                      initialZoom: 15.0,
                      onTap:
                          (tapPosition, point) => addDestinationMarker(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(markers: markers),
                      if (routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 4.0,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                    ],
                  ),

                  // زرين الزوم
                  Positioned(
                    top: 20,
                    right: 10,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          heroTag: "zoomIn",
                          mini: true,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            );
                          },
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: "zoomOut",
                          mini: true,
                          onPressed: () {
                            mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom - 1,
                            );
                          },
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (currentLocation != null) {
            mapController.move(
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
              15.0,
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  double haversineDistance(LatLng point1, LatLng point2) {
    const R = 6371000; // نصف قطر الأرض بالمتر
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
