import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(WhosThatApp());
  });
}

class WhosThatApp extends StatelessWidget {
  const WhosThatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Who\'s That?',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GuessScreen(),
    );
  }
}

class GuessScreen extends StatefulWidget {
  const GuessScreen({super.key});

  @override
  _GuessScreenState createState() => _GuessScreenState();
}

class _GuessScreenState extends State<GuessScreen> {
  final FlutterTts flutterTts = FlutterTts();
  late ConfettiController _confettiController;
  int incorrectGuessCount = 0;
  Map<String, String> familyMemberImages = {};
  bool isGuessCorrect =
      false; // Add this variable to track if the guess is correct

  final GlobalKey _menuKey = GlobalKey();
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _configureTts();
    _checkAndPromptForImages();
    initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isFirstLaunch = prefs.getBool('first_launch') ?? true;
      if (isFirstLaunch) {
        _initializeTargets();
        showTutorial();
        prefs.setBool('first_launch', false);
      }
    });
  }

  void _initializeTargets() {
    targets.add(
      TargetFocus(
        identify: "Menu",
        keyTarget: _menuKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Column(
              children: [
                Text(
                  "Tap here to add more pictures.",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
              ],
            ),
          ),
        ],
        shape: ShapeLightFocus.Circle,
      ),
    );
  }

  void showTutorial() {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
    ).show(context: context);
  }

  String capitalize(String s) => s.isNotEmpty
      ? s[0].toUpperCase() + s.substring(1).toLowerCase().trim()
      : s;

  Future<void> _configureTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.5); // Default is 0.5; range is 0.0 to 1.0
    await flutterTts.setVolume(8.0); // Volume level (0.0 to 1.0)
    await flutterTts.setPitch(1.7); // Default is 1.0; range is 0.5 to 2.0
  }

  Future<void> _speakCongratulatoryMessage(String name) async {
    var randCongrats = Random().nextInt(14);
    player.setReleaseMode(ReleaseMode.stop);
    player.play(AssetSource(
        'congrats_$randCongrats.mp3')); // Play the congratulation sound
  }

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

    // Pick an image
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Crop the image
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

    // Prompt for a name
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "Person's Name"),
            textCapitalization: TextCapitalization.words,
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

    // Generate a unique file name
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/assets/images';
    final Directory imagesDir = Directory(imagesPath);

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Create unique filename with timestamp
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String originalExtension = image.path.split('.').last;
    final String newFileName = '$name-$timestamp.$originalExtension';
    final String newPath = '$imagesPath/$newFileName';

    await File(croppedImage.path).copy(newPath);

    // Update familyMembers and images lists
    setState(() {
      if (!familyMembers
          .any((member) => member.toLowerCase() == name.toLowerCase())) {
        familyMembers
            .add(capitalize(name)); // Add the person's name (no duplicates)
      }
      images.add(newPath); // Add the new image
    });
  }

  Future<void> _removePicture() async {
    // Retrieve the application's documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/assets/images';
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
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('No Pictures Found'),
            content: Text('There are no pictures to remove.'),
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
      familyMembers.removeWhere(
          (member) => member.toLowerCase() == memberName.toLowerCase());
      images.removeWhere((imagePath) => imagePath.contains(memberName));
    });

    // Reset selectedMemberIndex if it points to a non-existent index
    if (selectedMemberIndex >= familyMembers.length) {
      selectedMemberIndex = -1;
    }
  }

  Future<List<String>> getFamilyMembers() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/assets/images';
    final Directory imagesDir = Directory(imagesPath);

    if (!await imagesDir.exists()) {
      return [];
    }

    final List<FileSystemEntity> files = imagesDir.listSync();

    // Extract names from file paths
    final List<String> members = files.where((file) {
      final String extension = file.path.split('.').last.toLowerCase();
      return ['jpg', 'jpeg', 'png'].contains(extension);
    }).map((file) {
      final String filename = file.path.split('/').last;
      final String name = filename.contains('-')
          ? filename.split('-').first // Extract name before timestamp
          : filename.split('.').first; // Use the whole name if no timestamp

      return capitalize(name);
    }).toList();

    return members.toSet().toList(); // Remove duplicates
  }

  List<String> familyMembers = [];
  late List<String> images;
  String obscurationType = "None";

  Future<void> _checkAndPromptForImages() async {
    final directory = await _getFamilyImagesDirectory();
    final files = directory.listSync();
    if (files.isEmpty) {
      _promptUserToUploadImages();
    }
  }

  Future<Directory> _getFamilyImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final familyDir = Directory('${appDir.path}/assets/images');
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
      familyMemberImages = Map.fromIterables(members, imagePaths);
    });
  }

  Future<List<String>> generateImagePaths(List<String> members) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String imagesPath = '${appDocDir.path}/assets/images';
    final Directory imagesDir = Directory(imagesPath);

    if (!await imagesDir.exists()) {
      return [];
    }

    final List<FileSystemEntity> files = imagesDir.listSync();
    final List<String> imagePaths = [];

    for (String member in members) {
      String fileNamePrefix = member.toLowerCase();

      // Collect all matching images for this member
      for (FileSystemEntity file in files) {
        if (file is File) {
          String filePath = file.path;
          String baseName = filePath.split('/').last.toLowerCase();
          if (baseName.startsWith(fileNamePrefix)) {
            imagePaths.add(filePath); // Add all matching images
          }
        }
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

  Future<void> spinWheel() async {
    setState(() {
      isSpinning = true;
      isGuessCorrect = false; // Reset the guess correct flag
      incorrectGuessCount = 0; // Reset the incorrect guess count
    });

    // Set the release mode to keep the source after playback has completed.
    player.setReleaseMode(ReleaseMode.stop);
    player.play(AssetSource('wheel_spin_short.mp4')); // Play the spinning sound

    // Simulate a spin delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        if (familyMembers.isEmpty || images.isEmpty) {
          selectedMemberIndex = -1;
          isSpinning = false;
          return;
        } else {
          // selectedMemberIndex = Random().nextInt(familyMembers.length);
          selectedMemberIndex = Random().nextInt(images.length);
          isSpinning = false;
        }
      });
    });
    await player.onPlayerComplete.first;
    var randWhosthat = Random().nextInt(3);
    player.setReleaseMode(ReleaseMode.stop);
    player.play(AssetSource(
        'whosthat_$randWhosthat.mp3')); // Play the who is that sound
  }

  void showKidFriendlyDialog(
      BuildContext context, String title, String message) {
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
                      backgroundColor: Colors
                          .white, // Sets the button's background color to green
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

  Future<void> guess(String guess) async {
    Completer<void> completer = Completer<void>();

    flutterTts.setCompletionHandler(() {
      completer.complete();
    });
    await flutterTts.speak(guess);
    await completer.future; // Wait for the speech to complete

    String selectedMember = images[selectedMemberIndex];
    if (selectedMember.toLowerCase().contains(guess.toLowerCase())) {
      setState(() {
        isGuessCorrect = true;
      });
      // // Set the release mode to keep the source after playback has completed.
      player.setReleaseMode(ReleaseMode.stop);
      player.play(AssetSource('won_game.mp3')); // Play the spinning sound
      _confettiController.play();
      await Future.delayed(Duration(seconds: 4));
      _speakCongratulatoryMessage(guess);
      setState(() {
        incorrectGuessCount = 0; // Reset the incorrect guess count
      });
    } else {
      showKidFriendlyDialog(
          context, 'Try Again!', 'That\'s not the right answer.');
      player.setReleaseMode(ReleaseMode.stop);
      player.play(AssetSource('lost_game.mp3')); // Play the spinning sound
      setState(() {
        incorrectGuessCount++;
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: Stack(
          children: [
            Container(
              width: double
                  .infinity, // Ensure the container takes up the full width
              height: double
                  .infinity, // Ensure the container takes up the full height
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/whosthatbkgrnd.png'),
                  fit: BoxFit
                      .contain, // Use BoxFit.contain to prevent stretching
                ),
              ),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                actions: [
                  PopupMenuButton<String>(
                    key: _menuKey,
                    icon: Icon(Icons.menu,
                        color: Colors.white, size: 30), // Enhanced Icon
                    color: Colors.white, // Menu Background
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Rounded corners
                    ),
                    onSelected: (String result) {
                      setState(() {
                        if (result == 'add_picture') {
                          _addPicture();
                        } else if (result == 'remove_picture') {
                          _removePicture();
                        } else {
                          obscurationType =
                              result; // Update the selected obscuration type
                        }
                      });
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'add_picture',
                        child: ListTile(
                          leading: Icon(Icons.add_a_photo, color: Colors.green),
                          title: Text(
                            'Add Picture',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'remove_picture',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text(
                            'Remove Picture',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[
                                50], // Light background for expansion tile
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Icon(Icons.blur_on, color: Colors.blue),
                                SizedBox(width: 10),
                                Text(
                                  "Peek-a-Boo Settings",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              ListTile(
                                leading: Icon(Icons.visibility,
                                    color: Colors.orange),
                                title: Text(
                                  "None",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(
                                      context, 'None'); // Pass the value back
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.blur_circular,
                                    color: Colors.purple),
                                title: Text(
                                  "Blur",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(
                                      context, 'Blur'); // Pass the value back
                                },
                              ),
                              ListTile(
                                leading:
                                    Icon(Icons.grid_on, color: Colors.teal),
                                title: Text(
                                  "Grid Cover",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context,
                                      'Grid Cover'); // Pass the value back
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Align(
                      alignment:
                          Alignment.topCenter, // Adjust alignment as needed
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality:
                            BlastDirectionality.explosive, // Random direction
                        shouldLoop: false, // Stop after the duration
                        colors: const [
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.yellow
                        ], // Customize colors
                        // Additional customization
                      ),
                    ),
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            150.0), // Make the image rounded
                        child: AnimatedRotation(
                          turns: isSpinning ? 3 : 0,
                          duration: const Duration(seconds: 2),
                          child: selectedMemberIndex >= 0 &&
                                  File(images[selectedMemberIndex]).existsSync()
                              ? getObscuredImage(
                                  File(images[selectedMemberIndex]),
                                  obscurationType, // Pass the selected obscuration type
                                )
                              : Image.asset(
                                  'images/spinner.png', // Placeholder spinner image
                                  height: 350,
                                  width: 350,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        isSpinning ? null : spinWheel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors
                            .green, // Sets the button's background color to green
                        foregroundColor:
                            Colors.white, // Sets the text color to white
                        side: BorderSide(
                            color: Colors.white,
                            width: 2), // Adds a white border with a width of 2
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              18), // Rounds the corners with a radius of 18
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 46, vertical: 15),
                        textStyle: TextStyle(
                          fontSize: 30, // Sets the font size to 20
                          fontWeight:
                              FontWeight.bold, // Sets the font weight to bold
                        ), // Adds padding inside the button
                      ),
                      child: Text(
                          'SPIN'), // Displays the text "SPIN" on the button
                    ),
                    if (selectedMemberIndex >= 0) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 70, // Adjust the height as needed
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: familyMembers.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ElevatedButton(
                                onPressed: () => guess(familyMembers[index]),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors
                                      .white, // Sets the button's background color to green
                                  foregroundColor: Colors
                                      .green, // Sets the text color to white
                                  side: BorderSide(
                                      color: Colors.green,
                                      width:
                                          2), // Adds a white border with a width of 2
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        18), // Rounds the corners with a radius of 18
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 36, vertical: 15),
                                  textStyle: TextStyle(
                                    fontSize: 30, // Sets the font size to 20
                                    fontWeight: FontWeight
                                        .bold, // Sets the font weight to bold
                                  ), // Adds padding inside the button
                                ),
                                child: Text(familyMembers[
                                    index]), // Displays the text "SPIN" on the button
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
        ),
      ),
    );
  }

  Widget getObscuredImage(File imageFile, String type) {
    if (isGuessCorrect) {
      return Image.file(
        imageFile,
        height: 350,
        width: 350,
        fit: BoxFit.cover,
      );
    }
    switch (type) {
      case "Blur":
        double revealPercentage = incorrectGuessCount * 0.25;
        return Stack(
          children: [
            Image.file(
              imageFile,
              height: 350,
              width: 350,
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 10 * (1 - revealPercentage),
                    sigmaY: 10 * (1 - revealPercentage)),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        );
      case "Grid Cover":
        double gridSize = 4;
        double boxSize = 350 / gridSize;
        List<Widget> grid = [];
        for (int i = 0; i < gridSize; i++) {
          for (int j = 0; j < gridSize; j++) {
            grid.add(Positioned(
              top: i * boxSize,
              left: j * boxSize,
              child: Container(
                width: boxSize,
                height: boxSize,
                color: Colors.black.withAlpha(
                    ((0.92 * (1 - incorrectGuessCount * 0.25)) * 255).toInt()),
              ),
            ));
          }
        }
        return Stack(
          children: [
            Image.file(
              imageFile,
              height: 350,
              width: 350,
              fit: BoxFit.cover,
            ),
            ...grid,
          ],
        );
      default:
        return Image.file(
          imageFile,
          height: 350,
          width: 350,
          fit: BoxFit.cover,
        ); // Default to no obscuration
    }
  }

  Widget blurImage(File imageFile) {
    return Stack(
      children: [
        Image.file(
          imageFile,
          height: 350,
          width: 350,
          fit: BoxFit.cover,
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter:
                ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Adjust blur level
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget gridCoverImage(File imageFile) {
    int gridSize = 4; // Number of grid rows and columns
    return Stack(
      children: [
        Image.file(
          imageFile,
          height: 350,
          width: 350,
          fit: BoxFit.cover,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            double boxSize = constraints.maxWidth / gridSize;
            List<Widget> grid = [];
            for (int i = 0; i < gridSize; i++) {
              for (int j = 0; j < gridSize; j++) {
                grid.add(Positioned(
                  top: i * boxSize,
                  left: j * boxSize,
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    color: Colors.black
                        .withAlpha((0.5 * 255).toInt()), // Cover opacity
                  ),
                ));
              }
            }
            return Stack(children: grid);
          },
        ),
      ],
    );
  }
}
