
import 'dart:async';

import 'package:flutter/material.dart';

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

  int? selectedId;
  bool loading = true;
  bool drawerClosing = false;
  bool deleteDialogOpen = false;

  @override
  void initState() {
    super.initState();
    loadApp();
  }

  Future<void> loadApp() async {
    try {
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
        controllers[counter.id!] = TextEditingController(
          text: counter.name,
        );
      }

      final selectedExists = counters.any(
        (counter) => counter.id == savedSelectedId,
      );

      selectedId = selectedExists
          ? savedSelectedId
          : counters.first.id;

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
    return counters.firstWhere(
      (counter) => counter.id == selectedId,
    );
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

      controllers[counter.id!] = TextEditingController(
        text: counter.name,
      );

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

    final counter = counters.firstWhere(
      (item) => item.id == id,
    );

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

        controllers[newCounter.id!] = TextEditingController(
          text: newCounter.name,
        );

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

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    for (final timer in saveTimers.values) {
      timer.cancel();
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || counters.isEmpty || selectedId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF101827),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final current = currentCounter;
    final controller = controllers[current.id!]!;

    return Scaffold(
      backgroundColor: current.style.background,

      onDrawerChanged: (isOpened) {
        if (!isOpened) {
          drawerClosing = false;
        }
      },

      appBar: AppBar(
        backgroundColor: current.style.appBar,
        foregroundColor: current.style.text,
        title: Text(current.name),
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
      ),

      drawer: Drawer(
        backgroundColor: current.style.appBar,
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calculate,
                        size: 45,
                        color: current.style.accent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'MY COUNTERS',
                        style: TextStyle(
                          color: current.style.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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

                      leading: Icon(
                        Icons.calculate_outlined,
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
                        'Value: ${counter.count}',
                        style: const TextStyle(
                          color: Colors.white60,
                        ),
                      ),

                      onTap: () {
                        selectCounter(counter.id!, context);
                      },

                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          deleteCounter(counter.id!);
                        },
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
                  height: 55,
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton.icon(
                        onPressed: () => addCounter(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Counter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A68A),
                          foregroundColor: Colors.white,
                          elevation: 4,
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

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: current.style.text,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Enter counter name',
                hintStyle: const TextStyle(color: Colors.white54),
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
              onChanged: (value) {
                renameCounter(current, value);
              },
            ),

            const SizedBox(height: 65),

            Text(
              'CURRENT COUNT',
              style: TextStyle(
                color: current.style.text.withValues(alpha: 0.7),
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              '${current.count}',
              style: TextStyle(
                color: current.style.countColor,
                fontSize: 75,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: current.style.countColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 55),

            SizedBox(
              width: double.infinity,
              height: 75,
              child: ElevatedButton(
                onPressed: () {
                  if (current.count < 0x7FFFFFFFFFFFFFFF) {
                    changeCount(current.count + 1);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: current.style.accent,
                  foregroundColor: current.style.buttonText,
                  elevation: 8,
                  shape: const CircleBorder(),
                ),
                child: const Icon(
                  Icons.add,
                  size: 35,
                ),
              ),
            ),

            const SizedBox(height: 15),

            Text(
              'TAP TO INCREMENT',
              style: TextStyle(
                color: current.style.text.withValues(alpha: 0.6),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => changeCount(0),
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
