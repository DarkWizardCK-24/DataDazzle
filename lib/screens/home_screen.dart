import 'package:flutter/material.dart';
import 'package:data_registration/screens/table_manager_screen.dart';
import 'package:data_registration/utils/responsive.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DataDazzle',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Color(0xFF212121),
              Color(0xFF424242),
              Color(0xFF616161),
              Color(0xFF757575),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.5, 0.7, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(wide ? 28 : 24),
                    child: Image.asset(
                      'assets/brand/logo.png',
                      width: wide ? 128 : 104,
                      height: wide ? 128 : 104,
                      semanticLabel: 'DataDazzle logo',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'DataDazzle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 36 : 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Design your own tables, capture records with generated forms, '
                    'and move data in and out as CSV or Excel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TableManagerScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Manage Tables'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
