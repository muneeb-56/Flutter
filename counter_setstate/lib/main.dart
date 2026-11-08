import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'counter_data.dart';
import 'counter_database.dart';
import 'counter_style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CounterHome(),
    );
  }
}

class CounterHome extends StatefulWidget {
  const CounterHome({super.key});

  @override
  State<CounterHome> createState() => _CounterHomeState();
}

class _CounterHomeState extends State<CounterHome> {
  final db = CounterDatabase.instance;

  final List<CounterData> counters = [];
  final Map<int, TextEditingController> controllers = {};
  final Map<int, Timer> saveTimers = {};

  final TextEditingController userNameController = TextEditingController();

  int? selectedId;
  bool loading = true;
  bool drawerClosing = false;
  bool deleteDialogOpen = false;
  bool sharing = false;

  Timer? dateTimer;
  Timer? nameSaveTimer;

  @override
  void initState() {
    super.initState();
    loadApp();

    // Refresh the date periodically so it changes automatically at midnight.
    dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> loadApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userNameController.text = prefs.getString('counter_user_name') ?? '';

      final savedCounters = await db.loadCounters();
      final savedSelectedId = await db.loadSelectedId();

      if (!mounted) return;

      counters.addAll(savedCounters);

      if (counters.isEmpty) {
        final first = CounterData(
          name: 'Counter 1',
          style: CounterStyle.random(),
        );

        await db.saveCounter(first);
        counters.add(first);
      }

      for (final counter in counters) {
        controllers[counter.id!] = TextEditingController(text: counter.name);
      }

      final selectedExists =
          counters.any((counter) => counter.id == savedSelectedId);

      selectedId =
          selectedExists ? savedSelectedId : counters.first.id;

      await db.saveSelectedId(selectedId!);
    } catch (e) {
      debugPrint('Loading error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load counters. Please restart the app.'),
        ),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  CounterData get currentCounter {
    return counters.firstWhere((counter) => counter.id == selectedId);
  }

  String get currentDate {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${weekdays[now.weekday - 1]}, ${now.day} '
        '${months[now.month - 1]} ${now.year}';
  }

