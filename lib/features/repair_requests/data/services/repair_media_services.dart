import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

abstract interface class RepairMediaPicker {
  Future<List<RepairEvidence>> pickPhotos();
  Future<RepairEvidence?> pickVideo();
  Future<RepairEvidence?> pickDocument(RepairEvidenceKind kind);
  Future<void> deleteLocal(String localPath);
}

class DeviceRepairMediaPicker implements RepairMediaPicker {
  DeviceRepairMediaPicker({ImagePicker? imagePicker, Uuid? uuid})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _uuid = uuid ?? const Uuid();

  final ImagePicker _imagePicker;
  final Uuid _uuid;

  @override
  Future<void> deleteLocal(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<List<RepairEvidence>> pickPhotos() async {
    final files = await _imagePicker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    final result = <RepairEvidence>[];
    for (final file in files) {
      result.add(
        await _persistXFile(file, RepairEvidenceKind.image, result.length),
      );
    }
    return result;
  }

  @override
  Future<RepairEvidence?> pickVideo() async {
    final file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) {
      return null;
    }
    return _persistXFile(file, RepairEvidenceKind.video, 0);
  }

  @override
  Future<RepairEvidence?> pickDocument(RepairEvidenceKind kind) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select ${kind.label.toLowerCase()}',
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'txt', 'jpg', 'jpeg', 'png'],
    );
    final platformFile = picked?.files.singleOrNull;
    if (platformFile?.path == null) {
      return null;
    }
    final source = File(platformFile!.path!);
    final target = await _copyIntoDraftStorage(source, platformFile.name);
    final mimeType = lookupMimeType(target.path) ?? 'application/octet-stream';
    return RepairEvidence(
      id: _uuid.v4(),
      kind: mimeType.startsWith('image/') && kind == RepairEvidenceKind.document
          ? RepairEvidenceKind.image
          : kind,
      localPath: target.path,
      filename: platformFile.name,
      mimeType: mimeType,
      byteSize: await target.length(),
      sortOrder: 0,
    );
  }

  Future<RepairEvidence> _persistXFile(
    XFile picked,
    RepairEvidenceKind kind,
    int sortOrder,
  ) async {
    final target = await _copyIntoDraftStorage(File(picked.path), picked.name);
    return RepairEvidence(
      id: _uuid.v4(),
      kind: kind,
      localPath: target.path,
      filename: picked.name,
      mimeType:
          picked.mimeType ??
          lookupMimeType(target.path) ??
          (kind == RepairEvidenceKind.video ? 'video/mp4' : 'image/jpeg'),
      byteSize: await target.length(),
      sortOrder: sortOrder,
    );
  }

  Future<File> _copyIntoDraftStorage(File source, String originalName) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'repair_evidence'));
    await directory.create(recursive: true);
    final extension = path.extension(originalName).toLowerCase();
    final target = File(path.join(directory.path, '${_uuid.v4()}$extension'));
    return source.copy(target.path);
  }
}

abstract interface class RepairSpeechService {
  bool get isListening;
  Future<bool> start(ValueChanged<String> onWords);
  Future<void> stop();
}

typedef ValueChanged<T> = void Function(T value);

class DeviceRepairSpeechService implements RepairSpeechService {
  DeviceRepairSpeechService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> start(ValueChanged<String> onWords) async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
    if (!_initialized) {
      return false;
    }
    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}

abstract interface class RepairAudioRecorder {
  bool get isRecording;
  Future<bool> start();
  Future<RepairEvidence?> stop();
  Future<void> dispose();
}

class DeviceRepairAudioRecorder implements RepairAudioRecorder {
  DeviceRepairAudioRecorder({AudioRecorder? recorder, Uuid? uuid})
    : _recorder = recorder ?? AudioRecorder(),
      _uuid = uuid ?? const Uuid();

  final AudioRecorder _recorder;
  final Uuid _uuid;
  String? _activePath;

  @override
  bool get isRecording => _activePath != null;

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) {
      return false;
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'repair_evidence'));
    await directory.create(recursive: true);
    _activePath = path.join(directory.path, '${_uuid.v4()}.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _activePath!,
    );
    return true;
  }

  @override
  Future<RepairEvidence?> stop() async {
    final recordedPath = await _recorder.stop() ?? _activePath;
    _activePath = null;
    if (recordedPath == null) {
      return null;
    }
    final file = File(recordedPath);
    if (!await file.exists()) {
      return null;
    }
    return RepairEvidence(
      id: _uuid.v4(),
      kind: RepairEvidenceKind.audio,
      localPath: recordedPath,
      filename: path.basename(recordedPath),
      mimeType: 'audio/mp4',
      byteSize: await file.length(),
      sortOrder: 0,
    );
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
