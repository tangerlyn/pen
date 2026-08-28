import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage({
    required File file,
    required String folder,
    int quality = 80,
    int maxWidth = 1080,
  }) async {
    // Note: image compression (quality, maxWidth) would typically be done before upload using flutter_image_compress.
    // For this service, we just upload the provided file.
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref().child('$folder/$fileName');
    
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await uploadTask.ref.getDownloadURL();
    return url;
  }

  Future<List<String>> uploadImages({
    required List<File> files,
    required String folder,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file: file, folder: folder);
      urls.add(url);
    }
    return urls;
  }

  Future<String> uploadProfileImage(File file, String uid) =>
      uploadImage(file: file, folder: 'profiles/$uid', quality: 90, maxWidth: 400);

  Future<List<String>> uploadReviewImages(List<File> files, String reviewId) =>
      uploadImages(files: files, folder: 'reviews/$reviewId');

  Future<List<String>> uploadListingImages(List<File> files, String listingId) =>
      uploadImages(files: files, folder: 'listings/$listingId');

  Future<String> uploadInkChartPhoto(File file, String uid) =>
      uploadImage(file: file, folder: 'inkChart/$uid', quality: 85, maxWidth: 1080);

  Future<String> uploadPenPhoto(File file, String uid) =>
      uploadImage(file: file, folder: 'pens/$uid', quality: 85, maxWidth: 1080);

  Future<String?> uploadPostImage(String filePath) async {
    try {
      return await uploadImage(file: File(filePath), folder: 'posts');
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // url이 유효하지 않거나 파일이 없는 경우 무시
    }
  }

  Future<void> deleteFolder(String folderPath) async {
    try {
      final result = await _storage.ref().child(folderPath).listAll();
      for (final item in result.items) {
        await item.delete();
      }
    } catch (_) {}
  }
}
