import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uasmobile_app/services/firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService firestoreService = FirestoreService();
  File? _selectedImage;
  Position? _currentPosition;
  String? _currentPlace;
  bool _isLoading = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _captureImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get the place name using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _currentPlace = place.name ??
              place.street ??
              place.subLocality ??
              'Unknown place';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error getting location: $e');
    }
  }

  void openNoteBox({String? docId, String? noteText}) {
    TextEditingController textController =
        TextEditingController(text: noteText ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: textController),
            const SizedBox(height: 10),
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 100)
                : const SizedBox.shrink(),
            ElevatedButton(
              onPressed: _captureImage,
              child: const Text('Capture Image'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _getLocation();
              if (_currentPosition != null && _currentPlace != null) {
                if (docId == null) {
                  await firestoreService.addNoteWithImageLocationAndPlace(
                    textController.text,
                    _selectedImage,
                    _currentPosition!,
                    _currentPlace!,
                  );
                } else {
                  await firestoreService.updateNoteWithImageLocationAndPlace(
                    docId,
                    textController.text,
                    _selectedImage,
                    _currentPosition!,
                    _currentPlace!,
                  );
                }
                textController.clear();
                setState(() {
                  _selectedImage = null;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Travel Logs")),
      floatingActionButton: FloatingActionButton(
        onPressed: openNoteBox,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getNotesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  List<QueryDocumentSnapshot> notesList = snapshot.data!.docs;
                  List<String> imageUrls = notesList
                      .map((document) => (document.data()
                          as Map<String, dynamic>)['imageUrl'] as String?)
                      .where((url) => url != null)
                      .cast<String>()
                      .toList();

                  return Column(
                    children: [
                      // Bagian atas: Slider foto
                      if (imageUrls.isNotEmpty)
                        Column(
                          children: [
                            SizedBox(
                              height: 200, // Tinggi slider
                              child: PageView.builder(
                                itemCount: imageUrls.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                imageUrls.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentPage == index
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16.0), // Jarak antara dua bagian
                      // Garis pemisah di sekitar setiap item
                      Expanded(
                        child: ListView.builder(
                          itemCount: notesList.length,
                          itemBuilder: (context, index) {
                            QueryDocumentSnapshot document = notesList[index];
                            String docID = document.id;
                            Map<String, dynamic> data =
                                document.data() as Map<String, dynamic>;
                            String noteText = data['note'];
                            String? imageUrl = data['imageUrl'];
                            GeoPoint? location = data['location'];
                            String? placeName = data['placeName'];

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: imageUrl != null
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          imageUrl,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : null,
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      noteText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                    if (location != null)
                                      Text(
                                        'Coordinates: ${location.latitude}, ${location.longitude}',
                                      ),
                                    if (placeName != null)
                                      Text('Place: $placeName'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => openNoteBox(
                                          docId: docID, noteText: noteText),
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Edit Note',
                                    ),
                                    IconButton(
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Deletion'),
                                          content: const Text(
                                              'Are you sure you want to delete this note?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  context), // Cancel button
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                firestoreService.deleteNote(
                                                    docID); // Delete button
                                                Navigator.pop(
                                                    context); // Close dialog
                                              },
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Delete Note',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}
