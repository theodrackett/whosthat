import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

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

Future<void> requestPhotoLibraryPermission() async {
  PermissionStatus status = await Permission.photos.status;

  if (status.isDenied || status.isRestricted) {
    // Request permission
    status = await Permission.photos.request();
  }

  if (status.isGranted) {
    // Permission granted, proceed with accessing the photo library
  } else if (status.isPermanentlyDenied) {
    // Permission permanently denied, prompt user to open settings
    openAppSettings();
  }
}

Future<void> _addPicture() async {
  requestPhotoLibraryPermission();
  final TextEditingController nameController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  // Pick image
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  if (image == null) return;

  // Crop image
  final CroppedFile? croppedImage = await ImageCropper().cropImage(
    sourcePath: image.path,
    aspectRatio: CropAspectRatio(ratioX: 16, ratioY: 9),
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

  // Extract the original extension
  String originalExtension = image.path.split('.').last;

  // Save cropped image with the provided name and original extension
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String imagesPath = '${appDocDir.path}/images/family';
  final Directory imagesDir = Directory(imagesPath);

  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }

  final String newPath = '$imagesPath/$name.$originalExtension';
  await File(croppedImage.path).copy(newPath);

  // // Reload family members to include the new image
  // await loadFamilyMembers();

    // Update familyMembers and images lists
  setState(() {
    familyMembers.add(name);
    images.add(newPath);
  });
}
Future<void> _removePicture() async {
  // Retrieve the application's documents directory
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String imagesPath = '${appDocDir.path}/images/family';
  final Directory imagesDir = Directory(imagesPath);

  if (!await imagesDir.exists()) {
    // Handle the case where the directory doesn't exist
    return;
  }

  // List all files in the images directory
  final List<FileSystemEntity> files = imagesDir.listSync();
  final List<String> pictureNames = files
      .where((file) {
        final String extension = file.path.split('.').last.toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension);
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

  // Extract the member name from the selected picture's filename
  final String memberName = selectedPicture.split('.').first;

  // Update the familyMembers and images lists
  setState(() {
    familyMembers.removeWhere((member) => member.toLowerCase() == memberName.toLowerCase());
    images.removeWhere((imagePath) => imagePath.contains(memberName));
  });

      // Reset selectedMemberIndex if it points to a non-existent index
    if (selectedMemberIndex >= familyMembers.length) {
      selectedMemberIndex = -1;
    }
}

  Future<List<String>> getFamilyMembers() async {
    // Get the application's documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/images/family';
    // List all files in the images directory
    final Directory imagesDir = Directory(imagesPath);
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
    _checkAndPromptForImages();
    initializeData();
  }

  Future<void> _checkAndPromptForImages() async {
    final directory = await _getFamilyImagesDirectory();
    final files = directory.listSync();
    if (files.isEmpty) {
      _promptUserToUploadImages();
    }
  }

  Future<Directory> _getFamilyImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final familyDir = Directory('${appDir.path}/images/family');
    if (!await familyDir.exists()) {
      await familyDir.create(recursive: true);
    }
    return familyDir;
  }

  void _promptUserToUploadImages() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No Images Found'),
          content: Text('Would you like to upload images?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addPicture();
              },
              child: Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  Future<void> initializeData() async {
    final List<String> members = await getFamilyMembers();
    final List<String> imagePaths = await generateImagePaths(members);
    setState(() {
      familyMembers = members;
      images = imagePaths;
    });
  }

Future<List<String>> generateImagePaths(List<String> members) async {
  final List<String> supportedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp'];
  final List<String> imagePaths = [];

  // Retrieve the application's documents directory
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String imagesPath = '${appDocDir.path}/images/family';
  final Directory imagesDir = Directory(imagesPath);

  if (!await imagesDir.exists()) {
    // If the directory doesn't exist, return an empty list
    return imagePaths;
  }

  // List all files in the directory
  final List<FileSystemEntity> files = imagesDir.listSync();

  for (String member in members) {
    String fileName = member.toLowerCase();
    bool found = false;

    for (FileSystemEntity file in files) {
      if (file is File) {
        String filePath = file.path;
        String baseName = filePath.split('/').last;
        String nameWithoutExtension = baseName.split('.').first.toLowerCase();
        String extension = baseName.split('.').last.toLowerCase();

        if (nameWithoutExtension == fileName && supportedExtensions.contains(extension)) {
          imagePaths.add(filePath);
          found = true;
          break;
        }
      }
    }

    if (!found) {
      // Handle the case where no matching file was found for the member
      print('No image found for member: $member');
    }
  }

  return imagePaths;
}



  Future<void> loadFamilyMembers() async {
    final List<String> members = await getFamilyMembers();
    setState(() {
      familyMembers = members;
    });
  }

  int selectedMemberIndex = -1;
  bool isSpinning = false;
  final player = AudioPlayer();

  void spinWheel() {
    setState(() {
      isSpinning = true;
    });

    // Give thanks to Sound Effect from <a href="https://pixabay.com/sound-effects/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=36693">Pixabay</a>
    // Sound Effect by <a href="https://pixabay.com/users/pw23check-44527802/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=218995">PW23CHECK</a> from <a href="https://pixabay.com/sound-effects//?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=218995">Pixabay</a>
    // Sound Effect from <a href="https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=91932">Pixabay</a>
    // Sound Effect from <a href="https://pixabay.com/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=89697">Pixabay</a>
    // Sound Effect from <a href="https://pixabay.com/sound-effects/?utm_source=link-attribution&utm_medium=referral&utm_campaign=music&utm_content=6008">Pixabay</a>

    // Set the release mode to keep the source after playback has completed.
    player.setReleaseMode(ReleaseMode.stop);
    player.play(AssetSource('wheel_spin_short.mp4')); // Play the spinning sound


    // Simulate a spin delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        selectedMemberIndex = Random().nextInt(familyMembers.length);
        isSpinning = false;
      });
    });

  }

  void showKidFriendlyDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.orange,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Comic Sans MS',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Comic Sans MS',
                      fontSize: 18,
                      color: Colors.brown,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      // primary: Colors.orange,
                      backgroundColor: Colors.white, // Sets the button's background color to green
                      foregroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontFamily: 'Comic Sans MS',
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void guess(String guess) {
    if (guess == familyMembers[selectedMemberIndex]) {

      showKidFriendlyDialog(context, 'Correct!', 'You guessed it right!');
      // Set the release mode to keep the source after playback has completed.
      player.setReleaseMode(ReleaseMode.stop);
      player.play(AssetSource('won_game.mp3')); // Play the spinning sound

    } else {

      showKidFriendlyDialog(context, 'Try Again!', 'That\'s not the right answer.');
      // Set the release mode to keep the source after playback has completed.
      player.setReleaseMode(ReleaseMode.stop);
      player.play(AssetSource('lost_game.mp3')); // Play the spinning sound
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(150.0), // Make the image rounded
                  child: AnimatedRotation(
                    turns: isSpinning ? 3 : 0,
                    duration: const Duration(seconds: 2),
                    child: Image.asset(
                      selectedMemberIndex >= 0
                          ? images[selectedMemberIndex]
                          : 'images/spinner.png', // Placeholder spinner image
                      height: 350,
                      width: 350,
                      fit: BoxFit.cover, // Ensure the image covers the container
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
