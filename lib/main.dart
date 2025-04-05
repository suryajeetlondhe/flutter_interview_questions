import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(home: QuestionsScreen()));

class QuestionsScreen extends StatefulWidget {
  @override
  _QuestionsScreenState createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<String> questions = [];
  List<String> filtered = [];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    final url = 'https://raw.githubusercontent.com/suryajeetlondhe/flutter-interview-questions/main/README.md'; // Change this
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final lines = response.body.split('\n');
      final extracted = <String>[];
      for (var line in lines) {
        if (line.startsWith("###")) {
          extracted.add(line.replaceFirst('### ', ''));
        }
      }
      setState(() {
        questions = extracted;
        filtered = extracted;
      });
    } else {
      print("Failed to fetch data");
    }
  }

  void filterQuestions(String query) {
    final q = query.toLowerCase();
    setState(() {
      filtered = questions.where((item) => item.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Interview Questions')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              onChanged: filterQuestions,
              decoration: InputDecoration(
                hintText: "Search questions...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(filtered[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
