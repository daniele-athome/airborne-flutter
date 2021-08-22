import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final Logger _log = Logger((AircraftData).toString());

class AircraftData {
  final Directory? dataPath;
  final String id;
  final String callSign;
  final Map<String, dynamic> backendInfo;
  final List<String> pilotNames;
  final double locationLatitude;
  final double locationLongitude;
  final String locationTimeZone;
  final bool admin;

  AircraftData({
    required this.dataPath,
    required this.id,
    required this.callSign,
    required this.backendInfo,
    required this.pilotNames,
    required this.locationLatitude,
    required this.locationLongitude,
    required this.locationTimeZone,
    this.admin = false,
  });

  File getPilotAvatar(String name) {
    return File(path.join(dataPath!.path, 'avatar-${name.toLowerCase()}.jpg'));
  }

}

class AircraftDataReader {
  final File dataFile;

  Map<String, dynamic>? metadata;

  AircraftDataReader({
    required this.dataFile,
  });

  /// Also loads metadata.
  Future<bool> validate() async {
    // FIXME in-memory operations - fine for small files, but it needs to change
    final bytes = await dataFile.readAsBytes();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    }
    catch (e) {
      _log.warning('Not a valid zip file: $e');
      return false;
    }

    final mainFile = archive.findFile("aircraft.json");
    if (mainFile == null || !mainFile.isFile) {
      _log.warning('aircraft.json not found in archive!');
      return false;
    }

    final jsonData = mainFile.content as List<int>;
    final Map<String, dynamic> metadata;
    try {
      metadata = json.decode(String.fromCharCodes(jsonData)) as Map<String, dynamic>;
    }
    catch(e) {
      _log.warning('aircraft.json is not valid JSON: $e');
      return false;
    }

    _log.finest(metadata);
    // TODO JSON Schema validation
    if (metadata['aircraft_id'] != null && metadata['callsign'] != null &&
        metadata['backend_info'] != null && metadata['pilot_names'] != null) {

      // TODO check for aircraft picture
      // TODO check for pilot avatars

      this.metadata = metadata;
      return true;
    }

    return false;
  }

  /// Opens an aircraft data file and extract contents in a temporary directory.
  Future<Directory> open() async {
    if (metadata != null && metadata!['path'] != null) {
      return metadata!['path'] as Directory;
    }

    final baseDir = await getTemporaryDirectory();
    final directory = Directory(path.join(baseDir.path, 'aircrafts', path.basenameWithoutExtension(dataFile.path)));
    final exists = await directory.exists();
    if (!exists) {
      await directory.create(recursive: true);

      // FIXME in-memory operations - fine for small files, but it needs to change
      final bytes = await dataFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);

      for (final file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final f = File(path.join(directory.path, file.name));
        await f.writeAsBytes(file.content as List<int>);
      }
    }

    try {
      final jsonFile = File(path.join(directory.path, 'aircraft.json'));
      final jsonData = await jsonFile.readAsString();
      metadata = json.decode(jsonData) as Map<String, dynamic>;
    }
    catch(e) {
      _log.warning('aircraft.json is not valid JSON: $e');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // aircraft picture
    final aircraftPicFile = File(path.join(directory.path, 'aircraft.jpg'));
    if (!(await aircraftPicFile.exists())) {
      _log.warning('aircraft.jpg is missing');
      throw const FormatException('Not a valid aircraft archive.');
    }

    // pilot avatars
    for (final pilot in List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>)) {
      if (!(await File(path.join(directory.path, 'avatar-${pilot.toLowerCase()}.jpg')).exists())) {
        _log.warning('pilot avatar for $pilot is missing');
        throw const FormatException('Not a valid aircraft archive.');
      }
    }

    // store path for later use
    metadata!['path'] = directory;
    return directory;
  }

  AircraftData toAircraftData() {
    return AircraftData(
      dataPath: metadata!['path'] as Directory,
      id: metadata!['aircraft_id'] as String,
      callSign: metadata!['callsign'] as String,
      backendInfo: metadata!['backend_info'] as Map<String, dynamic>,
      pilotNames: List<String>.from(metadata!['pilot_names'] as Iterable<dynamic>),
      locationLatitude: metadata!['location']?['latitude'] as double,
      locationLongitude: metadata!['location']?['longitude'] as double,
      locationTimeZone: metadata!['location']?['timezone'] as String,
      admin: metadata!['admin'] != null && metadata!['admin'] as bool,
    );
  }

}

/// Add an aircraft data file to a local data store for long-term storage.
Future<File> addAircraftDataFile(AircraftDataReader reader) async {
  final baseDir = await getApplicationSupportDirectory();
  final directory = Directory(path.join(baseDir.path, 'aircrafts'));
  await directory.create(recursive: true);
  final filename = path.join(directory.path, '${reader.metadata!['aircraft_id'] as String}.zip');
  await deleteAircraftCache(reader.metadata!['aircraft_id'] as String);
  return reader.dataFile.copy(filename);
}

/// Loads an aircraft data file into the cache.
Future<AircraftDataReader> loadAircraft(String aircraftId) async {
  final baseDir = await getApplicationSupportDirectory();
  final dataFile = File(path.join(baseDir.path, 'aircrafts', '$aircraftId.zip'));
  final reader = AircraftDataReader(dataFile: dataFile);
  await reader.open();
  return reader;
}

Future<Directory> deleteAircraftCache(String aircraftId) async {
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'aircrafts', aircraftId));
  final exists = await tmpDirectory.exists();
  return exists ? tmpDirectory.delete(recursive: true) as Future<Directory> : Future.value(tmpDirectory);
}

Future<Directory> deleteAllAircrafts() async {
  // delete cache
  final cacheDir = await getTemporaryDirectory();
  final tmpDirectory = Directory(path.join(cacheDir.path, 'aircrafts'));
  if (await tmpDirectory.exists()) {
    await tmpDirectory.delete(recursive: true);
  }
  // delete files
  final baseDir = await getApplicationSupportDirectory();
  final directory = Directory(path.join(baseDir.path, 'aircrafts'));
  final exists = await directory.exists();
  return exists ? directory.delete(recursive: true) as Future<Directory> : Future.value(directory);
}