import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:provider/provider.dart';



class ItemPage extends StatefulWidget {
  @override
  _ItemPageState createState() => _ItemPageState();
}


class _ItemPageState extends State<ItemPage> {
  late List<String> imageUrls;

  var item;
  ThemeData get theme => Theme.of(context);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  String _selectedSortOption = 'Price Asc';
  List<String> _sortOptions = ['Price Asc', 'Price Desc'];

  @override
  void initState() {
    super.initState();
    getImageUrls();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        createUserDocument(user);
      }
    });
  }

Future<void> createUserDocument(User user) async {
 if (user is User) {
  final userRef = FirebaseFirestore.instance.collection('user').doc(user.uid);
  if (!(await userRef.get()).exists) {
    String uid = user.uid;
    String statusMessage = 'I promise to take the test honestly before GOD.';
    String displayName = user.displayName ?? '';
    String email = user.email ?? '';
    await userRef.set({
      'name': displayName,
      'email': user.email ?? '',
      'uid': uid,
      'status_message': statusMessage,
    });
  }
} else {
  final userRef = FirebaseFirestore.instance.collection('user').doc(user.uid);
  if (!(await userRef.get()).exists) {
    String uid = user.uid;
    String statusMessage = 'I promise to take the test honestly before GOD.';
    await userRef.set({
      'uid': uid,
      'status_message': statusMessage,
    });
  }
}
}


  Future<void> getImageUrls() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('item')
        .get();
    List<QueryDocumentSnapshot> docs = snapshot.docs;
    List<String> urls = [];

    for (QueryDocumentSnapshot doc in docs) {
      String path = 'item/${doc['id']}';
      try {
        String imageUrl = await _storage.ref().child(path).getDownloadURL();
        urls.add(imageUrl);
      } catch (e) {
        print('Error retrieving download URL for $path: $e');
      }
    }

    setState(() {
      imageUrls = urls;
    });
  }

  void _onSortOptionChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedSortOption = value;
      });
    }
  }

  Future<void> _uploadImageAndSaveToDatabase(File imageFile) async {
    try {
      final String fileName = item['name'];
      final firebase_storage.Reference ref =
          _storage.ref().child('images/$fileName');
      final firebase_storage.UploadTask uploadTask = ref.putFile(imageFile);
      final firebase_storage.TaskSnapshot taskSnapshot =
          await uploadTask.whenComplete(() {});

      final String downloadURL = await taskSnapshot.ref.getDownloadURL();

      final String itemName = fileName;

      await _firestore.collection('item').add({
        'itemId': item['itemId'],
        'id': item['id'],
        'creationTime': item['creationTime'],
        'updateTime': item['updateTime'],
        'selectedImage!': downloadURL,
        'name': itemName,
        'price': item['price'],
        'description': item['description'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image uploaded successfully'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to upload image'),
        ),
      );
    }
  }

  Future<void> _pickImageAndUpload() async {
    final XFile? pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedImage != null) {
      final File imageFile = File(pickedImage.path);
      await _uploadImageAndSaveToDatabase(imageFile);
    }
  }

