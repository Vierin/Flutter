import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/colors.dart';
import '../services/mapbox_api_service.dart';

/// Модалка выбора адреса: подсказки Mapbox (через бэкенд) + карта (OSM, как Leaflet на вебе).
/// По образцу веб-версии: AddressSelectModal + MapComponentWithCoords.
class AddressPickerModal extends StatefulWidget {
  const AddressPickerModal({
    super.key,
    required this.initialAddress,
    this.initialLat,
    this.initialLon,
    required this.onSelect,
  });

  final String initialAddress;
  final double? initialLat;
  final double? initialLon;
  final void Function(String address, double lat, double lon) onSelect;

  static Future<void> show(
    BuildContext context, {
    required String initialAddress,
    double? initialLat,
    double? initialLon,
    required void Function(String address, double lat, double lon) onSelect,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddressPickerModal(
        initialAddress: initialAddress,
        initialLat: initialLat,
        initialLon: initialLon,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<AddressPickerModal> createState() => _AddressPickerModalState();
}

class _AddressPickerModalState extends State<AddressPickerModal> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _searchFocus = FocusNode();

  List<AddressSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _loadingSuggestions = false;
  bool _reverseGeocodeLoading = false;
  Timer? _debounceTimer;

  double? _lat;
  double? _lon;
  String _address = '';

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    _searchController.text = widget.initialAddress;
    _lat = widget.initialLat;
    _lon = widget.initialLon;
    if (_address.isNotEmpty && _lat != null && _lon != null) {
      // already have coords
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _loadingSuggestions = true);
    final list = await MapboxApiService.getAutocomplete(query, country: 'VN', limit: 5);
    if (!mounted) return;
    setState(() {
      _suggestions = list;
      _showSuggestions = list.isNotEmpty;
      _loadingSuggestions = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _address = value;
      _showSuggestions = false;
    });
    if (value.trim().length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () => _fetchSuggestions(value));
    }
  }

  void _onSelectSuggestion(AddressSuggestion s) {
    _searchController.text = s.address;
    setState(() {
      _address = s.address;
      _lat = s.lat;
      _lon = s.lon;
      _suggestions = [];
      _showSuggestions = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(LatLng(s.lat, s.lon), 16);
    });
  }

  Future<void> _onMapTap(TapPosition position, LatLng latLng) async {
    setState(() {
      _lat = latLng.latitude;
      _lon = latLng.longitude;
      _reverseGeocodeLoading = true;
    });
    final result = await MapboxApiService.reverseGeocode(latLng.latitude, latLng.longitude);
    if (!mounted) return;
    setState(() {
      _reverseGeocodeLoading = false;
      if (result != null) {
        _address = result.address;
        _searchController.text = result.address;
      }
    });
  }

  void _confirm() {
    if (_lat != null && _lon != null && _address.trim().isNotEmpty) {
      widget.onSelect(_address.trim(), _lat!, _lon!);
      Navigator.of(context).pop();
    }
  }

  LatLng get _center {
    if (_lat != null && _lon != null) return LatLng(_lat!, _lon!);
    return const LatLng(21.0285, 105.8542); // Hanoi
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _lat != null && _lon != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        width: screenWidth,
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Выберите адрес',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Search + suggestions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                children: [
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    onTap: () {
                      if (_suggestions.isEmpty && _searchController.text.trim().length >= 2) {
                        _fetchSuggestions(_searchController.text);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск по адресу',
                      prefixIcon: const Icon(Icons.search, size: 22, color: AppColors.textSecondary),
                      suffixIcon: _loadingSuggestions
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderPrimary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                    Positioned(
                      top: 52,
                      left: 0,
                      right: 0,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderPrimary),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                leading: Icon(Icons.location_on_outlined, size: 20, color: AppColors.textSecondary),
                                title: Text(
                                  s.address,
                                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                                onTap: () => _onSelectSuggestion(s),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 400,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundTertiary,
                    border: Border.all(color: AppColors.borderPrimary),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: hasCoords ? 16 : 10,
                          onTap: _onMapTap,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.henzo.mobile',
                          ),
                          if (hasCoords)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_lat!, _lon!),
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary500,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // Zoom controls (like Leaflet on web)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Column(
                          children: [
                            _MapZoomButton(
                              icon: Icons.add,
                              onPressed: () {
                                final zoom = _mapController.camera.zoom + 1;
                                _mapController.move(_mapController.camera.center, zoom.clamp(3.0, 19.0));
                              },
                            ),
                            const SizedBox(height: 4),
                            _MapZoomButton(
                              icon: Icons.remove,
                              onPressed: () {
                                final zoom = _mapController.camera.zoom - 1;
                                _mapController.move(_mapController.camera.center, zoom.clamp(3.0, 19.0));
                              },
                            ),
                          ],
                        ),
                      ),
                      // Hint overlay
                      if (hasCoords)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Нажмите на карту чтобы установить маркер в нужное место.',
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      if (_reverseGeocodeLoading)
                        const Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary500),
                          ),
                        ),
                      if (!hasCoords)
                        const Positioned.fill(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_outlined, size: 48, color: AppColors.textTertiary),
                                SizedBox(height: 8),
                                Text(
                                  'Выберите адрес для просмотра на карте',
                                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.borderPrimary),
                    ),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: (hasCoords && _address.trim().isNotEmpty) ? _confirm : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
                    child: const Text('Выбрать'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapZoomButton extends StatelessWidget {
  const _MapZoomButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundPrimary,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
