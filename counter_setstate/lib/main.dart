
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
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

  final TextEditingController userNameController =
      TextEditingController();

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

    dateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> loadApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      userNameController.text =
          prefs.getString('counter_user_name') ?? '';

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
        controllers[counter.id!] =
            TextEditingController(text: counter.name);
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
          content: Text(
            'Unable to load counters. Please restart the app.',
          ),
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
    return counters.firstWhere(
      (counter) => counter.id == selectedId,
    );
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

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void updateUserName(String value) {
    nameSaveTimer?.cancel();

    nameSaveTimer = Timer(
      const Duration(milliseconds: 350),
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(
            'counter_user_name',
            value.trim(),
          );
        } catch (e) {
          debugPrint('Name save failed: $e');
        }
      },
    );
  }

  Future<void> addCounter(BuildContext drawerContext) async {
    if (drawerClosing || loading) return;

    dismissKeyboard();

    final counter = CounterData(
      name: 'Counter ${counters.length + 1}',
      style: CounterStyle.random(),
    );

    try {
      await db.saveCounter(counter);

      if (!mounted) return;

      controllers[counter.id!] =
          TextEditingController(text: counter.name);

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

  Future<void> selectCounter(
    int id,
    BuildContext drawerContext,
  ) async {
    dismissKeyboard();

    if (drawerClosing || selectedId == id) {
      if (!drawerClosing) {
        closeDrawer(drawerContext);
      }
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

    saveTimers[id] = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          await db.saveCounter(counter);
        } catch (e) {
          debugPrint('Name save failed: $e');
        }
      },
    );
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

    dismissKeyboard();

    final counter =
        counters.firstWhere((item) => item.id == id);

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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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
    if (sharing ||
        loading ||
        counters.isEmpty ||
        selectedId == null) {
      return;
    }

    dismissKeyboard();

    setState(() {
      sharing = true;
    });

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
          WidgetsBinding.instance.addPostFrameCallback(
            (_) async {
              try {
                await Future<void>.delayed(
                  const Duration(milliseconds: 250),
                );

                await WidgetsBinding.instance.endOfFrame;

                if (!dialogContext.mounted) return;

                final renderObject =
                    captureKey.currentContext?.findRenderObject();

                if (renderObject is! RenderRepaintBoundary) {
                  throw Exception(
                    'Could not prepare the counter image.',
                  );
                }

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
                  throw Exception('Could not create PNG image.');
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

                // Share image only. No caption or extra text.
                await Share.shareXFiles([
                  XFile(file.path),
                ]);
              } catch (e) {
                debugPrint('Share image error: $e');

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (mounted) {
                  showMessage('Could not share PNG.');
                }
              }
            },
          );

          final screenWidth =
              MediaQuery.sizeOf(dialogContext).width;

          final cardWidth = math.min(
            screenWidth - 40,
            360.0,
          );

          final cardHeight = cardWidth * 1.25;

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            child: RepaintBoundary(
              key: captureKey,
              child: _ShareCounterCard(
                width: cardWidth,
                height: cardHeight,
                counterName: counter.name.trim().isEmpty
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
        setState(() {
          sharing = false;
        });
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
      return const Scaffold(
        backgroundColor: Color(0xFF101827),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00C5A0),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final current = currentCounter;
    final controller = controllers[current.id!]!;

    final screenWidth = MediaQuery.sizeOf(context).width;

    final drawerWidth = math.min(
      screenWidth * 0.84,
      380.0,
    );

    return Scaffold(
      backgroundColor: current.style.background,

      onDrawerChanged: (isOpened) {
        if (!isOpened) {
          drawerClosing = false;
          dismissKeyboard();
        }
      },

      appBar: AppBar(
        backgroundColor: current.style.appBar,
        foregroundColor: current.style.text,
        elevation: 0,
        titleSpacing: 0,

        title: Row(
          children: [
            TasbihMark(
              size: 27,
              color: current.style.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                current.name.trim().isEmpty
                    ? 'Tasbih Counter'
                    : current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () {
                dismissKeyboard();

                if (!drawerClosing) {
                  Scaffold.of(context).openDrawer();
                }
              },
            );
          },
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                'Developed by Muneeb',
                style: TextStyle(
                  color: current.style.text.withValues(alpha: 0.68),
                  fontSize: screenWidth < 360 ? 9 : 10,
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
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    16,
                    14,
                    12,
                  ),
                  child: Row(
                    children: [
                      TasbihMark(
                        size: 38,
                        color: current.style.accent,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: TextField(
                          controller: userNameController,
                          autofocus: false,
                          onChanged: updateUserName,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Your Name',
                            hintStyle: const TextStyle(
                              color: Colors.white60,
                            ),
                            suffixIcon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 19,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
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

              const Divider(
                color: Colors.white24,
                height: 1,
              ),

              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),

                      subtitle: Text(
                        'Count: ${counter.count}',
                        style: const TextStyle(
                          color: Colors.white60,
                        ),
                      ),

                      onTap: () {
                        dismissKeyboard();

                        selectCounter(
                          counter.id!,
                          context,
                        );
                      },

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

      body: SafeArea(
  top: false,
  child: Stack(
    children: [
      // MAIN COUNTER CONTENT
      Positioned.fill(
        top: 25,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(
              constraints.maxWidth,
              520.0,
            );

            final countFontSize = (contentWidth * 0.18)
                .clamp(54.0, 86.0)
                .toDouble();

            final buttonSize = (contentWidth * 0.29)
                .clamp(96.0, 120.0)
                .toDouble();

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
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
                        vertical: 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // DATE
                          Text(
                            currentDate,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: current.style.text.withValues(
                                alpha: 0.68,
                              ),
                              fontSize: 13,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // COUNTER NAME
                          TextField(
                            controller: controller,
                            autofocus: false,
                            textInputAction: TextInputAction.done,
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
                              hintStyle: const TextStyle(
                                color: Colors.white54,
                              ),
                              filled: true,
                              fillColor:
                                  current.style.inputBackground,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 15,
                              ),
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
                            onChanged: (value) {
                              renameCounter(current, value);
                            },
                          ),

                          const SizedBox(height: 60),

                          // CURRENT COUNT LABEL
                          Text(
                            'CURRENT COUNT',
                            style: TextStyle(
                              color: current.style.text.withValues(
                                alpha: 0.65,
                              ),
                              fontSize: 13,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 13),

                          // COUNT NUMBER
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${current.count}',
                              maxLines: 1,
                              style: TextStyle(
                                color: current.style.countColor,
                                fontSize: countFontSize,
                                fontWeight: FontWeight.w900,
                                height: 0.95,
                                shadows: [
                                  Shadow(
                                    color: current.style.countColor
                                        .withValues(alpha: 0.30),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 50),

                          // INCREMENT BUTTON
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: ElevatedButton(
                              onPressed: () {
                                if (current.count <
                                    9007199254740991) {
                                  changeCount(current.count + 1);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    current.style.accent,
                                foregroundColor:
                                    current.style.buttonText,
                                elevation: 7,
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 44,
                              ),
                            ),
                          ),

                          const SizedBox(height: 13),

                          // INCREMENT HINT
                          Text(
                            'TAP TO INCREMENT',
                            style: TextStyle(
                              color: current.style.text.withValues(
                                alpha: 0.55,
                              ),
                              letterSpacing: 1.2,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // SHARE BUTTON: FIXED TO SCREEN'S TOP-RIGHT CORNER
      Positioned(
        top: 3,
        right: 8,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: sharing ? null : shareCurrentCounter,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: sharing
                    ? SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: current.style.text,
                        ),
                      )
                    : Icon(
                        Icons.share_outlined,
                        size: 23,
                        color: current.style.text.withValues(
                          alpha: 0.85,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          dismissKeyboard();
          changeCount(0);
        },
        backgroundColor: current.style.reset,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Reset counter',
        child: const Icon(
          Icons.refresh,
          size: 28,
        ),
      ),
    );
  }
}

// --------------------------------------------------
// TASBIH ICON
// --------------------------------------------------

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
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width * 0.32;

    final stringPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(
        1.2,
        size.width * 0.035,
      );

    canvas.drawCircle(
      center,
      radius,
      stringPaint,
    );

    final beadPaint = Paint()..color = color;

    const beadCount = 13;

    for (int i = 0; i < beadCount; i++) {
      final angle =
          (2 * math.pi * i / beadCount) - math.pi / 2;

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

    canvas.drawLine(
      tasselStart,
      tasselEnd,
      stringPaint,
    );

    canvas.drawCircle(
      tasselEnd,
      size.width * 0.075,
      beadPaint,
    );

    canvas.drawCircle(
      Offset(
        tasselEnd.dx + size.width * 0.035,
        tasselEnd.dy + size.height * 0.09,
      ),
      size.width * 0.035,
      beadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TasbihPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// --------------------------------------------------
// SHARE IMAGE CARD
// --------------------------------------------------

class _ShareCounterCard extends StatelessWidget {
  const _ShareCounterCard({
    required this.width,
    required this.height,
    required this.counterName,
    required this.count,
    required this.date,
    required this.userName,
    required this.background,
    required this.accent,
    required this.textColor,
  });

  final double width;
  final double height;

  final String counterName;
  final int count;
  final String date;
  final String userName;

  final Color background;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = width * 0.09;

    // Reduced to prevent bottom overflow.
    final verticalPadding = height * 0.020;

    return Container(
      width: width,
      height: height,

      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(width * 0.065),
        border: Border.all(
          color: accent.withValues(alpha: 0.75),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),

      child: Column(
        children: [
          // Top branding.
          Expanded(
            flex: 27,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: width * 0.18,
                  height: width * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Center(
                    child: TasbihMark(
                      size: width * 0.12,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.018),

                Text(
                  'TASBIH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: width * 0.045,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),

                Text(
                  'COUNTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.65),
                    fontSize: width * 0.025,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),

          // Counter information.
          Expanded(
            flex: 43,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.03,
                  ),
                  child: Text(
                    counterName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: width * 0.055,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.025),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: accent,
                      fontSize: width * 0.20,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                // COUNTS label intentionally removed.
              ],
            ),
          ),

          // Bottom information.
          Expanded(
            flex: 27,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.72),
                    fontSize: width * 0.032,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (userName.isNotEmpty) ...[
                  SizedBox(height: height * 0.018),

                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.04,
                    ),
                    child: Text(
                      'Reciter: $userName',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: width * 0.070,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],

                SizedBox(height: height * 0.018),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '© ',
                        style: TextStyle(
                          fontSize: width * 0.023,
                          fontWeight: FontWeight.w400,
                          color: textColor.withValues(alpha: 0.45),
                        ),
                      ),
                      TextSpan(
                        text: 'App Developed by Muneeb',
                        style: TextStyle(
                          fontSize: width * 0.018,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
