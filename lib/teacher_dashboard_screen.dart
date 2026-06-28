import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';
import 'database_helper.dart';
import 'class_management_screen.dart';
import 'login_portal_screen.dart';
import 'pdf_viewer_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final bool isSomali;
  final String username;
  final String displayName;

  const TeacherDashboardScreen({
    super.key,
    required this.isSomali,
    required this.username,
    required this.displayName,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _currentIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _materialTitleController = TextEditingController();
  final TextEditingController _materialDescController = TextEditingController();

  List<Map<String, String>> _teacherClasses = [];
  List<Map<String, dynamic>> _uploadedMaterials = [];

  String? _selectedClassCode;
  String? _selectedFilePath;
  String? _selectedFileName;

  int _totalStudents = 0;

  bool _isDarkMode = false;
  bool _isSyncing = false;
  bool _isUploading = false;
  bool _isCreatingClass = false;

  late String _currentDisplayName;

  static const List<String> _allowedExtensions = [
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'xls', 'xlsx'
  ];

  String get _userEmail => widget.username;

  @override
  void initState() {
    super.initState();
    _currentDisplayName = widget.displayName;
    _loadAll();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _materialTitleController.dispose();
    _materialDescController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadClasses();
    await _loadMaterials();
    await _loadStudentCount();
  }

  Future<void> _loadClasses() async {
    final classes = await _dbHelper.getTeacherClasses(_userEmail);
    if (!mounted) return;
    setState(() {
      _teacherClasses = classes;
      if (classes.isNotEmpty && _selectedClassCode == null) {
        _selectedClassCode = classes.first['class_code'];
      }
    });
  }

  Future<void> _loadMaterials() async {
    List<Map<String, dynamic>> all = [];
    for (final cls in _teacherClasses) {
      final code = cls['class_code'];
      if (code != null) {
        final mats = await _dbHelper.getMaterialsByClass(code);
        for (final m in mats) {
          all.add({...m, 'class_name': cls['class_name'] ?? code});
        }
      }
    }
    if (!mounted) return;
    setState(() => _uploadedMaterials = all);
  }

  Future<void> _loadStudentCount() async {
    int total = 0;
    for (final cls in _teacherClasses) {
      final code = cls['class_code'];
      if (code != null) {
        final count = await _dbHelper.getStudentCountByClass(code);
        total += count;
      }
    }
    if (!mounted) return;
    setState(() => _totalStudents = total);
  }

  Future<void> _handleCreateClass() async {
    if (_classNameController.text.trim().isEmpty) return;
    setState(() => _isCreatingClass = true);
    final classCode = await _dbHelper.createClass(_classNameController.text.trim(), _userEmail);
    setState(() => _isCreatingClass = false);
    _classNameController.clear();
    if (!mounted) return;
    Navigator.pop(context);
    await _loadAll();
    _showSnack(
      widget.isSomali
          ? "Fasalka waa la abuuray! Koodhka: $classCode (Ardayda way si toos ah u heli karaan internet)"
          : "Class created! Code: $classCode (Students can access it via internet)",
      Colors.green,
    );
  }

  Future<void> _handleDeleteClass(String classCode, String className) async {
    final confirmed = await _showConfirmDialog(
      title: widget.isSomali ? "Tirtir Fasalka" : "Delete Class",
      content: widget.isSomali
          ? "Ma hubtaa inaad tirtireyso '$className'? Dhammaan casharradii iyo xogta fasalka ayaa tirtirmi doonta."
          : "Are you sure you want to delete '$className'? All materials and class data will be removed.",
    );
    if (!confirmed) return;
    await _dbHelper.deleteClass(classCode);
    if (!mounted) return;
    setState(() {
      if (_selectedClassCode == classCode) _selectedClassCode = null;
    });
    await _loadAll();
    _showSnack(
      widget.isSomali ? "Fasalka waa la tirtiray!" : "Class deleted successfully!",
      Colors.green,
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  Future<String?> _copyFileToAppDir(String sourcePath, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final destDir = Directory(p.join(appDir.path, 'materials'));
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final destPath = p.join(destDir.path, uniqueName);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint("Error copying file: $e");
      return null;
    }
  }

  Future<void> _handleUploadMaterial() async {
    final title = _materialTitleController.text.trim();
    final desc = _materialDescController.text.trim();

    if (title.isEmpty || _selectedFilePath == null || _selectedClassCode == null) {
      _showSnack(
        widget.isSomali
            ? "Fadlan buuxi cinwaanka, dooro fasal oo soo xul faylka!"
            : "Please enter title, select class and choose a file!",
        Colors.orange,
      );
      return;
    }

    setState(() => _isUploading = true);

    final savedPath = await _copyFileToAppDir(_selectedFilePath!, _selectedFileName!);
    if (savedPath == null) {
      setState(() => _isUploading = false);
      _showSnack(
        widget.isSomali
            ? "Waxaa dhacay khalad marka la kaydinayey faylka!"
            : "Error saving file to device storage!",
        Colors.redAccent,
      );
      return;
    }

    final result = await _dbHelper.addMaterial(
      classCode: _selectedClassCode!,
      title: title,
      description: desc,
      filePath: savedPath,
    );

    setState(() => _isUploading = false);

    if (result != -1) {
      _materialTitleController.clear();
      _materialDescController.clear();
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _currentIndex = 0;
      });
      await _loadAll();
      _showSnack(
        widget.isSomali ? "Casharka si guul leh ayaa loo kaydiyey!" : "Material uploaded successfully!",
        Colors.green,
      );
    } else {
      _showSnack(
        widget.isSomali ? "Waxaa dhacay khalad marka la kaydinayey!" : "Error uploading material!",
        Colors.redAccent,
      );
    }
  }

  Future<void> _handleDeleteMaterial(Map<String, dynamic> material) async {
    final confirmed = await _showConfirmDialog(
      title: widget.isSomali ? "Tirtir Casharka" : "Delete Material",
      content: widget.isSomali
          ? "Ma hubtaa inaad tirtireyso '${material['title']}'?"
          : "Are you sure you want to delete '${material['title']}'?",
    );
    if (!confirmed) return;

    final filePath = material['file_path'] as String?;
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    }

    await _dbHelper.deleteMaterial(material['id'] as int);
    await _loadAll();
    if (!mounted) return;
    _showSnack(
      widget.isSomali ? "Casharka waa la tirtiray!" : "Material deleted!",
      Colors.green,
    );
  }

  Future<void> _handleSyncAndBackup() async {
    setState(() => _isSyncing = true);
    for (final cls in _teacherClasses) {
      final code = cls['class_code'];
      if (code != null) {
        await _dbHelper.syncClassFromFirestore(code);
      }
    }
    await _loadAll();
    setState(() => _isSyncing = false);
    if (!mounted) return;
    _showSnack(
      widget.isSomali
          ? "Xogtaadii waa la xiriiriyay (Firestore Sync)!"
          : "Data synced with Firestore successfully!",
      Colors.green,
    );
  }

  void _openFile(String? filePath) {
    if (filePath == null) return;
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            isSomali: widget.isSomali,
            filePath: filePath,
            title: p.basenameWithoutExtension(filePath),
          ),
        ),
      );
    } else {
      OpenFile.open(filePath);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<bool> _showConfirmDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isSomali ? "Maya" : "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              widget.isSomali ? "Haa, Tirtir" : "Yes, Delete",
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  IconData _fileIcon(String? path) {
    if (path == null) return Icons.insert_drive_file_rounded;
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String? path) {
    if (path == null) return Colors.blueGrey;
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf': return Colors.redAccent;
      case 'doc': case 'docx': return Colors.blue;
      case 'ppt': case 'pptx': return Colors.orange;
      case 'xls': case 'xlsx': return Colors.green;
      default: return Colors.blueGrey;
    }
  }

  Widget _buildEmptyStateIllustration(
    IconData icon,
    String title,
    String subtitle,
    Color subTextColor,
    Color primaryColor,
    double iconSize,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Icon(icon, size: iconSize, color: primaryColor.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D6EFD);
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final Color cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = _isDarkMode ? Colors.grey : const Color(0xFF64748B);

    final List<Widget> pages = [
      _buildHomeTab(primaryColor, cardColor, textColor, subTextColor),
      _buildUploadTab(primaryColor, cardColor, textColor, subTextColor),
      _buildCoursesTab(primaryColor, cardColor, textColor, subTextColor),
      _buildProfileTab(primaryColor, cardColor, textColor, subTextColor),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          setState(() => _currentIndex = index);
          await _loadAll();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: subTextColor,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: widget.isSomali ? 'Hoy' : 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.upload_file_rounded), label: widget.isSomali ? 'Soo Geli' : 'Upload'),
          BottomNavigationBarItem(icon: const Icon(Icons.book_rounded), label: widget.isSomali ? 'Courses' : 'Courses'),
          BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: widget.isSomali ? 'Koontada' : 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(Color primaryColor, Color cardColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                    child: Icon(Icons.person_outline_rounded, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentDisplayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      Text(widget.isSomali ? "Macallin" : "Teacher", style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () => _showCreateClassBottomSheet(context, cardColor, textColor, subTextColor, primaryColor),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(widget.isSomali ? "Fasal" : "Class", style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(widget.isSomali ? "Guud ahaan Xogtaada" : "Overview Statistics",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard(_teacherClasses.length.toString(), widget.isSomali ? "Fasallada" : "My Classes", Icons.class_outlined, primaryColor, cardColor, textColor, subTextColor, null),
              const SizedBox(width: 15),
              // ✅ CUSUB — Stat card-kan hadda waa taaban karaa, muujiyaa liiska ardayda (magaca oo keliya)
              _buildStatCard(
                _totalStudents.toString(),
                widget.isSomali ? "Ardayda" : "Total Students",
                Icons.people_outline,
                Colors.orange,
                cardColor,
                textColor,
                subTextColor,
                () => _showAllStudentsSheet(cardColor, textColor, subTextColor, primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(widget.isSomali ? "Fasalladaada rasmiga ah" : "Your Registered Classes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 15),
          _teacherClasses.isEmpty
              ? _buildEmptyStateIllustration(
                  Icons.class_outlined,
                  widget.isSomali ? "Ma jiraan fasallo weli" : "No classes yet",
                  widget.isSomali ? "Guji 'Fasal' si aad u abuurto!" : "Tap 'Class' to create one!",
                  subTextColor,
                  primaryColor,
                  60,
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _teacherClasses.length,
                  itemBuilder: (context, index) {
                    final item = _teacherClasses[index];
                    return Card(
                      color: cardColor,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                            backgroundColor: primaryColor.withValues(alpha: 0.15),
                            child: Icon(Icons.class_rounded, color: primaryColor)),
                        title: Text(item['class_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Text('${widget.isSomali ? "Koodhka" : "Code"}: ${item['class_code']}', style: TextStyle(color: subTextColor)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.people_alt_outlined, color: primaryColor, size: 20),
                              tooltip: widget.isSomali ? "Ardayda Fasalkan" : "Students in this class",
                              onPressed: () => _showClassStudentsSheet(item['class_code'] ?? '', item['class_name'] ?? '', cardColor, textColor, subTextColor, primaryColor),
                            ),
                            IconButton(
                              icon: Icon(Icons.bar_chart_rounded, color: primaryColor, size: 20),
                              tooltip: widget.isSomali ? "Natiijooyinka Quiz-ka" : "Quiz Results",
                              onPressed: () => _showQuizResults(item['class_code'] ?? '', item['class_name'] ?? '', cardColor, textColor, subTextColor, primaryColor),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _handleDeleteClass(item['class_code'] ?? '', item['class_name'] ?? ''),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassManagementScreen(
                                isSomali: widget.isSomali,
                                classCode: item['class_code'] ?? '',
                                className: item['class_name'] ?? '',
                              ),
                            ),
                          ).then((_) => _loadAll());
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ✅ CUSUB — Liiska Ardayda ee Class Gaar Ah (magaca oo keliya, email lama tusin)
  Future<void> _showClassStudentsSheet(String classCode, String className, Color cardColor, Color textColor, Color subTextColor, Color primaryColor) async {
    final students = await _dbHelper.getStudentsInClass(classCode);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.isSomali ? "Ardayda Fasalka" : "Class Students",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        Text(className, style: TextStyle(fontSize: 13, color: subTextColor)),
                      ],
                    ),
                  ),
                  Text('${students.length} ${widget.isSomali ? "arday" : "student(s)"}',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: students.isEmpty
                  ? Center(child: _buildEmptyStateIllustration(
                      Icons.people_outline_rounded,
                      widget.isSomali ? "Wali ma jiro arday ku biiray" : "No students have joined yet",
                      widget.isSomali ? "Wadaaji koodhka fasalka si ardaydu ugu biiraan!" : "Share the class code so students can join!",
                      subTextColor,
                      primaryColor,
                      50,
                    ))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        return Card(
                          color: cardColor, elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                (s['student_name'] ?? '?').isNotEmpty ? s['student_name']![0].toUpperCase() : '?',
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            title: Text(s['student_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ CUSUB — Liiska Ardayda oo Dhan (class-yada macallinka oo dhan, magaca oo keliya)
  Future<void> _showAllStudentsSheet(Color cardColor, Color textColor, Color subTextColor, Color primaryColor) async {
    final students = await _dbHelper.getAllStudentsForTeacher(_userEmail);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isSomali ? "Dhammaan Ardayda" : "All Students",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  Text('${students.length} ${widget.isSomali ? "arday" : "student(s)"}',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: students.isEmpty
                  ? Center(child: _buildEmptyStateIllustration(
                      Icons.people_outline_rounded,
                      widget.isSomali ? "Wali ma jiro arday ku biiray" : "No students have joined yet",
                      widget.isSomali ? "Wadaaji koodhadka fasalladaada si ardaydu ugu biiraan!" : "Share your class codes so students can join!",
                      subTextColor,
                      primaryColor,
                      50,
                    ))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        return Card(
                          color: cardColor, elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                (s['student_name'] ?? '?').isNotEmpty ? s['student_name']![0].toUpperCase() : '?',
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            title: Text(s['student_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                            subtitle: Text(s['class_name'] ?? '', style: TextStyle(color: subTextColor, fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuizResults(String classCode, String className, Color cardColor, Color textColor, Color subTextColor, Color primaryColor) async {
    final results = await _dbHelper.getQuizResultsByClass(classCode);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.isSomali ? "Natiijooyinka Quiz-ka" : "Quiz Results",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        Text(className, style: TextStyle(fontSize: 13, color: subTextColor)),
                      ],
                    ),
                  ),
                  Text('${results.length} ${widget.isSomali ? "arday" : "student(s)"}',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: results.isEmpty
                  ? Center(child: _buildEmptyStateIllustration(
                      Icons.bar_chart_rounded,
                      widget.isSomali ? "Wali ma jiro arday quiz qaatay" : "No students have taken the quiz yet",
                      widget.isSomali ? "Marka ardaydu quiz-ka qaataan, natiijada halkan ayaa ku muuqan doonta!" : "Once students take the quiz, results will appear here!",
                      subTextColor,
                      primaryColor,
                      50,
                    ))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final r = results[i];
                        final score = r['score'] as int;
                        final total = r['total_questions'] as int;
                        final percentage = total > 0 ? (score / total * 100).round() : 0;
                        final isPassing = percentage >= 50;
                        return Card(
                          color: cardColor, elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: (isPassing ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                              child: Icon(isPassing ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                                  color: isPassing ? Colors.green : Colors.orange, size: 20),
                            ),
                            // ✅ Email-ka ardayga lama tusin — magaca oo keliya
                            title: Text(r['student_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$score / $total', style: TextStyle(fontWeight: FontWeight.bold, color: isPassing ? Colors.green : Colors.orange, fontSize: 15)),
                                Text('$percentage%', style: TextStyle(color: subTextColor, fontSize: 11)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab(Color primaryColor, Color cardColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.isSomali ? "Soo Geli Cashar Cusub" : "Upload New Course Material",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(widget.isSomali
                  ? "Ku dar faylal (PDF, Word, PPT, Excel) si ardaydu offline ugu akhristaan"
                  : "Add files (PDF, Word, PPT, Excel) for students to access offline",
              style: TextStyle(fontSize: 14, color: subTextColor)),
          const SizedBox(height: 25),
          if (_teacherClasses.isNotEmpty) ...[
            Text(widget.isSomali ? "Dooro Fasalka:" : "Select Class:",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClassCode,
                  isExpanded: true,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor, fontSize: 15),
                  items: _teacherClasses.map((c) {
                    return DropdownMenuItem<String>(value: c['class_code'], child: Text(c['class_name'] ?? ''));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedClassCode = val),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4))),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    widget.isSomali ? "Marka hore fasal abuur tab Home-ka ah." : "Please create a class first from the Home tab.",
                    style: const TextStyle(color: Colors.orange),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _materialTitleController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: widget.isSomali ? "Cinwaanka Casharka" : "Material Title",
              labelStyle: TextStyle(color: subTextColor),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _materialDescController,
            maxLines: 2,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: widget.isSomali ? "Faahfaahinta Casharka" : "Material Description",
              labelStyle: TextStyle(color: subTextColor),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor), borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _selectedFileName != null ? primaryColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.15),
                      width: 1.5)),
              child: Column(
                children: [
                  Icon(_fileIcon(_selectedFileName), size: 54,
                      color: _selectedFileName != null ? _fileColor(_selectedFileName) : primaryColor.withValues(alpha: 0.7)),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? (widget.isSomali ? "Dooro faylka (PDF, Word, PPT, Excel...)" : "Select file (PDF, Word, PPT, Excel...)"),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor,
                        fontStyle: _selectedFileName != null ? FontStyle.italic : FontStyle.normal),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isSomali ? "Noocyada la ogol yahay: PDF, DOC, DOCX, PPT, PPTX, XLS, XLSX, TXT" : "Allowed: PDF, DOC, DOCX, PPT, PPTX, XLS, XLSX, TXT",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor.withValues(alpha: 0.1),
                        foregroundColor: primaryColor,
                        elevation: 0,
                        side: BorderSide(color: primaryColor)),
                    onPressed: _pickFile,
                    icon: const Icon(Icons.add_to_photos_rounded),
                    label: Text(widget.isSomali ? "Dooro Fayl" : "Browse Files",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isUploading ? null : _handleUploadMaterial,
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(widget.isSomali ? "Kaydi Casharka" : "Save Material",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab(Color primaryColor, Color cardColor, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isSomali ? "Casharrada la soo geliyey" : "Uploaded Materials",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text(widget.isSomali ? "Dhammaan faylasha la kaydiyey" : "All uploaded files stored on device",
                  style: TextStyle(fontSize: 14, color: subTextColor)),
              const SizedBox(height: 6),
              Text('${_uploadedMaterials.length} ${widget.isSomali ? "cashar" : "material(s)"}',
                  style: TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _uploadedMaterials.isEmpty
              ? Center(child: _buildEmptyStateIllustration(
                  Icons.folder_open_rounded,
                  widget.isSomali ? "Ma jiraan casharro weli" : "No materials uploaded yet",
                  widget.isSomali ? "Tab 'Soo Geli' isticmaal si aad u darto!" : "Use the 'Upload' tab to add materials!",
                  subTextColor,
                  primaryColor,
                  60,
                ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _uploadedMaterials.length,
                  itemBuilder: (context, index) {
                    final mat = _uploadedMaterials[index];
                    final filePath = mat['file_path'] as String?;
                    return Card(
                      color: cardColor,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: _fileColor(filePath).withValues(alpha: 0.12),
                          child: Icon(_fileIcon(filePath), color: _fileColor(filePath)),
                        ),
                        title: Text(mat['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((mat['description'] ?? '').isNotEmpty)
                              Text(mat['description'] ?? '', style: TextStyle(color: subTextColor, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.class_outlined, size: 12, color: subTextColor),
                                const SizedBox(width: 4),
                                Text(mat['class_name'] ?? '', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (filePath != null) ...[
                              const SizedBox(height: 2),
                              Text(p.basename(filePath),
                                  style: TextStyle(color: subTextColor.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                        onTap: () => _openFile(filePath),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.quiz_outlined, color: primaryColor, size: 20),
                              tooltip: widget.isSomali ? "Arag Su'aalaha Quiz-ka" : "View Quiz Questions",
                              onPressed: () => _showQuizQuestions(mat, cardColor, textColor, subTextColor, primaryColor),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () => _handleDeleteMaterial(mat),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showQuizQuestions(Map<String, dynamic> material, Color cardColor, Color textColor, Color subTextColor, Color primaryColor) async {
    final classCode = material['class_code'] as String? ?? '';
    final questions = await _dbHelper.getQuizQuestionsByClass(classCode);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.isSomali ? "Su'aalaha Quiz-ka" : "Quiz Questions",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      Text(material['title'] ?? '', style: TextStyle(fontSize: 13, color: subTextColor)),
                    ],
                  )),
                  Text('${questions.length} ${widget.isSomali ? "su'aal" : "Q"}',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: questions.isEmpty
                  ? Center(child: _buildEmptyStateIllustration(
                      Icons.quiz_outlined,
                      widget.isSomali ? "Ma jiraan su'aalo weli" : "No quiz questions yet",
                      widget.isSomali ? "Fur fasalka si aad u darto su'aalo!" : "Open the class to add questions!",
                      subTextColor,
                      primaryColor,
                      50,
                    ))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: questions.length,
                      itemBuilder: (_, i) {
                        final q = questions[i];
                        return Card(
                          color: cardColor, elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                                    child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(q['question'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
                                ]),
                                const SizedBox(height: 10),
                                ..._buildAnswerOptions(q, textColor, subTextColor, primaryColor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerOptions(Map<String, dynamic> q, Color textColor, Color subTextColor, Color primaryColor) {
    final correctAnswer = q['correct_answer'] as String?;
    final options = <String?>[
      q['option_A'] as String?,
      q['option_B'] as String?,
      q['option_C'] as String?,
      q['option_D'] as String?,
    ].where((o) => o != null && o.isNotEmpty).toList();

    if (options.isEmpty) {
      return [Text('${widget.isSomali ? "Jawaabta" : "Answer"}: ${correctAnswer ?? "—"}', style: TextStyle(color: subTextColor, fontSize: 13))];
    }

    final labels = ['A', 'B', 'C', 'D'];
    return List.generate(options.length, (i) {
      final isCorrect = labels[i] == correctAnswer;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(
          children: [
            Text('${labels[i]}. ', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : subTextColor, fontSize: 13)),
            Expanded(child: Text(options[i]!, style: TextStyle(color: isCorrect ? Colors.green : textColor, fontSize: 13))),
            if (isCorrect) const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
          ],
        ),
      );
    });
  }

  Widget _buildProfileTab(Color primaryColor, Color cardColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: primaryColor.withValues(alpha: 0.15), child: Icon(Icons.person, size: 45, color: primaryColor)),
                  const SizedBox(height: 12),
                  Text(_currentDisplayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  Text(widget.isSomali ? "Macallin" : "Teacher", style: TextStyle(color: subTextColor)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniStat(_teacherClasses.length.toString(), widget.isSomali ? "Fasallo" : "Classes", primaryColor, textColor, subTextColor),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _buildMiniStat(_totalStudents.toString(), widget.isSomali ? "Ardayda" : "Students", Colors.orange, textColor, subTextColor),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _buildMiniStat(_uploadedMaterials.length.toString(), widget.isSomali ? "Cashar" : "Materials", Colors.green, textColor, subTextColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: _isSyncing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.sync_rounded, color: primaryColor),
              title: Text(widget.isSomali ? "Xiriiri & Keydi (Firestore Sync)" : "Sync & Backup", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isSomali ? "Ku keydi xogtaada daruuraha (Cloud)" : "Backup your offline data to server", style: TextStyle(color: subTextColor)),
              trailing: IconButton(icon: const Icon(Icons.cloud_upload_outlined), onPressed: _isSyncing ? null : _handleSyncAndBackup),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: Icon(Icons.settings_rounded, color: primaryColor),
              title: Text(widget.isSomali ? "Hagaajinta Koontada" : "Account Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isSomali ? "Beddelka magaca ama password-ka" : "Manage your name and password", style: TextStyle(color: subTextColor)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _showAccountSettingsSheet(cardColor, textColor, subTextColor, primaryColor),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: primaryColor),
              title: Text(widget.isSomali ? "Muuqaalka Abka" : "App Theme", style: TextStyle(color: textColor)),
              subtitle: Text(_isDarkMode
                  ? (widget.isSomali ? "Madow" : "Dark Mode")
                  : (widget.isSomali ? "Caddaan" : "Light Mode"),
                  style: TextStyle(color: subTextColor)),
              trailing: Switch(value: _isDarkMode, onChanged: (value) => setState(() => _isDarkMode = value)),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: Text(widget.isSomali ? "Ka Bax" : "Log Out", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () async {
                await _dbHelper.clearUserSession();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPortalScreen(isSomali: widget.isSomali)),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountSettingsSheet(Color cardColor, Color textColor, Color subTextColor, Color primaryColor) {
    final nameController = TextEditingController(text: _currentDisplayName);
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isSavingName = false;
    bool isSavingPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 24, left: 24, right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isSomali ? "Hagaajinta Koontada" : "Account Settings",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    widget.isSomali ? "Beddel Magaca" : "Change Name",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: widget.isSomali ? "Magaca Cusub" : "New Name",
                      labelStyle: TextStyle(color: subTextColor),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSavingName
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty) return;
                              setSheetState(() => isSavingName = true);
                              final success = await _dbHelper.updateUserProfile(
                                email: _userEmail,
                                newName: nameController.text.trim(),
                              );
                              setSheetState(() => isSavingName = false);
                              if (!mounted) return;
                              if (success) {
                                setState(() => _currentDisplayName = nameController.text.trim());
                                _showSnack(
                                  widget.isSomali ? "Magaca waa la cusboonaysiiyey!" : "Name updated successfully!",
                                  Colors.green,
                                );
                              } else {
                                _showSnack(
                                  widget.isSomali ? "Khalad ayaa dhacay!" : "Something went wrong!",
                                  Colors.redAccent,
                                );
                              }
                            },
                      child: isSavingName
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.isSomali ? "Kaydi Magaca" : "Save Name",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),

                  Text(
                    widget.isSomali ? "Beddel Password-ka" : "Change Password",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentPassController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: widget.isSomali ? "Password-ka Hadda" : "Current Password",
                      labelStyle: TextStyle(color: subTextColor),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: widget.isSomali ? "Password Cusub" : "New Password",
                      labelStyle: TextStyle(color: subTextColor),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPassController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: widget.isSomali ? "Xaqiiji Password Cusub" : "Confirm New Password",
                      labelStyle: TextStyle(color: subTextColor),
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSavingPassword
                          ? null
                          : () async {
                              if (currentPassController.text.isEmpty ||
                                  newPassController.text.isEmpty ||
                                  confirmPassController.text.isEmpty) {
                                _showSnack(
                                  widget.isSomali ? "Fadlan buuxi dhammaan goobaha!" : "Please fill all fields!",
                                  Colors.orange,
                                );
                                return;
                              }
                              if (newPassController.text.length < 6) {
                                _showSnack(
                                  widget.isSomali
                                      ? "Password-ku ma ka yaraan karo 6 xaraf!"
                                      : "Password must be at least 6 characters!",
                                  Colors.orange,
                                );
                                return;
                              }
                              if (newPassController.text != confirmPassController.text) {
                                _showSnack(
                                  widget.isSomali
                                      ? "Password-yadu ma is waafaqsana!"
                                      : "Passwords do not match!",
                                  Colors.orange,
                                );
                                return;
                              }

                              setSheetState(() => isSavingPassword = true);
                              final success = await _dbHelper.updatePassword(
                                email: _userEmail,
                                currentPassword: currentPassController.text,
                                newPassword: newPassController.text,
                              );
                              setSheetState(() => isSavingPassword = false);
                              if (!mounted) return;

                              if (success) {
                                currentPassController.clear();
                                newPassController.clear();
                                confirmPassController.clear();
                                _showSnack(
                                  widget.isSomali ? "Password-ka waa la beddelay!" : "Password changed successfully!",
                                  Colors.green,
                                );
                              } else {
                                _showSnack(
                                  widget.isSomali
                                      ? "Password-ka hadda waa khalad!"
                                      : "Current password is incorrect!",
                                  Colors.redAccent,
                                );
                              }
                            },
                      child: isSavingPassword
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.isSomali ? "Beddel Password-ka" : "Update Password",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateClassBottomSheet(BuildContext context, Color cardColor, Color textColor, Color subTextColor, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.isSomali ? "Abuur Fasal Cusub" : "Create New Class",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text(
                widget.isSomali
                    ? "Fasalku wuxuu si toos ah ugu heli doonaa ardayda internet ku xidhan"
                    : "Class will automatically be available to students with internet access",
                style: TextStyle(fontSize: 12, color: subTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _classNameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: widget.isSomali ? "Magaca Fasalka" : "Class Name",
                  labelStyle: TextStyle(color: subTextColor),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 50)),
                onPressed: _isCreatingClass
                    ? null
                    : () async {
                        setSheetState(() {});
                        await _handleCreateClass();
                      },
                child: _isCreatingClass
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.isSomali ? "Abuur" : "Create Now",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ SAXITAAN — onTap parameter cusub oo ikhtiyaari ah (optional, nullable)
  Widget _buildStatCard(String value, String title, IconData icon, Color color, Color cardColor, Color textColor, Color subTextColor, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded, color: subTextColor.withValues(alpha: 0.4), size: 14),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 13, color: subTextColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
      ],
    );
  }
}