  void updateUserName(String value) {
    nameSaveTimer?.cancel();
    nameSaveTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('counter_user_name', value.trim());
      } catch (e) {
        debugPrint('Name save failed: $e');
      }
    });
  }

  Future<void> addCounter(BuildContext drawerContext) async {
    if (drawerClosing || loading) return;

    final counter = CounterData(
      name: 'Counter ${counters.length + 1}',
      style: CounterStyle.random(),
    );

    try {
      await db.saveCounter(counter);

      if (!mounted) return;

      controllers[counter.id!] = TextEditingController(text: counter.name);

      setState(() {
        counters.add(counter);
        selectedId = counter.id;
      });

      await db.saveSelectedId(counter.id!);

      if (!mounted) return;
      closeDrawer(drawerContext);
    } catch (e) {
      showMessage('Could not create counter.');
    }
  }

  void closeDrawer(BuildContext context) {
    if (drawerClosing) return;

    drawerClosing = true;
    Scaffold.of(context).closeDrawer();
  }

  Future<void> selectCounter(int id, BuildContext drawerContext) async {
    if (drawerClosing || selectedId == id) {
      if (!drawerClosing) closeDrawer(drawerContext);
      return;
    }

    setState(() {
      selectedId = id;
    });

    try {
      await db.saveSelectedId(id);
    } catch (e) {
      showMessage('Could not save selected counter.');
    }

    if (!mounted) return;
    closeDrawer(drawerContext);
  }

  void renameCounter(CounterData counter, String value) {
    counter.name = value;
    setState(() {});

    final id = counter.id!;
    saveTimers[id]?.cancel();

    saveTimers[id] = Timer(const Duration(milliseconds: 500), () async {
      try {
        await db.saveCounter(counter);
      } catch (e) {
        debugPrint('Name save failed: $e');
      }
    });
  }

  Future<void> changeCount(int value) async {
    final counter = currentCounter;

    setState(() {
      counter.count = value;
    });

    try {
      await db.saveCounter(counter);
    } catch (e) {
      showMessage('Could not save counter value.');
    }
  }

  Future<void> deleteCounter(int id) async {
    if (deleteDialogOpen) return;

    final counter = counters.firstWhere((item) => item.id == id);
    deleteDialogOpen = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: counter.style.appBar,
          title: const Text(
            'Delete Counter?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${counter.name}"? '
            'This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    deleteDialogOpen = false;

    if (!mounted || confirmed != true) return;

    try {
      saveTimers[id]?.cancel();
      saveTimers.remove(id);
      controllers.remove(id)?.dispose();

      await db.deleteCounter(id);

      if (!mounted) return;

      setState(() {
        counters.removeWhere((item) => item.id == id);
      });

      if (counters.isEmpty) {
        final newCounter = CounterData(
          name: 'Counter 1',
          style: CounterStyle.random(),
        );

        await db.saveCounter(newCounter);
        if (!mounted) return;

        controllers[newCounter.id!] =
            TextEditingController(text: newCounter.name);

        setState(() {
          counters.add(newCounter);
          selectedId = newCounter.id;
        });

        await db.saveSelectedId(newCounter.id!);
      } else if (selectedId == id) {
        final newSelected = counters.first;

        setState(() {
          selectedId = newSelected.id;
        });

        await db.saveSelectedId(newSelected.id!);
      }

      showMessage('Counter deleted.');
    } catch (e) {
      showMessage('Could not delete counter.');
    }
  }

Future<void> shareCurrentCounter() async {
  if (sharing || loading || counters.isEmpty || selectedId == null) return;

  setState(() => sharing = true);

  final counter = currentCounter;
  final displayName = userNameController.text.trim();
  final date = currentDate;
  final captureKey = GlobalKey();

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            // Give the dialog route time to finish its first paint/animation.
            await Future<void>.delayed(
              const Duration(milliseconds: 300),
            );

            // Wait until Flutter has completed the frame.
            await WidgetsBinding.instance.endOfFrame;

            if (!dialogContext.mounted) return;

            final renderObject =
                captureKey.currentContext?.findRenderObject();

            if (renderObject is! RenderRepaintBoundary) {
              throw Exception(
                'Could not prepare the counter image.',
              );
            }

            // Make sure the boundary has actually been painted.
            if (renderObject.debugNeedsPaint) {
              await Future<void>.delayed(
                const Duration(milliseconds: 100),
              );

              await WidgetsBinding.instance.endOfFrame;
            }

            if (renderObject.debugNeedsPaint) {
              throw Exception(
                'Counter image is not ready yet.',
              );
            }

            final image = await renderObject.toImage(
              pixelRatio: 3.0,
            );

            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );

            image.dispose();

            if (byteData == null) {
              throw Exception(
                'Could not create PNG image.',
              );
            }

            final Uint8List pngBytes =
                byteData.buffer.asUint8List();

            final tempDir = await getTemporaryDirectory();

            final file = File(
              '${tempDir.path}/tasbih_counter.png',
            );

            await file.writeAsBytes(
              pngBytes,
              flush: true,
            );

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }

            await Share.shareXFiles(
              [
                XFile(file.path),
              ],
              text: 'Tasbih Counter',
            );
          } catch (e) {
            debugPrint('Share image error: $e');

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }

            if (mounted) {
              showMessage(
                'Could not share PNG: $e',
              );
            }
          }
        });

        final screenWidth =
            MediaQuery.of(dialogContext).size.width;

        final cardSize =
            (screenWidth - 48)
                .clamp(240.0, 320.0)
                .toDouble();

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(12),
          child: RepaintBoundary(
            key: captureKey,
            child: _ShareCounterCard(
              size: cardSize,
              counterName:
                  counter.name.trim().isEmpty
                      ? 'Untitled Counter'
                      : counter.name.trim(),
              count: counter.count,
              date: date,
              userName: displayName,
              background: counter.style.background,
              accent: counter.style.accent,
              textColor: counter.style.text,
            ),
          ),
        );
      },
    );
  } finally {
    if (mounted) {
      setState(() => sharing = false);
    }
  }
}

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    dateTimer?.cancel();
    nameSaveTimer?.cancel();

    for (final timer in saveTimers.values) {
      timer.cancel();
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }

    userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || counters.isEmpty || selectedId == null) {
      return const _LoadingPreview();
    }

    final current = currentCounter;
    final controller = controllers[current.id!]!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min(screenWidth * 0.84, 380.0);

    return Scaffold(
      backgroundColor: current.style.background,
      onDrawerChanged: (isOpened) {
        if (!isOpened) drawerClosing = false;
      },
      appBar: AppBar(
        backgroundColor: current.style.appBar,
        foregroundColor: current.style.text,
        titleSpacing: 0,
        title: Text(
          current.name.trim().isEmpty ? 'Tasbih Counter' : current.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                if (!drawerClosing) {
                  Scaffold.of(context).openDrawer();
                }
              },
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Developed by Muneeb',
                style: TextStyle(
                  color: current.style.text.withValues(alpha: 0.78),
                  fontSize: screenWidth < 360 ? 9 : 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        width: drawerWidth,
        backgroundColor: current.style.appBar,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                  child: Row(
                    children: [
                      TasbihMark(size: 42, color: current.style.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: userNameController,
                          onChanged: updateUserName,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Your Name',
                            hintStyle:
                                const TextStyle(color: Colors.white60),
                            suffixIcon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 19,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: counters.length,
                  itemBuilder: (context, index) {
                    final counter = counters[index];

                    return ListTile(
                      key: ValueKey(counter.id),
                      selected: counter.id == selectedId,
                      selectedTileColor:
                          current.style.accent.withValues(alpha: 0.2),
                      leading: TasbihMark(
                        size: 26,
                        color: counter.style.accent,
                      ),
                      title: Text(
                        counter.name.isEmpty
                            ? 'Untitled Counter'
                            : counter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Count: ${counter.count}',
                        style: const TextStyle(color: Colors.white60),
                      ),
                      onTap: () => selectCounter(counter.id!, context),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => deleteCounter(counter.id!),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton.icon(
                        onPressed: () => addCounter(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Counter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A68A),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              math.min(constraints.maxWidth, 520.0);
          final countFontSize =
              (contentWidth * 0.19).clamp(52.0, 86.0).toDouble();
          final buttonSize =
              (contentWidth * 0.25).clamp(78.0, 104.0).toDouble();

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Share counter as PNG',
                            onPressed: sharing ? null : shareCurrentCounter,
                            icon: sharing
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: current.style.text,
                                    ),
                                  )
                                : Icon(
                                    Icons.share_outlined,
                                    color: current.style.text.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                          ),
                        ),
                        Text(
                          currentDate,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: current.style.text.withValues(alpha: 0.72),
                            fontSize: 14,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          textAlign: TextAlign.center,
                          maxLength: 40,
                          style: TextStyle(
                            color: current.style.text,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Enter counter name',
                            hintStyle:
                                const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: current.style.inputBackground,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: current.style.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: current.style.accent,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) => renameCounter(current, value),
                        ),
                        SizedBox(
                          height: constraints.maxHeight < 600 ? 28 : 48,
                        ),
                        Text(
                          'CURRENT COUNT',
                          style: TextStyle(
                            color: current.style.text.withValues(alpha: 0.7),
                            fontSize: 15,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${current.count}',
                            maxLines: 1,
                            style: TextStyle(
                              color: current.style.countColor,
                              fontSize: countFontSize,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: current.style.countColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: constraints.maxHeight < 600 ? 28 : 44,
                        ),
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            onPressed: () {
                              if (current.count < 9007199254740991) {
                                changeCount(current.count + 1);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: current.style.accent,
                              foregroundColor: current.style.buttonText,
                              elevation: 7,
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.add, size: 38),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'TAP TO INCREMENT',
                          style: TextStyle(
                            color: current.style.text.withValues(alpha: 0.6),
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => changeCount(0),
        backgroundColor: current.style.reset,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Reset counter',
        child: const Icon(Icons.refresh, size: 28),
      ),
    );
  }
}

class _LoadingPreview extends StatelessWidget {
  const _LoadingPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TasbihMark(size: 92, color: Color(0xFF00C5A0)),
              const SizedBox(height: 22),
              const Text(
                'Tasbih Counter',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Developed by Muneeb',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF00C5A0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TasbihMark extends StatelessWidget {
  const TasbihMark({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TasbihPainter(color),
      ),
    );
  }
}

class _TasbihPainter extends CustomPainter {
  _TasbihPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;

    final stringPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width * 0.035);

    canvas.drawCircle(center, radius, stringPaint);

    final beadPaint = Paint()..color = color;
    const beadCount = 13;

    for (int i = 0; i < beadCount; i++) {
      final angle = (2 * math.pi * i / beadCount) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(
        point,
        size.width * (i == 0 ? 0.075 : 0.055),
        beadPaint,
      );
    }

    final tasselStart = Offset(
      center.dx + radius * 0.55,
      center.dy - radius * 0.82,
    );
    final tasselEnd = Offset(
      tasselStart.dx + size.width * 0.16,
      tasselStart.dy - size.height * 0.17,
    );

    canvas.drawLine(tasselStart, tasselEnd, stringPaint);
    canvas.drawCircle(tasselEnd, size.width * 0.075, beadPaint);
    canvas.drawCircle(
      Offset(tasselEnd.dx + size.width * 0.035, tasselEnd.dy + size.height * 0.09),
      size.width * 0.035,
      beadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TasbihPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ShareCounterCard extends StatelessWidget {
  const _ShareCounterCard({
    required this.size,
    required this.counterName,
    required this.count,
    required this.date,
    required this.userName,
    required this.background,
    required this.accent,
    required this.textColor,
  });

  final double size;
  final String counterName;
  final int count;
  final String date;
  final String userName;
  final Color background;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.075),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.07),
        border: Border.all(
          color: accent.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              TasbihMark(size: size * 0.16, color: accent),
              SizedBox(height: size * 0.025),
              Text(
                'TASBIH COUNTER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: size * 0.037,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                counterName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: size * 0.055,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: size * 0.025),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: accent,
                    fontSize: size * 0.19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'COUNTS',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: size * 0.032,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                date,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: size * 0.033,
                ),
              ),
              if (userName.isNotEmpty) ...[
                SizedBox(height: size * 0.025),
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: size * 0.043,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              SizedBox(height: size * 0.025),
              Text(
                'Developed by Muneeb',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.55),
                  fontSize: size * 0.027,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
