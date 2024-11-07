import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(WhosThatApp());

class WhosThatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Who\'s That?',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GuessScreen(),
    );
  }
}

class GuessScreen extends StatefulWidget {
  @override
  _GuessScreenState createState() => _GuessScreenState();
}

class _GuessScreenState extends State<GuessScreen> {

  String capitalize(String s) => s.isNotEmpty
      ? s[0].toUpperCase() + s.substring(1).toLowerCase()
      : s;

  Future<void> _addPicture() async {
    final TextEditingController nameController = TextEditingController();
    final ImagePicker picker = ImagePicker();

    // Prompt for name
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "Name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );

    String name = nameController.text.trim();
    if (name.isEmpty) return;

    // Pick image
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Crop image
    final CroppedFile? croppedImage = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
      // aspectRatios: [
      //   CropAspectRatioPreset.square,
      //   CropAspectRatioPreset.ratio3x2,
      //   CropAspectRatioPreset.original,
      //   CropAspectRatioPreset.ratio4x3,
      //   CropAspectRatioPreset.ratio16x9
      // ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0,
        ),
      ],
    );

    if (croppedImage == null) return;

    // Save cropped image with the provided name
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/images/family';
    final Directory imagesDir = Directory(imagesPath);

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final String newPath = '$imagesPath/$name.${croppedImage.path.split('.').last}';
    await File(croppedImage.path).copy(newPath);

    // Reload family members to include the new image
    await loadFamilyMembers();
  }

  Future<void> _removePicture() async {
    // Retrieve the list of existing pictures
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/images/family';
    final Directory imagesDir = Directory(imagesPath);

    if (!await imagesDir.exists()) {
      // Handle the case where the directory doesn't exist
      return;
    }

    final List<FileSystemEntity> files = imagesDir.listSync();
    final List<String> pictureNames = files
        .where((file) {
      final String extension = file.path.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png'].contains(extension);
    })
        .map((file) => file.path.split('/').last)
        .toList();

    if (pictureNames.isEmpty) {
      // Handle the case where there are no pictures to remove
      return;
    }

    // Display the list and allow the user to select a picture to remove
    String? selectedPicture = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Picture to Remove'),
          content: SingleChildScrollView(
            child: ListBody(
              children: pictureNames.map((name) {
                return ListTile(
                  title: Text(name),
                  onTap: () {
                    Navigator.of(context).pop(name);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedPicture == null) return;

    // Remove the selected picture
    final File fileToRemove = File('$imagesPath/$selectedPicture');
    if (await fileToRemove.exists()) {
      await fileToRemove.delete();
    }

    // Reload family members to reflect the removed picture
    await loadFamilyMembers();
  }

  Future<List<String>> getFamilyMembers() async {
    // Get the application's documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/images/family';
    // List all files in the images directory
    final Directory imagesDir = Directory(imagesPath);
    // print('imagesDir: $imagesDir');
    // Revisit on real device to see if images get copied to the directory
    // I had to manually copy them to the directory on the emulator
    if (!await imagesDir.exists()) {
      // Handle the case where the directory doesn't exist
      return [];
    }

    final List<FileSystemEntity> files = imagesDir.listSync();

    // Filter out non-image files and extract names
    final List<String> familyMembers = files
        .where((file) {
      final String extension = file.path.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png'].contains(extension);
    })
        .map((file) {
      final String filename = file.path.split('/').last;
      final String name = filename.split('.').first;
      return capitalize(name);
    })
        .toList();

    return familyMembers;
  }
  List<String> familyMembers = [];
  late List<String> images;

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    final List<String> members = await getFamilyMembers();
    final List<String> imagePaths = generateImagePaths(members);
    setState(() {
      familyMembers = members;
      images = imagePaths;
    });
  }

  List<String> generateImagePaths(List<String> members) {
    return members.map((member) {
      String fileName = member.toLowerCase();
      return 'images/family/$fileName.png';
    }).toList();
  }

  Future<void> loadFamilyMembers() async {
    final List<String> members = await getFamilyMembers();
    setState(() {
      familyMembers = members;
    });
  }

  int selectedMemberIndex = -1;
  bool isSpinning = false;

  void spinWheel() {
    setState(() {
      isSpinning = true;
    });

    // Simulate a spin delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        selectedMemberIndex = Random().nextInt(familyMembers.length);
        isSpinning = false;
      });
    });
  }

  void guess(String guess) {
    if (guess == familyMembers[selectedMemberIndex]) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Correct!'),
          content: const Text('You guessed it right!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Try Again!'),
          content: const Text('That\'s not the right answer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('images/whosthatbkgrnd.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
          ),
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                  ),
                  child: SizedBox(height: 2),
                ),
                ListTile(
                  leading: Icon(Icons.add_a_photo),
                  title: Text('Add Picture'),
                  tileColor: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _addPicture();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Remove Picture'),
                  tileColor: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _removePicture();
                  },
                ),
              ],
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                ClipOval(
                  child: AnimatedRotation(
                    turns: isSpinning ? 3 : 0,
                    duration: const Duration(seconds: 2),
                    child: Image.asset(
                      selectedMemberIndex >= 0
                          ? images[selectedMemberIndex]
                          : 'images/spinner.png', // Placeholder spinner image
                      height: 300,
                      width: 300,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    isSpinning ? null : spinWheel();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Sets the button's background color to green
                    foregroundColor: Colors.white, // Sets the text color to white
                    side: BorderSide(color: Colors.white, width: 2), // Adds a white border with a width of 2
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18), // Rounds the corners with a radius of 18
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 46, vertical: 15),
                    textStyle: TextStyle(
                      fontSize: 30, // Sets the font size to 20
                      fontWeight: FontWeight.bold, // Sets the font weight to bold
                    ),// Adds padding inside the button
                  ),
                  child: Text('SPIN'), // Displays the text "SPIN" on the button
                ),

                if (selectedMemberIndex >= 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    height: 60, // Adjust the height as needed
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: familyMembers.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ElevatedButton(
                            onPressed: () => guess(familyMembers[index]),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, // Sets the button's background color to green
                              foregroundColor: Colors.green, // Sets the text color to white
                              side: BorderSide(color: Colors.green, width: 2), // Adds a white border with a width of 2
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18), // Rounds the corners with a radius of 18
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                              textStyle: TextStyle(
                                fontSize: 30, // Sets the font size to 20
                                fontWeight: FontWeight.bold, // Sets the font weight to bold
                              ),// Adds padding inside the button
                            ),
                            child: Text(familyMembers[index]), // Displays the text "SPIN" on the button
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
