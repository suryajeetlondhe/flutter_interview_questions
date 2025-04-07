import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(
    ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          home: QuestionsScreen(),
        );
      },
    ),
  );
}

class QuestionsScreen extends StatefulWidget {
  @override
  _QuestionsScreenState createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<String> questions = [];
  List<String> filtered = [];
  TextEditingController searchController = TextEditingController();
  String searchWord = '';
  int currentMatchIndex = 0;
  List<int> matchIndexes = [];
  Set<int> bookmarkedIndexes = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchQuestions();
    loadBookmarks();
  }

  Future<void> fetchQuestions() async {
    final url = 'https://raw.githubusercontent.com/suryajeetlondhe/flutter_interview_questions/refs/heads/master/README.md';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      List<String> cleanData = [];
      String currentQn = '';
      String currentAns = '';

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith("---") || line.startsWith("#")) continue;

        if (RegExp(r'^\d+\.\s*').hasMatch(line)) {
          if (currentQn.isNotEmpty && currentAns.isNotEmpty) {
            cleanData.add('${currentQn.trim()}\n${currentAns.trim()}');
          }
          currentQn = line.replaceAll("*", "");
          currentAns = '';
        } else {
          currentAns += line.replaceAll("*", "") + '\n';
        }
      }

      if (currentQn.isNotEmpty && currentAns.isNotEmpty) {
        cleanData.add('${currentQn.trim()}\n${currentAns.trim()}');
      }

      setState(() {
        questions = cleanData;
        filtered = cleanData;
      });
    }
  }

  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarked = prefs.getStringList('bookmarks') ?? [];
    setState(() {
      bookmarkedIndexes = bookmarked.map((e) => int.parse(e)).toSet();
    });
  }

  Future<void> saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', bookmarkedIndexes.map((e) => e.toString()).toList());
  }

  void search(String query) {
    setState(() {
      searchWord = query.toLowerCase();
      filtered = questions.where((q) => q.toLowerCase().contains(searchWord)).toList();
      matchIndexes = [];

      for (int i = 0; i < filtered.length; i++) {
        if (filtered[i].toLowerCase().contains(searchWord)) {
          matchIndexes.add(i);
        }
      }

      currentMatchIndex = 0;
    });

    scrollToMatch();
  }

  void scrollToMatch() {
    if (matchIndexes.isNotEmpty) {
      final index = matchIndexes[currentMatchIndex];
      final position = index * 1000.0;

      _scrollController.animateTo(
        position,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToNextMatch() {
    if (matchIndexes.isNotEmpty) {
      setState(() {
        currentMatchIndex = (currentMatchIndex + 1) % matchIndexes.length;
      });
      scrollToMatch();
    }
  }

  void goToPreviousMatch() {
    if (matchIndexes.isNotEmpty) {
      setState(() {
        currentMatchIndex = (currentMatchIndex - 1 + matchIndexes.length) % matchIndexes.length;
      });
      scrollToMatch();
    }
  }

  void exportAsPDF() async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        build: (context) => questions.map((q) => pw.Text(q)).toList(),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdfDoc.save());
  }

  Widget _highlightedText(String text) {
    if (searchWord.isEmpty) {
      return Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color));
    }

    final matches = RegExp(searchWord, caseSensitive: false).allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color));
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(backgroundColor: Colors.yellow, fontWeight: FontWeight.bold),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
        children: spans,
      ),
    );
  }

  @override
  void dispose() {
    saveBookmarks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Interview Questions'),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: exportAsPDF),
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              onChanged: search,
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (searchWord.isNotEmpty && matchIndexes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Match ${currentMatchIndex + 1} of ${matchIndexes.length}',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      IconButton(onPressed: goToPreviousMatch, icon: Icon(Icons.arrow_back_ios_new)),
                      IconButton(onPressed: goToNextMatch, icon: Icon(Icons.arrow_forward_ios)),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final isMatched = matchIndexes.contains(index);
                final isCurrentMatch = isMatched && index == matchIndexes[currentMatchIndex];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isCurrentMatch
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
                      : Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isMatched)
                              Text('🔍 Found "$searchWord"',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.secondary)),
                            IconButton(
                              icon: Icon(
                                bookmarkedIndexes.contains(index)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (bookmarkedIndexes.contains(index)) {
                                    bookmarkedIndexes.remove(index);
                                  } else {
                                    bookmarkedIndexes.add(index);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        _highlightedText(filtered[index]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}