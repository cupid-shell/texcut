import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';

/// Sync status for the UI.
enum SyncStatus { idle, syncing, success, error, signedOut }

/// Signs the user into Google and syncs the snippet library to a private file
/// in their Drive **appDataFolder** (hidden from the normal Drive UI). The
/// appdata scope keeps texcut's access scoped to its own data only.
class DriveSync extends ChangeNotifier {
  DriveSync(this.appState);

  final AppState appState;

  static const _backupFileName = 'texcut-backup.json';
  static const _autoSyncKey = 'texcut.autoSyncEnabled';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? _account;
  SyncStatus _status = SyncStatus.signedOut;
  String? _message;
  DateTime? _lastSynced;
  bool _autoSync = true;
  Timer? _debounce;

  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;
  SyncStatus get status => _status;
  String? get message => _message;
  DateTime? get lastSynced => _lastSynced;
  bool get autoSync => _autoSync;

  /// Wires up auto-push and attempts a silent sign-in + pull on launch.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool(_autoSyncKey) ?? true;

    // Push to Drive (debounced) whenever local data changes.
    appState.onDataChanged = _onLocalChange;

    try {
      _account = await _googleSignIn.signInSilently();
      if (_account != null) {
        _status = SyncStatus.idle;
        notifyListeners();
        await syncNow();
      }
    } catch (_) {
      // Silent sign-in failing is normal when not signed in yet.
    }
  }

  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, value);
    notifyListeners();
  }

  Future<void> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account != null) {
        notifyListeners();
        await syncNow();
      }
    } catch (e) {
      _fail('Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _account = null;
    _status = SyncStatus.signedOut;
    _message = null;
    notifyListeners();
  }

  /// Pulls remote data and merges it, then pushes the merged result back so
  /// both sides converge.
  Future<void> syncNow() async {
    if (!isSignedIn) return;
    _setStatus(SyncStatus.syncing);
    try {
      final api = await _driveApi();
      if (api == null) {
        _fail('Could not authenticate with Google Drive.');
        return;
      }
      final fileId = await _findBackupId(api);
      if (fileId != null) {
        final remote = await _download(api, fileId);
        if (remote != null && remote.trim().isNotEmpty) {
          await appState.applySyncedData(remote);
        }
      }
      await _upload(api, fileId);
      _lastSynced = DateTime.now();
      _setStatus(SyncStatus.success);
    } catch (e) {
      _fail('Sync failed: $e');
    }
  }

  void _onLocalChange() {
    if (!isSignedIn || !_autoSync) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _pushOnly);
  }

  Future<void> _pushOnly() async {
    if (!isSignedIn) return;
    _setStatus(SyncStatus.syncing);
    try {
      final api = await _driveApi();
      if (api == null) {
        _fail('Could not authenticate with Google Drive.');
        return;
      }
      final fileId = await _findBackupId(api);
      await _upload(api, fileId);
      _lastSynced = DateTime.now();
      _setStatus(SyncStatus.success);
    } catch (e) {
      _fail('Upload failed: $e');
    }
  }

  Future<drive.DriveApi?> _driveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  Future<String?> _findBackupId(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  Future<String?> _download(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<void> _upload(drive.DriveApi api, String? existingId) async {
    final json = appState.exportToJson();
    final bytes = utf8.encode(json);
    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (existingId == null) {
      final file = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      await api.files.create(file, uploadMedia: media);
    } else {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    }
  }

  void _setStatus(SyncStatus s, [String? msg]) {
    _status = s;
    _message = msg;
    notifyListeners();
  }

  void _fail(String msg) {
    if (kDebugMode) debugPrint('[DriveSync] $msg');
    _setStatus(SyncStatus.error, msg);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    appState.onDataChanged = null;
    super.dispose();
  }
}
