// ignore_for_file: unnecessary_null_comparison, use_build_context_synchronously, library_private_types_in_public_api
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel_dart/excel_dart.dart';
import 'package:gestion_pointages_app/screens/check_absence.dart';
import 'package:gestion_pointages_app/utilities/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const AttendanceTrackerApp());
}

class AttendanceTrackerApp extends StatelessWidget {
  const AttendanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance Tracker',
      theme: appTheme,
      home: const AttendanceHomePage(),
      // home: CheckAbsenceScreen(),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  _AttendanceHomePageState createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  String? baseFilePath;
  String? attendanceFilePath;
  bool isProcessing = false;

  // Controllers for Search Fields
  final TextEditingController _searchIdController = TextEditingController();
  final TextEditingController _searchDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBaseFilePath();
  }

  @override
  void dispose() {
    _searchIdController.dispose();
    _searchDateController.dispose();
    super.dispose();
  }

  // Load the base file path from shared_preferences
  Future<void> _loadBaseFilePath() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      baseFilePath = prefs.getString('baseFilePath');
    });
  }

  // Save the base file path to shared_preferences
  Future<void> _saveBaseFilePath(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseFilePath', path);
    setState(() {
      baseFilePath = path;
    });
  }

  // Upload Base Excel File
  Future<void> _uploadBaseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        await _saveBaseFilePath(path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Base Excel file uploaded successfully.'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
        print('Base Excel file uploaded: $path');
      }
    } catch (e) {
      print('Error uploading base file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading base file: $e')),
      );
    }
  }

  // Upload Attendance Text File
  Future<void> _uploadAttendanceFile() async {
    if (baseFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload the base Excel file first.'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        setState(() {
          attendanceFilePath = path;
        });

        print('Attendance file uploaded: $path');

        // Start processing
        await _processAttendanceFile(path);
      }
    } catch (e) {
      print('Error uploading attendance file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading attendance file: $e'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  // Process Attendance File
  Future<void> _processAttendanceFile(String path) async {
    setState(() {
      isProcessing = true;
    });

    try {
      // Read attendance text file
      File attendanceFile = File(path);
      List<String> lines = await attendanceFile.readAsLines();
      print(
          'Attendance file read successfully. Number of lines: ${lines.length}');

      // Read base Excel file
      File baseFile = File(baseFilePath!);
      List<int> baseBytes = await baseFile.readAsBytes();
      Excel baseExcel = Excel.decodeBytes(baseBytes);
      Sheet baseSheet = baseExcel.tables.values.first; // Assuming first sheet

      // Create a map of ID to student details for quick lookup
      Map<String, Map<String, dynamic>> studentMap = {};
      for (var row in baseSheet.rows) {
        if (row.length < 4) continue; // Ensure there are enough columns
        String id = row[0]?.value.toString() ?? '';
        if (id.isEmpty) continue;
        studentMap[id] = {
          'Nom': row[1]?.value.toString() ?? '',
          'Prénom': row[2]?.value.toString() ?? '',
          'Promotion': row[3]?.value.toString() ?? '',
        };
      }
      print('Base Excel file loaded. Number of students: ${studentMap.length}');

      // Iterate over each attendance record
      for (String line in lines) {
        if (line.trim().isEmpty) continue; // Skip empty lines
        List<String> parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue; // Ensure proper format

        String id = parts[0];
        String date = parts[1];
        String heure = parts[2];

        print('Processing attendance record: ID=$id, Date=$date, Heure=$heure');

        if (!studentMap.containsKey(id)) {
          // Prompt user to add new student details
          Map<String, String>? newStudent = await _promptNewStudent(id);
          if (newStudent == null) {
            // User cancelled the form
            print('User cancelled adding new student for ID: $id');
            continue;
          }

          // Add new student to baseExcel
          int newRowIndex = baseSheet.maxRows;
          baseSheet.cell(CellIndex.indexByString("A${newRowIndex + 1}")).value =
              id;
          baseSheet.cell(CellIndex.indexByString("B${newRowIndex + 1}")).value =
              newStudent['Nom'];
          baseSheet.cell(CellIndex.indexByString("C${newRowIndex + 1}")).value =
              newStudent['Prénom'];
          baseSheet.cell(CellIndex.indexByString("D${newRowIndex + 1}")).value =
              newStudent['Promotion'];

          // Update studentMap
          studentMap[id] = newStudent;
          print('New student added: $newStudent');
        }

        // Retrieve student details
        Map<String, dynamic> student = studentMap[id]!;

        String promotion = student['Promotion'];
        String nom = student['Nom'];
        String prenom = student['Prénom'];

        // Handle Promotion-specific Excel file
        Directory appDir = await getApplicationDocumentsDirectory();
        String promotionFileName = '$promotion.xlsx';
        String promotionFilePath = p.join(appDir.path, promotionFileName);
        File promotionFile = File(promotionFilePath);
        Excel promotionExcel;

        if (promotionFile.existsSync()) {
          // Load existing promotion Excel file
          List<int> promoBytes = await promotionFile.readAsBytes();
          promotionExcel = Excel.decodeBytes(promoBytes);
          print('Promotion Excel file loaded: $promotionFilePath');
        } else {
          // Create new promotion Excel file
          promotionExcel = Excel.createExcel();
          promotionExcel
              .delete(promotionExcel.tables.keys.first); // Remove default sheet
          print('Promotion Excel file created: $promotionFilePath');
        }

        // Check or create sheet for the date
        String sanitizedDate = safeSheetName(date);
        Sheet? dateSheet = promotionExcel[sanitizedDate];
        if (dateSheet == null) {
          dateSheet = promotionExcel[sanitizedDate];
          print('Created new sheet for date: $sanitizedDate');
        } else {
          print('Sheet for date $sanitizedDate already exists.');
        }

        // Prepare the row data
        List<dynamic> attendanceRow = [id, nom, prenom, promotion, heure];

        // Check for duplicates
        bool isDuplicate = false;
        for (var existingRow in dateSheet.rows) {
          if (existingRow.length < 5) continue;
          String existingId = existingRow[0]?.value.toString() ?? '';
          String existingHeure = existingRow[4]?.value.toString() ?? '';
          if (existingId == id && existingHeure == heure) {
            isDuplicate = true;
            break;
          }
        }

        if (!isDuplicate) {
          // Append the attendance row
          dateSheet.appendRow(attendanceRow);
          print(
              'Attendance record added to sheet $sanitizedDate: $attendanceRow');
        } else {
          print(
              'Duplicate attendance record found for ID: $id at Heure: $heure. Skipping.');
        }

        // Save the promotion Excel file after each record
        List<int>? promoFileBytes = promotionExcel.save();
        if (promoFileBytes != null) {
          await promotionFile.writeAsBytes(promoFileBytes, flush: true);
          print('Promotion Excel file saved: $promotionFilePath');
        } else {
          print('Failed to save promotion Excel file: $promotionFilePath');
        }
      }

      // Save the updated base Excel file
      List<int>? updatedBaseBytes = baseExcel.save();
      if (updatedBaseBytes != null) {
        await baseFile.writeAsBytes(updatedBaseBytes, flush: true);
        print('Base Excel file saved: $baseFilePath');
      } else {
        print('Failed to save base Excel file: $baseFilePath');
      }

      setState(() {
        isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Attendance processed successfully.'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {
      setState(() {
        isProcessing = false;
      });
      print('Error processing attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing attendance: $e'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  // Function to sanitize sheet names
  String safeSheetName(String name) {
    // Excel sheet names cannot contain certain characters and have a max length of 31
    String sanitized = name.replaceAll(RegExp(r'[\\/?*\[\]]'), '_');
    if (sanitized.length > 31) {
      sanitized = sanitized.substring(0, 31);
    }
    return sanitized;
  }

  // Prompt user to add new student details
  Future<Map<String, String>?> _promptNewStudent(String id) async {
    String? nom;
    String? prenom;
    String? promotion;

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Student ID: $id'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Nom'),
                  onChanged: (value) {
                    nom = value;
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  onChanged: (value) {
                    prenom = value;
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Promotion'),
                  onChanged: (value) {
                    promotion = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                if (nom != null &&
                    prenom != null &&
                    promotion != null &&
                    nom!.isNotEmpty &&
                    prenom!.isNotEmpty &&
                    promotion!.isNotEmpty) {
                  Navigator.of(context).pop<Map<String, String>>({
                    'Nom': nom!,
                    'Prénom': prenom!,
                    'Promotion': promotion!,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('All fields are required.'),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Search Functionality
  Future<void> _searchStudent() async {
    String searchId = _searchIdController.text.trim();
    String searchDate = _searchDateController.text.trim();

    if (searchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please enter a Student ID to search.'),
            backgroundColor: Theme.of(context).primaryColor),
      );
      return;
    }

    if (baseFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Base Excel file not found.'),
            backgroundColor: Theme.of(context).primaryColor),
      );
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      // Read base Excel file
      File baseFile = File(baseFilePath!);
      List<int> baseBytes = await baseFile.readAsBytes();
      Excel baseExcel = Excel.decodeBytes(baseBytes);
      Sheet baseSheet = baseExcel.tables.values.first; // Assuming first sheet

      // Find student in base file
      Map<String, dynamic>? student;
      for (var row in baseSheet.rows) {
        if (row.length < 4) continue; // Ensure there are enough columns
        String id = row[0]?.value.toString() ?? '';
        if (id == searchId) {
          student = {
            'ID': id,
            'Nom': row[1]?.value.toString() ?? '',
            'Prénom': row[2]?.value.toString() ?? '',
            'Promotion': row[3]?.value.toString() ?? '',
          };
          break;
        }
      }

      if (student == null) {
        setState(() {
          isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Student with ID $searchId not found in the base file.'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
        return;
      }

      // If date is provided, search in promotion-specific Excel file
      List<String> attendanceHours =
          []; // List to hold multiple attendance records
      if (searchDate.isNotEmpty) {
        String promotion = student['Promotion'];
        Directory appDir = await getApplicationDocumentsDirectory();
        String promotionFileName = '$promotion.xlsx';
        String promotionFilePath = p.join(appDir.path, promotionFileName);
        File promotionFile = File(promotionFilePath);

        if (promotionFile.existsSync()) {
          Excel promotionExcel =
              Excel.decodeBytes(await promotionFile.readAsBytes());
          String sanitizedDate = safeSheetName(searchDate);
          Sheet? dateSheet = promotionExcel[sanitizedDate];

          if (dateSheet != null) {
            for (var row in dateSheet.rows) {
              if (row.length < 5) continue;
              String id = row[0]?.value.toString() ?? '';
              String heure = row[4]?.value.toString() ?? '';
              if (id == searchId) {
                attendanceHours.add(heure); // Collecting all hours
              }
            }
          }
        }
      }

      setState(() {
        isProcessing = false;
      });

      // Display the results
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Search Results',
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${student!['ID']}'),
                Text('Nom: ${student['Nom']}'),
                Text('Prénom: ${student['Prénom']}'),
                Text('Promotion: ${student['Promotion']}'),
                if (searchDate.isNotEmpty)
                  if (attendanceHours.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hours on $searchDate:'),
                        ...attendanceHours.map((heure) => Text(heure)).toList(),
                      ],
                    )
                  else
                    Text('No attendance record found on $searchDate.'),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        isProcessing = false;
      });
      print('Error during search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during search: $e'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String baseFileDisplay = baseFilePath != null
        ? p.basename(baseFilePath!)
        : 'No Base File Uploaded';
    String attendanceFileDisplay = attendanceFilePath != null
        ? p.basename(attendanceFilePath!)
        : 'No Attendance File Uploaded';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Attendance Tracker'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Upload Base File Section
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Base Excel File'),
              subtitle: Text(baseFileDisplay),
              trailing: ElevatedButton(
                style: ButtonStyle(
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  backgroundColor:
                      WidgetStatePropertyAll(Theme.of(context).primaryColor),
                ),
                onPressed: _uploadBaseFile,
                child: const Text('Upload Base File'),
              ),
            ),
            const Divider(),
            // Upload Attendance File Section
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('Attendance Text File'),
              subtitle: Text(attendanceFileDisplay),
              trailing: ElevatedButton(
                style: ButtonStyle(
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  backgroundColor:
                      WidgetStatePropertyAll(Theme.of(context).primaryColor),
                ),
                onPressed: isProcessing ? null : _uploadAttendanceFile,
                child: const Text('Upload Attendance File'),
              ),
            ),
            const Divider(),
            ListTile(
              trailing: ElevatedButton(
                style: const ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                  backgroundColor: WidgetStatePropertyAll(Color(0xFF6F35A5)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CheckAbsenceScreen()),
                  );
                },
                child: const Text(
                  "Check Absence",
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 20),
            // Search Section
            const Text(
              'Search Student',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Search ID Input
            TextField(
              controller: _searchIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            // Search Date Input (Optional)
            TextField(
              controller: _searchDateController,
              decoration: const InputDecoration(
                labelText: 'Date (YYYY/MM/DD)',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            // Search Button
            ElevatedButton(
              style: ButtonStyle(
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                backgroundColor:
                    WidgetStatePropertyAll(Theme.of(context).primaryColor),
              ),
              onPressed: isProcessing ? null : _searchStudent,
              child: const Text('Search'),
            ),
            const Divider(),
            // Processing Indicator
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
