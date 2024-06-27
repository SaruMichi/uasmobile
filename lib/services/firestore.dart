import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> addNoteWithImageLocationAndPlace(
    String note,
    File? image,
    Position position,
    String placeName,
  ) async {
    try {
      String? imageUrl;

      // Upload image if available
      if (image != null) {
        imageUrl = await _uploadImage(image);
      }

      // Save note with image, location, and place name
      await _db.collection('notes').add({
        'note': note,
        'imageUrl': imageUrl,
        'location': GeoPoint(position.latitude, position.longitude),
        'placeName': placeName,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding note: $e');
      throw e;
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference reference = _storage.ref().child('images/$fileName.jpg');
      UploadTask uploadTask = reference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  Future<void> updateNoteWithImageLocationAndPlace(
    String docId,
    String note,
    File? image,
    Position position,
    String placeName,
  ) async {
    try {
      String? imageUrl;

      // Upload image if available
      if (image != null) {
        imageUrl = await _uploadImage(image);
      }

      // Update note with image, location, and place name
      await _db.collection('notes').doc(docId).update({
        'note': note,
        'imageUrl': imageUrl,
        'location': GeoPoint(position.latitude, position.longitude),
        'placeName': placeName,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating note: $e');
      throw e;
    }
  }

  Future<void> deleteNote(String docId) async {
    try {
      await _db.collection('notes').doc(docId).delete();
    } catch (e) {
      print('Error deleting note: $e');
      throw e;
    }
  }

  Stream<QuerySnapshot> getNotesStream() {
    return _db
        .collection('notes')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
