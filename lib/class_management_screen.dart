import 'package:flutter/material.dart';
import 'database_helper.dart';

class ClassManagementScreen extends StatefulWidget {
  final bool isSomali;
  final String classCode;
  final String className;

  const ClassManagementScreen({
    super.key,
    required this.isSomali,
    required this.classCode,
    required this.className,
  });

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  final TextEditingController _quizQuestionController = TextEditingController();
  final TextEditingController _optAController = TextEditingController();
  final TextEditingController _optBController = TextEditingController();
  final TextEditingController _optCController = TextEditingController();
  final TextEditingController _optDController = TextEditingController();
  String _correctAnswer = 'A';

  List<Map<String, dynamic>> _quizList = [];
  bool _isLoadingQuiz = false;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  @override
  void dispose() {
    _quizQuestionController.dispose();
    _optAController.dispose();
    _optBController.dispose();
    _optCController.dispose();
    _optDController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoadingQuiz = true);
    final quizzes = await _dbHelper.getQuizQuestionsByClass(widget.classCode);
    if (!mounted) return;
    setState(() {
      _quizList = quizzes;
      _isLoadingQuiz = false;
    });
  }

  Future<void> _saveQuizQuestion() async {
    if (_quizQuestionController.text.trim().isEmpty ||
        _optAController.text.trim().isEmpty ||
        _optBController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isSomali
              ? "Fadlan buuxi su'aasha iyo doorashooyinka!"
              : "Please fill out the question and options!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _dbHelper.addQuizQuestion(
      classCode: widget.classCode,
      quizTitle: "General Quiz",
      sectionName: "Section 1",
      question: _quizQuestionController.text.trim(),
      optionA: _optAController.text.trim(),
      optionB: _optBController.text.trim(),
      optionC: _optCController.text.trim(),
      optionD: _optDController.text.trim(),
      correctAnswer: _correctAnswer,
    );

    _quizQuestionController.clear();
    _optAController.clear();
    _optBController.clear();
    _optCController.clear();
    _optDController.clear();
    setState(() => _correctAnswer = 'A');

    await _loadQuizzes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isSomali
            ? "Su'aasha Quiz-ka waa la kaydiyey!"
            : "Quiz question saved successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteQuizQuestion(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isSomali ? "Tirtir Su'aasha" : "Delete Question"),
        content: Text(widget.isSomali
            ? "Ma hubtaa inaad tirtireyso su'aashaan?"
            : "Are you sure you want to delete this question?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isSomali ? "Maya" : "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isSomali ? "Haa, Tirtir" : "Yes, Delete",
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = await _dbHelper.database;
    await db.delete('quizzes', where: 'id = ?', whereArgs: [id]);
    await _loadQuizzes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isSomali ? "Su'aasha waa la tirtiray!" : "Question deleted!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF0D6EFD);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color subTextColor = isDark ? Colors.grey : const Color(0xFF64748B);
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            "${widget.className} (${widget.classCode})",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
          ),
          backgroundColor: cardColor,
          iconTheme: IconThemeData(color: textColor),
          elevation: 0,
          bottom: TabBar(
            labelColor: primaryColor,
            unselectedLabelColor: subTextColor,
            indicatorColor: primaryColor,
            tabs: [
              Tab(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                text: widget.isSomali ? "Abuur" : "Create",
              ),
              Tab(
                icon: const Icon(Icons.quiz_outlined, size: 18),
                text: widget.isSomali
                    ? "Su'aalaha (${_quizList.length})"
                    : "Questions (${_quizList.length})",
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── TAB 1: ABUUR QUIZ ──────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isSomali
                        ? "Diyaari Su'aalaha Quiz-ka"
                        : "Create Quiz Questions",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isSomali
                        ? "Su'aalahan waxaa loo kaydin doonaa fasalkan oo kaliya"
                        : "Questions will be saved for this class only",
                    style: TextStyle(fontSize: 13, color: subTextColor),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: isDark
                              ? Colors.grey.withValues(alpha: 0.15)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _quizQuestionController,
                            maxLines: 2,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: widget.isSomali ? "Qor Su'aasha" : "Question Text",
                              labelStyle: TextStyle(color: subTextColor),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey.withValues(alpha: 0.3)
                                          : Colors.grey),
                                  borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: primaryColor),
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildOptionField(_optAController, "A", textColor, subTextColor, isDark, primaryColor),
                          const SizedBox(height: 10),
                          _buildOptionField(_optBController, "B", textColor, subTextColor, isDark, primaryColor),
                          const SizedBox(height: 10),
                          _buildOptionField(_optCController, "C (${widget.isSomali ? "Ikhtiyaari" : "Optional"})", textColor, subTextColor, isDark, primaryColor),
                          const SizedBox(height: 10),
                          _buildOptionField(_optDController, "D (${widget.isSomali ? "Ikhtiyaari" : "Optional"})", textColor, subTextColor, isDark, primaryColor),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.isSomali ? "Jawaabta Saxda ah:" : "Correct Answer:",
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.grey.withValues(alpha: 0.3)
                                          : const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButton<String>(
                                  value: _correctAnswer,
                                  underline: const SizedBox(),
                                  dropdownColor: cardColor,
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  items: ['A', 'B', 'C', 'D']
                                      .map((o) => DropdownMenuItem(
                                            value: o,
                                            child: Text(o),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setState(() => _correctAnswer = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saveQuizQuestion,
                            icon: const Icon(Icons.save_rounded, color: Colors.white),
                            label: Text(
                              widget.isSomali ? "Kaydi Su'aasha" : "Save Question",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── TAB 2: LIISKA QUIZ-YADA ────────────────────
            _isLoadingQuiz
                ? const Center(child: CircularProgressIndicator())
                : _quizList.isEmpty
                    ? _buildEmptyStateIllustration(
                        Icons.quiz_outlined,
                        widget.isSomali ? "Ma jiraan su'aalo weli" : "No quiz questions yet",
                        widget.isSomali
                            ? "Tab 'Abuur' isticmaal si aad u darto su'aalo!"
                            : "Use the 'Create' tab to add questions!",
                        subTextColor,
                        primaryColor,
                        60,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quizList.length,
                        itemBuilder: (context, index) {
                          final q = _quizList[index];
                          final correct = q['correct_answer'] as String? ?? 'A';
                          final options = {
                            'A': q['option_A'] as String? ?? '',
                            'B': q['option_B'] as String? ?? '',
                            'C': q['option_C'] as String? ?? '',
                            'D': q['option_D'] as String? ?? '',
                          };
                          return Card(
                            color: cardColor,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.15))),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor:
                                            primaryColor.withValues(alpha: 0.15),
                                        child: Text('${index + 1}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(q['question'] ?? '',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: textColor)),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 20),
                                        onPressed: () =>
                                            _deleteQuizQuestion(q['id'] as int),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ...options.entries
                                      .where((e) => e.value.isNotEmpty)
                                      .map((e) {
                                    final isCorrect = e.key == correct;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isCorrect
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: isCorrect
                                                ? Colors.green.withValues(alpha: 0.4)
                                                : Colors.transparent),
                                      ),
                                      child: Row(
                                        children: [
                                          Text('${e.key}. ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isCorrect
                                                      ? Colors.green
                                                      : subTextColor,
                                                  fontSize: 13)),
                                          Expanded(
                                            child: Text(e.value,
                                                style: TextStyle(
                                                    color: isCorrect
                                                        ? Colors.green
                                                        : textColor,
                                                    fontSize: 13)),
                                          ),
                                          if (isCorrect)
                                            const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                color: Colors.green,
                                                size: 16),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionField(TextEditingController controller, String label,
      Color textColor, Color subTextColor, bool isDark, Color primaryColor) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: "Option $label",
        labelStyle: TextStyle(color: subTextColor),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF0D6EFD)),
            borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
    );
  }

  Widget _buildEmptyStateIllustration(
    IconData icon,
    String title,
    String subtitle,
    Color subTextColor,
    Color primaryColor,
    double iconSize,
  ) {
    return Center(
      child: Padding(
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
      ),
    );
  }
}