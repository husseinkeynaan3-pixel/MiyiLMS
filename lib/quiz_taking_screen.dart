import 'package:flutter/material.dart';
import 'database_helper.dart';

class QuizTakingScreen extends StatefulWidget {
  final bool isSomali;
  final String classCode;
  final String className;
  final String studentEmail;
  final String studentName;

  const QuizTakingScreen({
    super.key,
    required this.isSomali,
    required this.classCode,
    required this.className,
    required this.studentEmail,
    required this.studentName,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  final Map<int, String> _selectedAnswers = {};

  bool _isSubmitted = false;
  int _score = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await _dbHelper.getQuizQuestionsByClass(widget.classCode);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _selectAnswer(String answer) {
    setState(() => _selectedAnswers[_currentQuestionIndex] = answer);
  }

  void _goToNext() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    }
  }

  void _goToPrevious() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
    }
  }

  Future<void> _handleSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isSomali ? "Dir Quiz-ka" : "Submit Quiz"),
        content: Text(
          widget.isSomali
              ? "Ma hubtaa inaad diraysid quiz-ka? Marka la diro, ma beddeli kartid jawaabaha."
              : "Are you sure you want to submit? You cannot change answers after submitting.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.isSomali ? "Maya" : "Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.isSomali ? "Haa, Dir" : "Yes, Submit"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      final correctAnswer = _questions[i]['correct_answer'];
      final selected = _selectedAnswers[i];
      if (selected != null && selected == correctAnswer) {
        correctCount++;
      }
    }

    await _dbHelper.submitQuizResult(
      classCode: widget.classCode,
      studentEmail: widget.studentEmail,
      studentName: widget.studentName,
      score: correctCount,
      totalQuestions: _questions.length,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isSubmitted = true;
      _score = correctCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? Colors.grey : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.className,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? _buildEmptyState(textColor, subTextColor, primaryBlue)
              : _isSubmitted
                  ? _buildResultScreen(cardColor, textColor, subTextColor, primaryBlue)
                  : _buildQuestionScreen(cardColor, textColor, subTextColor, primaryBlue),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor, Color primaryBlue) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.quiz_outlined, size: 50, color: primaryBlue.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isSomali ? "Ma jiraan su'aalo weli" : "No quiz questions yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSomali
                  ? "Macallinku weli su'aalo ma darin fasalkan."
                  : "Your teacher hasn't added quiz questions yet.",
              style: TextStyle(fontSize: 13, color: subTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isSomali ? "Dib u noqo" : "Go Back", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScreen(Color cardColor, Color textColor, Color subTextColor, Color primaryBlue) {
    final question = _questions[_currentQuestionIndex];
    final options = <String, String?>{
      'A': question['option_A'] as String?,
      'B': question['option_B'] as String?,
      'C': question['option_C'] as String?,
      'D': question['option_D'] as String?,
    };
    final selected = _selectedAnswers[_currentQuestionIndex];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.isSomali ? "Su'aal" : "Question"} ${_currentQuestionIndex + 1} / ${_questions.length}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                  ),
                  Text(
                    '${_selectedAnswers.length} / ${_questions.length} ${widget.isSomali ? "la jawaabay" : "answered"}',
                    style: TextStyle(fontSize: 12, color: primaryBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _questions.length,
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  color: primaryBlue,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    question['question'] ?? '',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                ...options.entries.where((e) => e.value != null && e.value!.isNotEmpty).map((entry) {
                  final isSelected = selected == entry.key;
                  return GestureDetector(
                    onTap: () => _selectAnswer(entry.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue.withValues(alpha: 0.1) : cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? primaryBlue : Colors.grey.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? primaryBlue : Colors.grey.withValues(alpha: 0.1),
                            ),
                            child: Center(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : subTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              entry.value!,
                              style: TextStyle(
                                fontSize: 15,
                                color: isSelected ? primaryBlue : textColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle_rounded, color: primaryBlue, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goToPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: primaryBlue),
                    ),
                    child: Text(widget.isSomali ? "Dib" : "Previous", style: TextStyle(color: primaryBlue)),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : (_currentQuestionIndex == _questions.length - 1
                          ? _handleSubmit
                          : _goToNext),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _currentQuestionIndex == _questions.length - 1
                              ? (widget.isSomali ? "Dir Quiz-ka" : "Submit Quiz")
                              : (widget.isSomali ? "Xiga" : "Next"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(Color cardColor, Color textColor, Color subTextColor, Color primaryBlue) {
    final percentage = (_score / _questions.length * 100).round();
    final isPassing = percentage >= 50;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isPassing ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              ),
              child: Center(
                child: Icon(
                  isPassing ? Icons.check_circle_rounded : Icons.info_rounded,
                  size: 60,
                  color: isPassing ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isSomali ? "Quiz-ka waa la dhammeeyay!" : "Quiz Completed!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            Text(
              '$_score / ${_questions.length}',
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: isPassing ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage% ${widget.isSomali ? "sax" : "correct"}',
              style: TextStyle(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  widget.isSomali ? "Dib u noqo" : "Go Back",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}