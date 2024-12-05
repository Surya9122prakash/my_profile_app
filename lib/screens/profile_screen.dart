import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_profile_app/screens/signin_screen.dart';
import 'package:my_profile_app/theme/theme.dart';
import 'package:mime/mime.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  /// Utility function to show error messages using SnackBar
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Utility function to show critical errors using a dialog
  void _showDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Fetch user profile data
  Future<void> _getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print("Token is null. Redirecting to SigninScreen...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SigninScreen()),
        );
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.5:5000/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        setState(() {
          _nameController.text = jsonResponse['username'] ?? '';
          _emailController.text = jsonResponse['email'] ?? '';
          // Add a timestamp to bust the cache
          _profileImageUrl = jsonResponse['imageUrl'] != null
              ? '${jsonResponse['imageUrl']}?timestamp=${DateTime.now().millisecondsSinceEpoch}'
              : null;
        });
      } else if (response.statusCode == 401) {
        _showDialog(
            context, "Unauthorized", "Session expired. Please log in again.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SigninScreen()),
        );
      } else {
        _showError(context, "Failed to fetch profile. Please try again.");
      }
    } catch (e) {
      _showError(context, "An error occurred: $e");
    }
  }

  /// Update user profile data
  Future<void> _updateProfile() async {
    final name = _nameController.text;
    final email = _emailController.text;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    String? base64Image;
    if (_imageFile != null) {
      base64Image = await _encodeImageToBase64(_imageFile!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print("Token is null. Redirecting to SigninScreen...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SigninScreen()),
        );
        return;
      }

      final response = await http.put(
        Uri.parse('http://192.168.1.5:5000/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': name,
          'email': email,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'imageUrl': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        await _getProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated!')),
        );
      } else if (response.statusCode == 400) {
        _showError(context, "Invalid data. Please check your input.");
      } else if (response.statusCode == 500) {
        _showError(context, "Server error. Please try again later.");
      } else {
        _showError(context, "Failed to update profile. Please try again.");
      }
    } catch (e) {
      _showError(context, "An error occurred: $e");
    }
  }

  /// Encode image to base64 format
  Future<String> _encodeImageToBase64(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final mimeType = lookupMimeType(imageFile.path) ??
        'image/jpeg'; // Fallback to image/jpeg
    final base64Image = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Image';
  }

  /// Pick an image using camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    setState(() {
      _imageFile = pickedFile;
      _profileImageUrl = null; // Reset the imageUrl when a new image is picked
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token'); // Clear the token
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SigninScreen()),
              );
            },
          ),
        ],
        backgroundColor: myColor, // Use custom color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 80,
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path)) as ImageProvider
                        : _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : const AssetImage(
                                'assets/images/default_profile.png'),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled:
                              true, // Enables dynamic height adjustment
                          builder: (context) => Padding(
                            padding: MediaQuery.of(context)
                                .viewInsets, // Handles keyboard overlap
                            child: SizedBox(
                              height: 100,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera),
                                    title: const Text('Camera'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Gallery'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      await _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _currentPasswordController, // Added
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _newPasswordController, // Added
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
