import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerScreen extends StatefulWidget {
  final bool isSomali;
  final String filePath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.isSomali,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF0D6EFD);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final Color appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_hasError && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _hasError
          ? _buildErrorState(textColor, primaryBlue)
          : Stack(
              children: [
                PDFView(
                  filePath: widget.filePath,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) {
                    setState(() {
                      _isLoading = false;
                      _totalPages = pages ?? 0;
                    });
                  },
                  onError: (error) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                    });
                  },
                  onPageError: (page, error) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                    });
                  },
                  onPageChanged: (page, total) {
                    setState(() => _currentPage = page ?? 0);
                  },
                ),
                if (_isLoading)
                  Container(
                    color: bgColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: primaryBlue),
                          const SizedBox(height: 16),
                          Text(
                            widget.isSomali ? "Faylka waa la soo rarayaa..." : "Loading document...",
                            style: TextStyle(color: textColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorState(Color textColor, Color primaryBlue) {
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
                color: Colors.redAccent.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.error_outline_rounded, size: 50, color: Colors.redAccent.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isSomali ? "Faylka lama furi karo" : "Unable to open file",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSomali
                  ? "Faylkan waa khaldan yahay ama lama heli karo."
                  : "This file may be corrupted or unavailable.",
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              label: Text(
                widget.isSomali ? "Dib u noqo" : "Go Back",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}