Widget _buildGridCards(
  BuildContext context, List<DocumentSnapshot> documents) {
  return GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 8.0 / 9.0,
    ),
    padding: const EdgeInsets.all(16.0),
    itemCount: documents.length, // 수정된 부분
    itemBuilder: (context, index) {
      final document = documents[index];
      final String name = document['name'] ?? '';
      final int price = int.tryParse(document['price'].toString()) ?? 0;
      final String imageUrl = document['imageUrl'];

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPage(
                itemId: document.id,
                name: name,
                price: price,
                description: document['description'] ?? '',
                id: document['id'] ?? '',
                creationTime: document['creationTime'],
                updateTime: document['updateTime'],
                imageUrl: imageUrl,
              ),
            ),
          );
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 18 / 11,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.fitWidth,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headline6,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        price.toString(),
                        style: Theme.of(context).textTheme.subtitle1,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  List<DocumentSnapshot> _sortDocuments(QuerySnapshot snapshot) {
    final documents = snapshot.docs;

    if (_selectedSortOption == 'Price Asc') {
      documents.sort((a, b) => (a['price'] ?? '').compareTo(b['price'] ?? ''));
    } else if (_selectedSortOption == 'Price Desc') {
      documents.sort((a, b) => (b['price'] ?? '').compareTo(a['price'] ?? ''));
    }

    return documents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.person,
            semanticLabel: 'profile',
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(),
              ),
            );
          },
        ),
        title: const Text('Main'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.shopping_cart,
              semanticLabel: 'cart',
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WishlistPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.add,
              semanticLabel: 'more',
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              value: _selectedSortOption,
              onChanged: _onSortOptionChanged,
              items: _sortOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('item').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final documents = snapshot.data!.docs; // 수정된 부분
                final sortedDocuments = _sortDocuments(snapshot.data!);
                return _buildGridCards(context, sortedDocuments);
              },
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}



class DetailPage extends StatefulWidget {
  final String itemId;
  final String name;
  final int price;
  final String description;
  final String id;
  final Timestamp creationTime;
  late final Timestamp updateTime;
  final String imageUrl;

  DetailPage({
    required this.itemId,
    required this.name,
    required this.price,
    required this.description,
    required this.id,
    required this.creationTime,
    required this.updateTime,
    required this.imageUrl,
  });

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _likedByCurrentUser = false;

