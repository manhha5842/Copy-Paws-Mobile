// ignore_for_file: unused_import, unused_field, unused_local_variable, annotate_overrides, must_call_super

// This file is DEPRECATED and not used in the current architecture.
// The app now uses individual services instead:
// - ConnectionManager for connection state
// - SyncService for clipboard sync
// - StorageService for data persistence
// - etc.
//
// This file is kept only for reference and should not be imported or used.

import 'package:flutter/foundation.dart';

import '../core/constants/connection_state.dart' as app;
import '../core/models/clipboard_item.dart';
import '../core/models/hub_info.dart';

/// DEPRECATED: Use individual services instead of this global AppState
class AppState with ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  // This class is no longer used
  final app.ConnectionState _connectionState = app.ConnectionState.disconnected;
  HubInfo? _connectedHub;
  final List<ClipboardItem> _incomingClips = [];

  // Getters (kept for backwards compatibility if needed)
  app.ConnectionState get connectionState => _connectionState;
  HubInfo? get connectedHub => _connectedHub;
  List<ClipboardItem> get incomingClips => List.unmodifiable(_incomingClips);
  bool get isConnected => _connectionState == app.ConnectionState.connected;

  void dispose() {
    // No-op
  }
}
