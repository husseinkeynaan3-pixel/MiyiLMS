import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';
import 'login_portal_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quiz_taking_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final bool isSomali;
  final String username;
  final String displayName;
  final bool isNewUser;

  const StudentDashboardScreen({
    super.key,
    required this.isSomali,
    required this.username,
    required this.displayName,
    required this.isNewUser,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  bool _isDarkMode = false;
  bool _isSyncing = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _classCodeController = TextEditingController();

  List<Map<String, String>> _myClasses = [];
  List<Map<String, dynamic>> _allMaterials = [];
  List<Map<String, dynamic>> _recentMaterials = [];
  Map<String, bool> _quizTakenStatus = {};

  late String _currentDisplayName;

  // ══════════════════════════════════════════
  // BLUETOOTH CLASSIC STATE
  // ══════════════════════════════════════════
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  String _btStatus = 'idle';
  final List<BluetoothDevice> _discoveredDevices = [];
  BluetoothConnection? _connection;
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  int _currentItemIndex = 0;
  int _totalItemsToTransfer = 0;
  String _currentTransferName = '';
  int _currentBytesTransferred = 0;
  int _currentTotalBytes = 0;
  bool _isTransferActive = false;

  final List<int> _receiveBuffer = [];
  Map<String, dynamic>? _currentReceivingHeader;
  IOSink? _currentWriteSink;
  String? _currentTempFilePath;
  String? _currentFinalFilePath;
  final List<int> _jsonBodyBuffer = [];

  static const String _headerEndMarker = '\n###HEADER_END###\n';

  String get _userEmail => widget.username;

  @override
  void initState() {
    super.initState();
    _currentDisplayName = widget.displayName;
    _loadAll();
  }

  @override
  void dispose() {
    _classCodeController.dispose();
    _stopAll();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadClasses();
    await _loadMaterials();
    await _loadQuizStatus();
  }

  Future<void> _loadClasses() async {
    final classes = await _dbHelper.getStudentClasses(_userEmail);
    if (!mounted) return;
    setState(() => _myClasses = classes);
  }

  Future<void> _loadMaterials() async {
    List<Map<String, dynamic>> all = [];
    for (final cls in _myClasses) {
      final code = cls['class_code'];
      if (code != null) {
        final mats = await _dbHelper.getMaterialsByClass(code);
        for (final m in mats) {
          all.add({...m, 'class_name': cls['class_name'] ?? code});
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _allMaterials = all;
      _recentMaterials = all.take(3).toList();
    });
  }

  // ✅ CUSUB — Hubi haddii ardaygu quiz-ka qaatay class kasta
  Future<void> _loadQuizStatus() async {
    Map<String, bool> status = {};
    for (final cls in _myClasses) {
      final code = cls['class_code'];
      if (code != null) {
        final taken = await _dbHelper.hasStudentTakenQuiz(code, _userEmail);
        status[code] = taken;
      }
    }
    if (!mounted) return;
    setState(() => _quizTakenStatus = status);
  }

  Future<void> _handleJoinClass() async {
    final code = _classCodeController.text.trim();
    if (code.isEmpty) return;

    final success = await _dbHelper.joinClassWithCode(code, _userEmail);
    _classCodeController.clear();
    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      await _loadAll();
      _showSnack(widget.isSomali ? "Si guul leh ayaad fasalka ugu biirtay!" : "Successfully joined the class!", Colors.green);
    } else {
      _showSnack(
        widget.isSomali
            ? "Koodhka fasalka waa khalad ama internet ma jiro!"
            : "Invalid class code, or no internet connection!",
        Colors.redAccent,
      );
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    for (final cls in _myClasses) {
      final code = cls['class_code'];
      if (code != null) {
        await _dbHelper.syncClassFromFirestore(code);
      }
    }
    await _loadAll();
    setState(() => _isSyncing = false);
    if (!mounted) return;
    _showSnack(
      widget.isSomali ? "Xogtaadii waa la cusbooneysiiyey (Firestore)!" : "Data synced with Firestore!",
      Colors.green,
    );
  }

  // ✅ CUSUB — Fur Quiz-Taking Screen-ka
  Future<void> _openQuiz(String classCode, String className) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTakingScreen(
          isSomali: widget.isSomali,
          classCode: classCode,
          className: className,
          studentEmail: _userEmail,
          studentName: _currentDisplayName,
        ),
      ),
    );
    if (result == true) {
      await _loadQuizStatus();
    }
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

  // ══════════════════════════════════════════
  // BLUETOOTH PERMISSIONS
  // ══════════════════════════════════════════

  Future<bool> _requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<bool> _ensureBluetoothOn() async {
    bool? isEnabled = await _bluetooth.isEnabled;
    if (isEnabled != true) {
      try {
        await _bluetooth.requestEnable();
        isEnabled = await _bluetooth.isEnabled;
      } catch (_) {
        return false;
      }
    }
    return isEnabled == true;
  }

  // ══════════════════════════════════════════
  // ADVERTISING
  // ══════════════════════════════════════════

  Future<void> _startAdvertising() async {
    final granted = await _requestBluetoothPermissions();
    if (!granted) {
      _showSnack(
        widget.isSomali ? "Fadlan ogolow dhammaan ogolaanshaha Bluetooth-ka!" : "Please grant all Bluetooth permissions!",
        Colors.redAccent,
      );
      return;
    }

    final btOn = await _ensureBluetoothOn();
    if (!btOn) {
      _showSnack(
        widget.isSomali ? "Fadlan shid Bluetooth-ka!" : "Please turn on Bluetooth!",
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _btStatus = 'advertising';
      _isAdvertising = true;
    });

    try {
      await _bluetooth.requestDiscoverable(120);
      _showSnack(
        widget.isSomali
            ? "Taleefankaan waa la heli karaa. Sug inta kale ay ku xirmaan!"
            : "This device is discoverable. Waiting for the other device to connect!",
        Colors.blue,
      );
    } catch (e) {
      setState(() {
        _btStatus = 'idle';
        _isAdvertising = false;
      });
      _showSnack(widget.isSomali ? "Khalad: $e" : "Error: $e", Colors.redAccent);
    }
  }

  // ══════════════════════════════════════════
  // DISCOVERY
  // ══════════════════════════════════════════

  Future<void> _startDiscovering() async {
    final granted = await _requestBluetoothPermissions();
    if (!granted) {
      _showSnack(
        widget.isSomali ? "Fadlan ogolow dhammaan ogolaanshaha Bluetooth-ka!" : "Please grant all Bluetooth permissions!",
        Colors.redAccent,
      );
      return;
    }

    final btOn = await _ensureBluetoothOn();
    if (!btOn) {
      _showSnack(
        widget.isSomali ? "Fadlan shid Bluetooth-ka!" : "Please turn on Bluetooth!",
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _btStatus = 'discovering';
      _isDiscovering = true;
      _discoveredDevices.clear();
    });

    try {
      final bonded = await _bluetooth.getBondedDevices();
      if (mounted) {
        setState(() => _discoveredDevices.addAll(bonded));
      }
    } catch (_) {}

    _discoverySubscription = _bluetooth.startDiscovery().listen((result) {
      final exists = _discoveredDevices.any((d) => d.address == result.device.address);
      if (!exists && result.device.name != null) {
        setState(() => _discoveredDevices.add(result.device));
      }
    }, onDone: () {
      if (mounted) setState(() => _isDiscovering = false);
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await _discoverySubscription?.cancel();
    setState(() => _btStatus = 'connecting');

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      setState(() {
        _btStatus = 'connected';
        _isDiscovering = false;
      });
      _showSnack(
        widget.isSomali ? "Waa la xidhay: ${device.name}" : "Connected to: ${device.name}",
        Colors.green,
      );
      _listenToConnection();
      await _sendAllData();
    } catch (e) {
      setState(() => _btStatus = 'idle');
      _showSnack(
        widget.isSomali ? "Xiriirka waa fashilantay: $e" : "Connection failed: $e",
        Colors.redAccent,
      );
    }
  }

  void _listenToConnection() {
    _connection?.input?.listen((Uint8List data) {
      _handleIncomingBytes(data);
    }).onDone(() {
      if (!mounted) return;
      setState(() {
        _btStatus = 'idle';
        _connection = null;
      });
      _showSnack(
        widget.isSomali ? "Xiriirka waa la jaray!" : "Connection closed!",
        Colors.orange,
      );
    });
  }

  // ══════════════════════════════════════════
  // SEND
  // ══════════════════════════════════════════

  Future<void> _sendAllData() async {
    if (_connection == null) return;

    final List<Map<String, dynamic>> queue = [];

    for (final cls in _myClasses) {
      queue.add({'type': 'class', 'class_code': cls['class_code'] ?? '', 'class_name': cls['class_name'] ?? ''});
    }
    for (final cls in _myClasses) {
      final code = cls['class_code'];
      if (code != null) {
        final quizzes = await _dbHelper.getQuizQuestionsByClass(code);
        for (final q in quizzes) {
          queue.add({
            'type': 'quiz',
            'class_code': code,
            'question': q['question'] ?? '',
            'option_A': q['option_A'] ?? '',
            'option_B': q['option_B'] ?? '',
            'option_C': q['option_C'] ?? '',
            'option_D': q['option_D'] ?? '',
            'correct_answer': q['correct_answer'] ?? '',
          });
        }
      }
    }
    for (final mat in _allMaterials) {
      final filePath = mat['file_path'] as String?;
      if (filePath != null && await File(filePath).exists()) {
        queue.add({
          'type': 'material_file',
          'class_code': mat['class_code'] ?? '',
          'class_name': mat['class_name'] ?? '',
          'title': mat['title'] ?? '',
          'description': mat['description'] ?? '',
          'file_path': filePath,
        });
      }
    }

    setState(() {
      _totalItemsToTransfer = queue.length;
      _currentItemIndex = 0;
      _isTransferActive = true;
      _btStatus = 'sending';
    });

    for (int i = 0; i < queue.length; i++) {
      setState(() => _currentItemIndex = i + 1);
      final item = queue[i];
      if (item['type'] == 'material_file') {
        await _sendFileItem(item);
      } else {
        await _sendJsonItem(item);
      }
    }

    setState(() {
      _isTransferActive = false;
      _btStatus = 'connected';
    });
    _showSnack(
      widget.isSomali ? "Dhammaan xogta waa la diray!" : "All data sent successfully!",
      Colors.green,
    );
  }

  Future<void> _sendJsonItem(Map<String, dynamic> item) async {
    final bodyBytes = utf8.encode(jsonEncode(item));
    final header = {
      'kind': 'json',
      'size': bodyBytes.length,
    };
    setState(() {
      _currentTransferName = item['type'] == 'quiz'
          ? (widget.isSomali ? "Su'aal Quiz" : "Quiz Question")
          : (widget.isSomali ? "Fasalka" : "Class Info");
      _currentTotalBytes = bodyBytes.length;
      _currentBytesTransferred = 0;
    });

    _connection!.output.add(utf8.encode(jsonEncode(header) + _headerEndMarker));
    await _connection!.output.allSent;
    _connection!.output.add(Uint8List.fromList(bodyBytes));
    await _connection!.output.allSent;

    setState(() => _currentBytesTransferred = bodyBytes.length);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> _sendFileItem(Map<String, dynamic> item) async {
    final filePath = item['file_path'] as String;
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = p.basename(filePath);

    final header = {
      'kind': 'file',
      'size': fileSize,
      'file_name': fileName,
      'class_code': item['class_code'],
      'class_name': item['class_name'],
      'title': item['title'],
      'description': item['description'],
    };

    setState(() {
      _currentTransferName = item['title'] ?? fileName;
      _currentTotalBytes = fileSize;
      _currentBytesTransferred = 0;
    });

    _connection!.output.add(utf8.encode(jsonEncode(header) + _headerEndMarker));
    await _connection!.output.allSent;

    final stream = file.openRead();
    int sent = 0;
    await for (final chunk in stream) {
      _connection!.output.add(Uint8List.fromList(chunk));
      await _connection!.output.allSent;
      sent += chunk.length;
      setState(() => _currentBytesTransferred = sent);
    }
  }

  // ══════════════════════════════════════════
  // RECEIVE
  // ══════════════════════════════════════════

  void _handleIncomingBytes(Uint8List data) {
    _receiveBuffer.addAll(data);

    if (_currentReceivingHeader == null) {
      _tryParseHeader();
    } else {
      _consumeBodyBytes();
    }
  }

  void _tryParseHeader() {
    final markerBytes = utf8.encode(_headerEndMarker);
    final bufferList = _receiveBuffer;

    int markerIndex = -1;
    for (int i = 0; i <= bufferList.length - markerBytes.length; i++) {
      bool match = true;
      for (int j = 0; j < markerBytes.length; j++) {
        if (bufferList[i + j] != markerBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        markerIndex = i;
        break;
      }
    }

    if (markerIndex == -1) return;

    final headerBytes = bufferList.sublist(0, markerIndex);
    final remaining = bufferList.sublist(markerIndex + markerBytes.length);
    _receiveBuffer.clear();
    _receiveBuffer.addAll(remaining);

    final headerJson = jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    _currentReceivingHeader = headerJson;

    if (headerJson['kind'] == 'file') {
      _prepareFileReceive(headerJson);
    } else {
      setState(() {
        _currentTransferName = widget.isSomali ? "Xog la heli" : "Receiving data";
        _currentTotalBytes = headerJson['size'] as int;
        _currentBytesTransferred = 0;
        _btStatus = 'receiving';
      });
    }

    if (_receiveBuffer.isNotEmpty) {
      _consumeBodyBytes();
    }
  }

  Future<void> _prepareFileReceive(Map<String, dynamic> header) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(appDir.path, 'materials'));
    if (!await destDir.exists()) await destDir.create(recursive: true);

    final fileName = header['file_name'] as String;
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final finalPath = p.join(destDir.path, uniqueName);
    final tempPath = '$finalPath.tmp';

    _currentTempFilePath = tempPath;
    _currentFinalFilePath = finalPath;
    _currentWriteSink = File(tempPath).openWrite();

    setState(() {
      _currentTransferName = header['title'] ?? fileName;
      _currentTotalBytes = header['size'] as int;
      _currentBytesTransferred = 0;
      _btStatus = 'receiving';
    });
  }

  void _consumeBodyBytes() {
    final header = _currentReceivingHeader;
    if (header == null) return;

    final expectedSize = header['size'] as int;
    final available = _receiveBuffer.length;
    final remainingNeeded = expectedSize - _currentBytesTransferred;
    final toConsume = available < remainingNeeded ? available : remainingNeeded;

    if (toConsume <= 0) return;

    final chunk = _receiveBuffer.sublist(0, toConsume);
    final remaining = _receiveBuffer.sublist(toConsume);
    _receiveBuffer.clear();
    _receiveBuffer.addAll(remaining);

    if (header['kind'] == 'file') {
      _currentWriteSink?.add(chunk);
    } else {
      _jsonBodyBuffer.addAll(chunk);
    }

    setState(() => _currentBytesTransferred += toConsume);

    if (_currentBytesTransferred >= expectedSize) {
      _finishCurrentItem(header);
    }

    if (_receiveBuffer.isNotEmpty) {
      _tryParseHeader();
    }
  }

  Future<void> _finishCurrentItem(Map<String, dynamic> header) async {
    if (header['kind'] == 'file') {
      await _currentWriteSink?.flush();
      await _currentWriteSink?.close();
      _currentWriteSink = null;

      final tempFile = File(_currentTempFilePath!);
      await tempFile.rename(_currentFinalFilePath!);

      await _dbHelper.addMaterial(
        classCode: header['class_code'] ?? '',
        title: header['title'] ?? p.basenameWithoutExtension(_currentFinalFilePath!),
        description: header['description'] ?? '',
        filePath: _currentFinalFilePath!,
      );

      _currentTempFilePath = null;
      _currentFinalFilePath = null;
    } else {
      final bodyStr = utf8.decode(_jsonBodyBuffer);
      _jsonBodyBuffer.clear();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      if (body['type'] == 'class') {
        await _dbHelper.joinClassWithCode(body['class_code'] as String, _userEmail);
      } else if (body['type'] == 'quiz') {
        await _dbHelper.addQuizQuestion(
          classCode: body['class_code'] as String,
          quizTitle: 'Shared Quiz',
          sectionName: 'Bluetooth Share',
          question: body['question'] as String,
          optionA: body['option_A'] as String,
          optionB: body['option_B'] as String,
          optionC: body['option_C'] as String,
          optionD: body['option_D'] as String,
          correctAnswer: body['correct_answer'] as String,
        );
      }
    }

    _currentReceivingHeader = null;
    await _loadAll();
    if (mounted) setState(() => _btStatus = 'connected');
  }

  // ══════════════════════════════════════════
  // STOP ALL
  // ══════════════════════════════════════════

  Future<void> _stopAll() async {
    await _discoverySubscription?.cancel();
    await _connection?.close();
    await _currentWriteSink?.close();
    try {
      await _bluetooth.cancelDiscovery();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _btStatus = 'idle';
      _isAdvertising = false;
      _isDiscovering = false;
      _connection = null;
      _discoveredDevices.clear();
      _isTransferActive = false;
    });
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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

  String _btStatusText() {
    switch (_btStatus) {
      case 'discovering': return widget.isSomali ? 'Raadinta...' : 'Discovering...';
      case 'advertising': return widget.isSomali ? 'La heli karaa' : 'Discoverable';
      case 'connecting': return widget.isSomali ? 'Xidhaya...' : 'Connecting...';
      case 'connected': return widget.isSomali ? 'Waa la xidhay' : 'Connected';
      case 'sending': return widget.isSomali ? 'Diraya...' : 'Sending...';
      case 'receiving': return widget.isSomali ? 'Helaya...' : 'Receiving...';
      default: return widget.isSomali ? 'Diyaar' : 'Ready';
    }
  }

  Color _btStatusColor() {
    switch (_btStatus) {
      case 'discovering': return Colors.orange;
      case 'advertising': return Colors.blue;
      case 'connecting': return Colors.amber;
      case 'connected': return Colors.green;
      case 'sending': return Colors.purple;
      case 'receiving': return Colors.teal;
      default: return Colors.grey;
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withValues(alpha: 0.08)),
            child: Center(child: Icon(icon, size: iconSize, color: primaryColor.withValues(alpha: 0.6))),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subTextColor), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 13, color: subTextColor.withValues(alpha: 0.7), fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    final Color bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final Color cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = _isDarkMode ? Colors.grey : const Color(0xFF64748B);

    final List<Widget> pages = [
      _buildHomeTab(primaryBlue, cardColor, textColor, subTextColor),
      _buildCoursesTab(primaryBlue, cardColor, textColor, subTextColor),
      _buildDownloadsTab(primaryBlue, cardColor, textColor, subTextColor),
      _buildProfileTab(primaryBlue, cardColor, textColor, subTextColor),
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
        selectedItemColor: primaryBlue,
        unselectedItemColor: subTextColor,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_filled), label: widget.isSomali ? 'Hoy' : 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.book_rounded), label: widget.isSomali ? 'Casharrada' : 'Courses'),
          BottomNavigationBarItem(icon: const Icon(Icons.download_for_offline_rounded), label: widget.isSomali ? 'La soo degay' : 'Downloads'),
          BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: widget.isSomali ? 'Koontada' : 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(Color primaryBlue, Color cardColor, Color textColor, Color subTextColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: primaryBlue.withValues(alpha: 0.12), child: Icon(Icons.person_rounded, color: primaryBlue, size: 28)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentDisplayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  Text(widget.isSomali ? "Arday" : "Student", style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                onPressed: () => _showJoinClassSheet(cardColor, textColor, subTextColor, primaryBlue),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: Text(widget.isSomali ? "Biir" : "Join", style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.15))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.isSomali ? "Xogta Ardaynimadaada" : "Your Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    Icon(Icons.bar_chart_rounded, color: primaryBlue, size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(_myClasses.length.toString(), widget.isSomali ? "Fasallada" : "Classes", primaryBlue, textColor, subTextColor),
                    Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildStatColumn(_allMaterials.length.toString(), widget.isSomali ? "Casharrada" : "Materials", Colors.orange, textColor, subTextColor),
                    Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildStatColumn(
                      _quizTakenStatus.values.where((v) => v).length.toString(),
                      widget.isSomali ? "Quiz" : "Quizzes",
                      Colors.green,
                      textColor,
                      subTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isSomali ? "Fasalladayda" : "My Classes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              if (_myClasses.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Text(widget.isSomali ? "Arag dhan" : "See all", style: TextStyle(fontSize: 14, color: primaryBlue, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _myClasses.isEmpty
              ? _buildEmptyStateIllustration(
                  Icons.class_outlined,
                  widget.isSomali ? "Wali ma biirto fasal" : "No classes yet",
                  widget.isSomali ? "Kabraha 'Biir' taab si aad u gasho!" : "Tap 'Join' to enroll in a class!",
                  subTextColor,
                  primaryBlue,
                  60,
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myClasses.length,
                  itemBuilder: (context, index) {
                    final cls = _myClasses[index];
                    final code = cls['class_code'] ?? '';
                    final taken = _quizTakenStatus[code] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.15))),
                      child: Row(
                        children: [
                          Icon(Icons.class_rounded, color: primaryBlue, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cls['class_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                                Text(code, style: TextStyle(color: subTextColor, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: taken ? Colors.grey.withValues(alpha: 0.15) : primaryBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _openQuiz(code, cls['class_name'] ?? ''),
                            icon: Icon(taken ? Icons.check_circle_rounded : Icons.quiz_rounded, color: taken ? Colors.green : Colors.white, size: 16),
                            label: Text(
                              taken
                                  ? (widget.isSomali ? "La dhammeeyay" : "Done")
                                  : (widget.isSomali ? "Qaad Quiz" : "Take Quiz"),
                              style: TextStyle(color: taken ? Colors.green : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 25),
          Text(widget.isSomali ? "Dhowaan la soo geliyey" : "Recently Added", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          _recentMaterials.isEmpty
              ? _buildEmptyStateIllustration(
                  Icons.cloud_sync_rounded,
                  widget.isSomali ? "Ma jiraan casharro diyaar ah" : "No materials available yet",
                  widget.isSomali ? "Sug macallinka inuu soo upload gareeyo!" : "Waiting for teacher to upload!",
                  subTextColor,
                  primaryBlue,
                  50,
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentMaterials.length,
                  itemBuilder: (context, index) => _buildMaterialCard(_recentMaterials[index], cardColor, textColor, subTextColor, primaryBlue),
                ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab(Color primaryBlue, Color cardColor, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isSomali ? "Casharradayda" : "My Course Materials", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text(widget.isSomali ? "Dhammaan faylasha macallinkaagu soo geliyey" : "All files uploaded by your teachers", style: TextStyle(fontSize: 14, color: subTextColor)),
              const SizedBox(height: 6),
              Text('${_allMaterials.length} ${widget.isSomali ? "cashar" : "material(s)"}', style: TextStyle(fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _allMaterials.isEmpty
              ? Center(child: _buildEmptyStateIllustration(
                  Icons.folder_open_rounded,
                  widget.isSomali ? "Ma jiraan casharro weli" : "No materials yet",
                  widget.isSomali ? "Biir fasal si aad u hesho!" : "Join a class to get started!",
                  subTextColor,
                  primaryBlue,
                  60,
                ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _allMaterials.length,
                  itemBuilder: (context, index) => _buildMaterialCard(_allMaterials[index], cardColor, textColor, subTextColor, primaryBlue),
                ),
        ),
      ],
    );
  }

  Widget _buildDownloadsTab(Color primaryBlue, Color cardColor, Color textColor, Color subTextColor) {
    final List<Map<String, dynamic>> downloaded = _allMaterials.where((m) {
      final path = m['file_path'] as String?;
      if (path == null) return false;
      return File(path).existsSync();
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isSomali ? "Faylasha Device-ka" : "Files on Device", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text(widget.isSomali ? "Faylasha offline-ka ku kaydsan mishiinahaaga" : "Files stored offline on your device", style: TextStyle(fontSize: 14, color: subTextColor)),
              const SizedBox(height: 6),
              Text('${downloaded.length} ${widget.isSomali ? "fayl" : "file(s)"}', style: TextStyle(fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: downloaded.isEmpty
              ? Center(child: _buildEmptyStateIllustration(
                  Icons.download_for_offline_rounded,
                  widget.isSomali ? "Ma jiraan faylal offline ah" : "No offline files found",
                  widget.isSomali ? "Casharrada biir si aad u hesho!" : "Join a class to access materials!",
                  subTextColor,
                  primaryBlue,
                  60,
                ))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: downloaded.length,
                  itemBuilder: (context, index) {
                    final mat = downloaded[index];
                    final filePath = mat['file_path'] as String?;
                    return Card(
                      color: cardColor, elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(backgroundColor: _fileColor(filePath).withValues(alpha: 0.12), child: Icon(_fileIcon(filePath), color: _fileColor(filePath))),
                        title: Text(mat['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mat['class_name'] ?? '', style: TextStyle(color: subTextColor, fontSize: 12)),
                            if (filePath != null)
                              Text(p.basename(filePath), style: TextStyle(color: subTextColor.withValues(alpha: 0.6), fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        onTap: () => _openFile(filePath),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 14),
                              SizedBox(width: 4),
                              Text("Offline", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
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

  Widget _buildProfileTab(Color primaryBlue, Color cardColor, Color textColor, Color subTextColor) {
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
                  CircleAvatar(radius: 40, backgroundColor: primaryBlue.withValues(alpha: 0.12), child: Icon(Icons.person, size: 45, color: primaryBlue)),
                  const SizedBox(height: 12),
                  Text(_currentDisplayName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  Text(widget.isSomali ? "Arday" : "Student", style: TextStyle(color: subTextColor)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn(_myClasses.length.toString(), widget.isSomali ? "Fasallo" : "Classes", primaryBlue, textColor, subTextColor),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 20)),
                      _buildStatColumn(_allMaterials.length.toString(), widget.isSomali ? "Cashar" : "Materials", Colors.orange, textColor, subTextColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bluetooth_rounded, color: primaryBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(widget.isSomali ? "Wadaajinta Offline" : "Offline Share",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _btStatusColor().withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: _btStatusColor(), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(_btStatusText(), style: TextStyle(color: _btStatusColor(), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isSomali
                      ? "Casharrada (faylasha dhabta ah) iyo quiz-yada la wadaaji ardayda kale via Bluetooth (backup haddii internet la'aan)"
                      : "Share materials (actual files) and quizzes with other students via Bluetooth (backup if no internet)",
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
                const SizedBox(height: 16),

                if (_isTransferActive || _btStatus == 'receiving') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _currentTransferName.isEmpty
                                    ? (widget.isSomali ? "Diyaarinta..." : "Preparing...")
                                    : _currentTransferName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_totalItemsToTransfer > 0)
                              Text(
                                '$_currentItemIndex / $_totalItemsToTransfer',
                                style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _currentTotalBytes > 0 ? _currentBytesTransferred / _currentTotalBytes : 0,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            color: primaryBlue,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentTotalBytes > 0
                              ? '${(_currentBytesTransferred / 1024).toStringAsFixed(1)} KB / ${(_currentTotalBytes / 1024).toStringAsFixed(1)} KB (${((_currentBytesTransferred / _currentTotalBytes) * 100).toStringAsFixed(0)}%)'
                              : '',
                          style: TextStyle(fontSize: 11, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_discoveredDevices.isNotEmpty) ...[
                  Text(widget.isSomali ? "Ardayda la helay:" : "Students found:",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 8),
                  ..._discoveredDevices.map((device) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryBlue.withValues(alpha: 0.2))),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(device.name ?? device.address, style: TextStyle(color: textColor, fontWeight: FontWeight.w500))),
                        TextButton(
                          onPressed: () => _connectToDevice(device),
                          child: Text(widget.isSomali ? "Xiddo" : "Connect",
                              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _isAdvertising ? Colors.grey : primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () async {
                          if (_isAdvertising) { await _stopAll(); } else { await _startAdvertising(); }
                        },
                        icon: Icon(_isAdvertising ? Icons.stop_rounded : Icons.visibility_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isAdvertising ? (widget.isSomali ? "Jooji" : "Stop") : (widget.isSomali ? "La heli" : "Be Visible"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _isDiscovering ? Colors.grey : Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () async {
                          if (_isDiscovering) { await _stopAll(); } else { await _startDiscovering(); }
                        },
                        icon: Icon(_isDiscovering ? Icons.stop_rounded : Icons.search_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isDiscovering ? (widget.isSomali ? "Jooji" : "Stop") : (widget.isSomali ? "Raadi" : "Search"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: _isSyncing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.sync_rounded, color: primaryBlue),
              title: Text(widget.isSomali ? "Xiriiri & Cusboonaysii (Firestore)" : "Sync & Refresh (Firestore)", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isSomali ? "Hel casharrada cusub ee macallinkaaga (internet u baahan)" : "Get latest materials from your teachers (requires internet)", style: TextStyle(color: subTextColor)),
              trailing: IconButton(icon: const Icon(Icons.cloud_sync_outlined), onPressed: _isSyncing ? null : _handleSync),
            ),
          ),
          const SizedBox(height: 10),

          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: Icon(Icons.group_add_rounded, color: primaryBlue),
              title: Text(widget.isSomali ? "Ku Biir Fasal" : "Join a Class", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isSomali ? "Geli koodhka fasalka si aad u gasho" : "Enter class code to enroll", style: TextStyle(color: subTextColor)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _showJoinClassSheet(cardColor, textColor, subTextColor, primaryBlue),
            ),
          ),
          const SizedBox(height: 10),

          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: Icon(Icons.settings_rounded, color: primaryBlue),
              title: Text(widget.isSomali ? "Hagaajinta Koontada" : "Account Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(widget.isSomali ? "Beddelka magaca ama password-ka" : "Manage your name and password", style: TextStyle(color: subTextColor)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _showAccountSettingsSheet(cardColor, textColor, subTextColor, primaryBlue),
            ),
          ),
          const SizedBox(height: 10),

          Card(
            color: cardColor, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            child: ListTile(
              leading: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: primaryBlue),
              title: Text(widget.isSomali ? "Muuqaalka Abka" : "App Theme", style: TextStyle(color: textColor)),
              subtitle: Text(_isDarkMode ? (widget.isSomali ? "Madow" : "Dark Mode") : (widget.isSomali ? "Caddaan" : "Light Mode"), style: TextStyle(color: subTextColor)),
              trailing: Switch(value: _isDarkMode, onChanged: (val) => setState(() => _isDarkMode = val)),
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
                await _stopAll();
                await _dbHelper.clearUserSession();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPortalScreen(isSomali: widget.isSomali)),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountSettingsSheet(Color cardColor, Color textColor, Color subTextColor, Color primaryBlue) {
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryBlue),
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
                        backgroundColor: primaryBlue,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryBlue),
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

  void _showJoinClassSheet(Color cardColor, Color textColor, Color subTextColor, Color primaryBlue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.isSomali ? "Ku Biir Fasal Cusub" : "Join a New Class",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 6),
            Text(
              widget.isSomali
                  ? "Weydi macallinka koodhka fasalka (internet u baahan)"
                  : "Ask your teacher for the class code (requires internet)",
              style: TextStyle(fontSize: 13, color: subTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _classCodeController,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 3),
              decoration: InputDecoration(
                labelText: widget.isSomali ? "Koodhka Fasalka" : "Class Code",
                labelStyle: TextStyle(color: subTextColor),
                hintText: "e.g. ABC123",
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5), letterSpacing: 1),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                prefixIcon: Icon(Icons.vpn_key_rounded, color: primaryBlue),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, minimumSize: const Size(double.infinity, 50)),
              onPressed: _handleJoinClass,
              child: Text(widget.isSomali ? "Ku Biir Fasalka" : "Join Class",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> mat, Color cardColor, Color textColor, Color subTextColor, Color primaryBlue) {
    final filePath = mat['file_path'] as String?;
    final fileExists = filePath != null && File(filePath).existsSync();
    return Card(
      color: cardColor, elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(backgroundColor: _fileColor(filePath).withValues(alpha: 0.12), child: Icon(_fileIcon(filePath), color: _fileColor(filePath))),
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: fileExists ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    fileExists ? "Offline" : (widget.isSomali ? "Online kaliya" : "Online only"),
                    style: TextStyle(color: fileExists ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _openFile(filePath),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatColumn(String number, String label, Color color, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(number, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
      ],
    );
  }
}