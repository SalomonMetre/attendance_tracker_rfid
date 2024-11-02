// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:excel_dart/excel_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CheckAbsenceScreen extends StatefulWidget {
  @override
  _CheckAbsenceScreenState createState() => _CheckAbsenceScreenState();
}

class _CheckAbsenceScreenState extends State<CheckAbsenceScreen> {
  String? selectedPromotion;
  DateTime? selectedDate;
  List<Map<String, String>> absentStudents = [];
  String? message; // Message to display when attendance not recorded

  // Fetching promotion files and populating dropdown
  Future<List<String>> _getPromotionFiles() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> files = appDir.listSync();
    List<String> promotions = [];

    for (var file in files) {
      if (file is File &&
          basename(file.path).startsWith('M') &&
          file.path.endsWith('.xlsx')) {
        promotions.add(basenameWithoutExtension(file.path));
      }
    }

    return promotions;
  }

  // Check for absent students
  Future<void> checkAbsences() async {
    final prefs = await SharedPreferences.getInstance();
    final baseFilePath = prefs.getString('baseFilePath');

    if (baseFilePath == null) {
      print("Base file path not set.");
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final promotionFilePath = join(appDir.path, '$selectedPromotion.xlsx');

    final baseFile = File(baseFilePath);
    final promotionFile = File(promotionFilePath);

    if (!baseFile.existsSync() || !promotionFile.existsSync()) {
      print("One or more files do not exist.");
      return;
    }

    // Load student data from the base file
    final baseExcel = Excel.decodeBytes(baseFile.readAsBytesSync());
    final allStudents = <String, String>{}; // Map of student ID to name

    // Assuming student data is in the first sheet in the base file
    for (var row in baseExcel.tables.values.single.rows) {
      String id = "${row[0]?.value ?? ''}"; // ID in column A
      String name =
          "${row[1]?.value ?? ''} ${row[2]?.value ?? ''}"; // Name in columns B and C
      String promotion = row[3]?.value ?? ''; // Promotion in column D

      // Check if the promotion matches the selected promotion from the dropdown
      if (id.isNotEmpty &&
          name.trim().isNotEmpty &&
          promotion == selectedPromotion) {
        allStudents[id] = name;
      }
    }

    // Load the selected promotion file and sheet for the selected date
    final promotionExcel = Excel.decodeBytes(promotionFile.readAsBytesSync());
    String? sheetName;
    if (selectedDate != null) {
      sheetName =
          "${selectedDate!.year}_${selectedDate!.month}_${selectedDate!.day}";
    }

    if (sheetName != null && promotionExcel.tables.containsKey(sheetName)) {
      final presentStudents = promotionExcel.tables[sheetName]!.rows
          .map((row) => row[0]?.value) // Assuming ID is in the first column
          .whereType<String>()
          .toSet();

      // Identify absent students
      setState(() {
        absentStudents = allStudents.entries
            .where((entry) => !presentStudents.contains(entry.key))
            .map((entry) => {'ID': entry.key, 'Name': entry.value})
            .toList();
        message = null; // Clear message if data is found
      });
    } else {
      // Set message if the sheet does not exist
      setState(() {
        message = "Attendance for the selected date has not yet been recorded.";
        absentStudents.clear(); // Clear previous results
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Check Absences",
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<String>>(
        future: _getPromotionFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No promotion files found."));
          }

          List<String> promotionFiles = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Promotion", style: TextStyle(fontSize: 18)),
                DropdownButton<String>(
                  focusColor: Colors.white,
                  hint: const Text(
                    "Choose a promotion",
                    style: TextStyle(
                        color: Color(0xFF6F35A5), fontWeight: FontWeight.w900),
                  ),
                  value: selectedPromotion,
                  items: promotionFiles.map((promotion) {
                    return DropdownMenuItem<String>(
                      value: promotion,
                      child: Text(promotion),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPromotion = value;
                      absentStudents.clear(); // Clear previous results
                      message = null; // Clear message
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text("Select Date", style: TextStyle(fontSize: 18)),
                TextButton(
                  style: const ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Color(0xFF6F35A5)),
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );

                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                        absentStudents.clear(); // Clear previous results
                        message = null; // Clear message
                      });
                    }
                  },
                  child: Text(
                    selectedDate == null
                        ? "Pick a date"
                        : "Selected Date: ${selectedDate!.toLocal()}"
                            .split(' ')[0],
                    style: const TextStyle(
                        backgroundColor: Colors.white,
                        color: Color(0xFF6F35A5),
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: const ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                    backgroundColor: WidgetStatePropertyAll(Color(0xFF6F35A5)),
                  ),
                  onPressed: () {
                    if (selectedPromotion != null && selectedDate != null) {
                      checkAbsences();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Please select a promotion and a date.")),
                      );
                    }
                  },
                  child: const Text("Check Absences"),
                ),
                const SizedBox(height: 16),
                if (message != null) // Display message if there is one
                  Text(
                    message!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                if (absentStudents.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: absentStudents.length,
                      itemBuilder: (context, index) {
                        final student = absentStudents[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student['Name']!,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("ID: ${student['ID']!}"),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: "${student['ID']}"));
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text("ID ${student['ID']} of ${student['Name']} copied to clipboard !",), backgroundColor: Theme.of(context).primaryColor,),
                                      );
                                },
                                child: const Icon(Icons.copy),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
