import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'devices_page.dart';

class AboutHelpPage extends StatelessWidget {
  const AboutHelpPage({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(
        uri,
        mode: url_launcher.LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DevicesPage()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F1F1),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DevicesPage()),
              );
            },
          ),
          title: const Text('About / Help'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // About Section
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Zenosmart Connect is a device management application that allows you to connect, configure, and manage your Zenosmart IoT devices via Bluetooth.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      const Text(
                        'Zenosmart is a registered trademark of ZENOPIX®',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Contact Section
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Website
                      InkWell(
                        onTap: () => _launchURL('https://zenosmart.com'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.language,
                                color: Color(0xFF008E46),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'zenosmart.com',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF008E46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      // Email
                      InkWell(
                        onTap: () => _launchEmail('info@zenopix.com'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.email,
                                color: Color(0xFF008E46),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'info@zenopix.com',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF008E46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Version
              Center(
                child: Text(
                  'Version 3.0.0+3',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
