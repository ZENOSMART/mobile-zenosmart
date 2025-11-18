import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'devices_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sw = constraints.maxWidth;
            const refW = 1080.0;
            final s = sw / refW;
            // Güvenli genişlik hesapları (clamp hatasını önlemek için min/max kullan)
            final buttonW = math.min(sw * 0.72, 900.0 * s);
            final radius = 27.0 * s;
            final gap = 36.5 * s;
            final vPad = 18.0 * s;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 320.0 * s),
                Image.asset(
                  'assets/images/zenosmart-connect.png',
                  width: math.min(sw * 0.78, math.max(140.0, 700.0 * s)),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 40.0 * s),
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/smart-city.webp',
                      width: math.min(sw * 0.94, math.max(220.0, 1452.0 * s)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 80.0 * s),
                SizedBox(
                  width: buttonW,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF008E46),
                      disabledForegroundColor: Colors.white,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        vertical: vPad,
                        horizontal: 16.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Zenosmart',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: null,
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: gap),
                SizedBox(
                  width: buttonW,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DevicesPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008E46),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: vPad,
                        horizontal: 16.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Bluetooth',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final m = ScaffoldMessenger.of(context);
                            m.hideCurrentSnackBar();
                            m.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Operations via Bluetooth will be independent of the Zenosmart Panel.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Color(0xFF16335F),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 70.0 * s),
                Image.asset(
                  'assets/images/zenosmart-logo-black.png',
                  width: (500.0 * s).clamp(110.0, sw * 0.65),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 150.0 * s),
              ],
            );
          },
        ),
      ),
    );
  }
}
