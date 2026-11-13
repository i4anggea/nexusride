import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nexusride/core/services/permission_service.dart';
import 'package:nexusride/core/services/notification_service.dart';
import 'package:nexusride/core/services/ble_background_service.dart';
import 'package:nexusride/features/device/presentation/providers/ble_bridge_provider.dart';
import 'package:nexusride/features/location/presentation/providers/location_provider.dart';
import 'package:nexusride/features/location/presentation/providers/ble_location_provider.dart';
import 'package:nexusride/features/location/presentation/providers/route_provider.dart';
import 'package:nexusride/shared/widgets/sync_status_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _fallbackPosition = LatLng(19.4326, -99.1332);

  GoogleMapController? _mapController;
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareHome());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationPermission();
    }
  }

  Future<void> _prepareHome() async {
    // NotificationService requests notification permission during app startup.
    // Wait for that prompt before requesting location so Android only has one
    // permission activity open at a time.
    await ref.read(notificationServiceProvider).init();
    if (!mounted) return;

    await _requestLocationPermission();

    if (await PermissionService.hasBluetoothPermissions() && mounted) {
      await resumeSavedBleDeviceService();
    }
  }

  Future<void> _requestLocationPermission() async {
    final granted = await PermissionService.requestLocation(context);
    if (!mounted) return;
    setState(() => _locationPermissionGranted = granted);
    if (granted) ref.invalidate(locationStreamProvider);
  }

  Future<void> _refreshLocationPermission() async {
    final granted = await PermissionService.hasLocationPermission();
    if (!mounted || granted == _locationPermissionGranted) return;
    setState(() => _locationPermissionGranted = granted);
    if (granted) ref.invalidate(locationStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationStreamProvider);
    final bleLocation = ref.watch(bleLocationProvider);
    final route = ref.watch(routeProvider);
    final bleStatus = ref.watch(bleStatusProvider);

    ref.listen(bleLocationProvider, (_, loc) {
      if (loc != null) {
        ref.read(routeProvider.notifier).onLocationUpdate(loc);
      }
    });
    ref.listen(locationStreamProvider, (_, next) {
      final location = next.valueOrNull;
      if (location == null) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(location.latitude, location.longitude)),
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: locationAsync.valueOrNull == null
                  ? _fallbackPosition
                  : LatLng(
                      locationAsync.valueOrNull!.latitude,
                      locationAsync.valueOrNull!.longitude,
                    ),
              zoom: locationAsync.valueOrNull == null ? 4 : 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              final location = ref.read(locationStreamProvider).valueOrNull;
              if (location != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(location.latitude, location.longitude),
                  ),
                );
              }
            },
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: _locationPermissionGranted,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              if (locationAsync.valueOrNull case final location?)
                Marker(
                  markerId: const MarkerId('current-location'),
                  position: LatLng(location.latitude, location.longitude),
                  infoWindow: const InfoWindow(title: 'Tu ubicación'),
                ),
            },
          ),
          if (!_locationPermissionGranted || locationAsync.hasError)
            Positioned(
              top: 86,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: _LocationHint()),
                      TextButton(
                        onPressed: _locationPermissionGranted
                            ? () => ref.invalidate(locationStreamProvider)
                            : _requestLocationPermission,
                        child: Text(
                          _locationPermissionGranted
                              ? 'Reintentar'
                              : 'Permitir',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (locationAsync.isLoading)
            const Positioned(
              top: 94,
              left: 16,
              child: Chip(label: Text('Buscando ubicación del teléfono…')),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DeviceStatusBadge(status: bleStatus),
                  const SizedBox(height: 8),
                  const SyncStatusBadge(),
                  if (route.isActive) ...[
                    const SizedBox(height: 8),
                    _RouteBadge(duration: route.duration),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 16,
            child: bleLocation != null
                ? _SpeedCard(speed: route.currentSpeed)
                : const SizedBox.shrink(),
          ),
          Positioned(
            bottom: 140,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'share',
                  onPressed: _shareLocation,
                  child: const Icon(Icons.share_outlined),
                ),
                const SizedBox(height: 8),
                const _RouteButton(),
              ],
            ),
          ),
          const Positioned(bottom: 56, left: 0, right: 0, child: _StatsBar()),
        ],
      ),
    );
  }

  void _shareLocation() {
    final loc = ref.read(locationStreamProvider).value;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicacion no disponible aun')),
      );
      return;
    }
    final url = 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';
    SharePlus.instance.share(
      ShareParams(
        text: 'Mi ubicacion en tiempo real: $url',
        subject: 'Ubicacion NexusRide',
      ),
    );
  }
}

class _LocationHint extends ConsumerWidget {
  const _LocationHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationStreamProvider);
    return Text(
      location.hasError
          ? 'No se pudo obtener el GPS del teléfono. El mapa seguirá disponible.'
          : 'El mapa está disponible. Activa la ubicación para centrarlo en tu posición.',
    );
  }
}

class _RouteBadge extends StatelessWidget {
  final int duration;
  const _RouteBadge({required this.duration});

  String _format(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'En ruta - ${_format(duration)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusBadge extends StatelessWidget {
  final BleStatus status;
  const _DeviceStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status == BleStatus.connected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isConnected ? 'Modulo conectado' : 'Sin modulo',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                isConnected ? 'Senal BLE activa' : 'Toca para conectar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.bluetooth,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  final double speed;
  const _SpeedCard({required this.speed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            speed.toStringAsFixed(0),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'km/h',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteButton extends ConsumerWidget {
  const _RouteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);
    final isActive = route.isActive;
    final isPaused = route.status == RouteStatus.paused;

    return FloatingActionButton.extended(
      heroTag: 'route',
      backgroundColor: isActive
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      onPressed: () {
        HapticFeedback.mediumImpact();
        if (isActive) {
          ref.read(routeProvider.notifier).stopRoute();
        } else if (isPaused) {
          ref.read(routeProvider.notifier).resumeRoute();
        } else {
          ref.read(routeProvider.notifier).startRoute();
        }
      },
      icon: Icon(isActive ? Icons.stop_rounded : Icons.play_arrow_rounded),
      label: Text(
        isActive
            ? 'Detener'
            : isPaused
            ? 'Continuar'
            : 'Iniciar ruta',
      ),
    );
  }
}

class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(routeProvider);

    final distance = route.totalDistance >= 1
        ? '${route.totalDistance.toStringAsFixed(2)} km'
        : '${(route.totalDistance * 1000).toStringAsFixed(0)} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _StatItem(label: 'Distancia', value: distance),
          _StatItem(label: 'Tiempo', value: _formatDuration(route.duration)),
          _StatItem(
            label: 'Vel. max',
            value: '${route.maxSpeed.toStringAsFixed(0)} km/h',
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