  StreamSubscription<DocumentSnapshot>? _likesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchLikesCount();
  }

  @override
  void dispose() {
    _likesSubscription?.cancel(); // Cancel the Firestore listener
    super.dispose();
  }

  void _fetchLikesCount() async {
    // Fetch the likes count for the item from Firestore
    _likesSubscription = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.itemId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        Map<String, dynamic>? likesData =
            snapshot.data() as Map<String, dynamic>?;

        if (likesData != null) {
          setState(() {
            _likesCount = likesData['likesCount'] ?? 0;
            _isLiked = likesData['likedBy']?.contains(widget.id) ?? false;
          });
        }
      }
    });
  }

  void _likeItem() async {
    try {
      if (_isLiked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already liked this item.')),
        );
      } else {
        // Update the likes count and add the user's UID to the likedBy array
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.itemId)
            .update({
          'likesCount': _likesCount + 1,
          'likedBy': FieldValue.arrayUnion([widget.id]),
        });

        setState(() {
          _isLiked = true;
          _likesCount += 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item liked!')),
        );
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'not-found') {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.itemId)
            .set({
          'likesCount': 1,
          'likedBy': [widget.id],
        });

        setState(() {
          _isLiked = true;
          _likesCount = 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item liked!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An error occurred while liking the item.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    void _editItem() async {
      print('widget.id: ${widget.itemId}');
      print('currentUser.uid: ${FirebaseAuth.instance.currentUser?.uid}');

      if (widget.id == FirebaseAuth.instance.currentUser?.uid) {
        final updatedItem = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditPage(
              itemId: widget.itemId,
              updateTime: widget.updateTime,
            ),
          ),
        );

        if (updatedItem != null) {
          setState(() {
            widget.updateTime = updatedItem['updateTime'];
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not authorized to edit this item.')),
        );
      }
    }

    void _deleteItem() async {
       print('widget.id: ${widget.itemId}');
      print('currentUser.uid: ${FirebaseAuth.instance.currentUser?.uid}');

      if (widget.id == FirebaseAuth.instance.currentUser?.uid) {
        try {
          // Delete the item from the 'items' collection
          await FirebaseFirestore.instance
              .collection('item')
              .doc(widget.itemId)
              .delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item deleted successfully.')),
          );
          Future.delayed(Duration(milliseconds: 500), () {
            Navigator.pop(context);
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred while deleting the item.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are not authorized to delete this item.')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail'),
        actions: [
          IconButton(
            icon: Icon(Icons.create),
            onPressed: _editItem,
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteItem,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 16.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.name,
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    Row(
                      children: [
                        Text(
                          'Likes: $_likesCount',
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                        const SizedBox(width: 8.0),
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: _isLiked ? Colors.blue : null,
                          ),
                          onPressed: _likeItem,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Price:\$${widget.price.toString()}',
                  style: Theme.of(context).textTheme.subtitle1,
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Description: ${widget.description}',
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Item ID: ${widget.itemId}',
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                Text(
                  'UID: ${widget.id}',
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                Text(
                  'Creation Time: ${widget.creationTime.toDate()}',
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                Text(
                  'Update Time: ${widget.updateTime.toDate()}',
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                const SizedBox(height: 16.0),
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  height: 200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login'); 
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 30),
          Center(
            child: Image.network(
              FirebaseAuth.instance.currentUser?.photoURL != null
                  ? FirebaseAuth.instance.currentUser!.photoURL!
                  : 'http://handong.edu/site/handong/res/img/logo.png',
              width: 200,
              height: 200,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 20, top: 30),
            child: Text(
              '${FirebaseAuth.instance.currentUser?.uid ?? "anonymous uid"}',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 20, top: 10),
            child: Text(
              '${FirebaseAuth.instance.currentUser?.email ?? "Anonymous"}',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
          ),
          SizedBox(height: 30),
          Padding(
            padding:EdgeInsets.only(left: 20, top: 10),
            child: Text(
              'Kim Minkyoung',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
          ),
          // SizedBox(height: 10),
          Padding(
            padding:EdgeInsets.only(left: 20, top: 10),
            child: Text(
              'I promise to take the test honestly before GOD.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}


class AddPage extends StatefulWidget {
  @override
  _AddPageState createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final ImagePicker picker = ImagePicker();
  File? selectedImage;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String generateRandomId() {
    final String? randomId = FirebaseAuth.instance.currentUser?.uid;
    return '$randomId';
  }

  Future<void> _selectImageAndSetState() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        // print(' selectedImage:');
        // print(selectedImage);
      });
    }
    // else  print('no select');
    }

  Future<void> _uploadImageAndSaveToDatabase(
    String itemId,
    String id,
    Timestamp creationTime,
    Timestamp updateTime,
    File imageFile,
    String name,
    int price,
    String description,
  ) async {
    final storageRef = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('item')
        .child(itemId);
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadURL = await snapshot.ref.getDownloadURL();

    final productData = {
      'itemId': itemId,
      'id': id,
      'creationTime': creationTime,
      'updateTime': updateTime,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': downloadURL,
    };

    await FirebaseFirestore.instance.collection('item').add(productData);
  }

  Future<void> _saveProductToDatabase(
    String itemId,
    String id,
    Timestamp creationTime,
    Timestamp updateTime,
    String name,
    int price,
    String description,
  ) async {
    final productData = {
      'itemId': itemId,
      'id': id,
      'creationTime': creationTime,
      'updateTime': updateTime,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': 'https://handong.edu/site/handong/res/img/logo.png',
    };

    await FirebaseFirestore.instance.collection('item').add(productData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Add'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final String itemId = generateRandomId();
                final String id = FirebaseAuth.instance.currentUser?.uid ?? '';
                final Timestamp creationTime = Timestamp.now();
                final Timestamp updateTime = Timestamp.now();
                final String name = _nameController.text;
                final int price = int.parse(_priceController.text);
                final String description = _descriptionController.text;

                if (selectedImage != null) {
                  _uploadImageAndSaveToDatabase(
                    itemId,
                    id,
                    creationTime,
                    updateTime,
                    selectedImage!,
                    name,
                    price,
                    description,
                  );
                } else {
                  _saveProductToDatabase(
                    itemId,
                    id,
                    creationTime,
                    updateTime,
                    name,
                    price,
                    description,
                  );
                }

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectedImage != null)
              Image.file(
                selectedImage!,
                width: 200,
                height: 200,
              ),
            if (selectedImage == null)
              Image.network(
                'https://handong.edu/site/handong/res/img/logo.png',
                width: 200,
                height: 200,
              ),
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                try {
                  final XFile? pickedImage = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedImage != null) {
                    setState(() {
                      selectedImage = File(pickedImage.path);
                    });
                  }
                } catch (e) {
                  print('Error selecting image: $e');
                }
              },
              child: const Text('Select Image'),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}





class EditPage extends StatefulWidget {
  final String itemId;

  EditPage({required this.itemId, required Timestamp updateTime});

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  File? selectedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _fetchItemData() async {
    // Fetch the item data from Firestore using the provided itemId
    DocumentSnapshot itemSnapshot = await FirebaseFirestore.instance
        .collection('item')
        .doc(widget.itemId)
        .get();

    if (itemSnapshot.exists) {
      Map<String, dynamic>? itemData =
          itemSnapshot.data() as Map<String, dynamic>?;

      if (itemData != null) {
        setState(() {
          _nameController.text = itemData['name'];
          _priceController.text = itemData['price'].toString();
          _descriptionController.text = itemData['description'];
        });
      }
    }
  }

Future<void> _updateItemData() async {
  if (!mounted) {
    return; // 상태가 이미 해체된 경우 작업 중단
  }

  final String itemId = widget.itemId;
  final String id = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Timestamp updateTime = Timestamp.now();
  final String name = _nameController.text;
  final int price = int.parse(_priceController.text);
  final String description = _descriptionController.text;

  if (selectedImage != null) {
    await _uploadImageAndSaveToDatabase(
      itemId,
      id,
      updateTime,
      selectedImage!,
      name,
      price,
      description,
    );
  } else {
    await _saveProductToDatabase(
      itemId,
      id,
      updateTime,
      name,
      price,
      description,
    );
  }

  if (!mounted) {
    return; // 상태가 이미 해체된 경우 작업 중단
  }

  Navigator.pop(context);
}


  Future<void> _uploadImageAndSaveToDatabase(
    String itemId,
    String id,
    Timestamp updateTime,
    File imageFile,
    String name,
    int price,
    String description,
  ) async {
    final storageRef = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('item')
        .child(itemId);
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadURL = await snapshot.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('item').doc(itemId).update({
      'id': id,
      'updateTime': updateTime,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': downloadURL,
    });
  }

  Future<void> _saveProductToDatabase(
    String itemId,
    String id,
    Timestamp updateTime,
    String name,
    int price,
    String description,
  ) async {
    await FirebaseFirestore.instance.collection('item').doc(itemId).update({
      'id': id,
      'updateTime': updateTime,
      'name': name,
      'price': price,
      'description': description,
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchItemData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Edit'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _updateItemData();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectedImage != null)
              Image.file(
                selectedImage!,
                width: 200,
                height: 200,
              ),
            const SizedBox(height: 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                final XFile? pickedImage = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                );
                if (pickedImage != null) {
                  setState(() {
                    selectedImage = File(pickedImage.path);
                  });
                }
              },
              child: const Text('Select Image'),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }
}

class WishlistPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // final wishlistState = Provider.of<WishlistState>(context);
    // final wishlistItems = wishlistState.wishlistItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Wish list'),
      ),
      // body: ListView.builder(
      //   itemCount: wishlistItems.length,
      //   itemBuilder: (context, index) {
      //     final itemId = wishlistItems[index];
      //     // Replace the below code with your item card widget
      //     return Card(
      //       child: ListTile(
      //         title: Text('Item $itemId'),
      //         trailing: IconButton(
      //           icon: Icon(Icons.delete),
      //           onPressed: () {
      //             wishlistState.removeItemFromWishlist(itemId);
      //           },
      //         ),
      //       ),
      //     );
      //   },
      // ),
    );
  }
}
