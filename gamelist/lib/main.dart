import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ===================== MODELOS =====================

class Game {
  final String id;
  String title;
  String platform; // Ex.: PS2, Wii, PC...
  List<String> statuses; // Ex.: Jogando, Zerado...
  List<String> devices; // Ex.: PC, Odin, TV, Quest 3s...
  String notes;
  String coverUrl; // URL da capa (opcional)

  Game({
    required this.id,
    required this.title,
    required this.platform,
    required this.statuses,
    required this.devices,
    required this.notes,
    required this.coverUrl,
  });

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        platform: j['platform'] as String? ?? 'PC',
        statuses: (j['statuses'] as List?)?.cast<String>() ?? <String>[],
        devices: (j['devices'] as List?)?.cast<String>() ?? <String>[],
        notes: j['notes'] as String? ?? '',
        coverUrl: j['coverUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'platform': platform,
        'statuses': statuses,
        'devices': devices,
        'notes': notes,
        'coverUrl': coverUrl,
      };
}

class Goal {
  final String id;
  String title;
  int targetCount;
  String? platform; // filtro opcional
  String? status;
  String? device;

  Goal({
    required this.id,
    required this.title,
    required this.targetCount,
    this.platform,
    this.status,
    this.device,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        targetCount: (j['targetCount'] as num?)?.toInt() ?? 0,
        platform: j['platform'] as String?,
        status: j['status'] as String?,
        device: j['device'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetCount': targetCount,
        'platform': platform,
        'status': status,
        'device': device,
      };
}

class GameApiInfo {
  final String name;
  final String? description;
  final String? imageUrl;

  GameApiInfo({
    required this.name,
    this.description,
    this.imageUrl,
  });
}

// ===================== SERVIÇO DE API (RAWG) =====================

class GameApiService {
  // Coloque sua API key do RAWG aqui:
  // Crie uma conta em https://rawg.io/apidocs e gere a key.
  static const String _apiKey = '9d5b6ed5d1e94a9e9f7536389a4e4032';

  static Future<GameApiInfo?> fetchInfo(String query) async {
    if (_apiKey.isEmpty) return null;
    try {
      final listUri = Uri.https(
        'api.rawg.io',
        '/api/games',
        {
          'key': _apiKey,
          'search': query,
          'page_size': '1',
        },
      );
      final listRes = await http.get(listUri);
      if (listRes.statusCode != 200) return null;

      final listData = jsonDecode(listRes.body) as Map<String, dynamic>;
      final results = listData['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final id = first['id'];
      final name = first['name'] as String? ?? query;
      final image = first['background_image'] as String?;

      String? description;

      if (id != null) {
        final detailUri = Uri.https(
          'api.rawg.io',
          '/api/games/$id',
          {'key': _apiKey},
        );
        final detailRes = await http.get(detailUri);
        if (detailRes.statusCode == 200) {
          final detailData = jsonDecode(detailRes.body) as Map<String, dynamic>;
          description = detailData['description_raw'] as String?;
        }
      }

      return GameApiInfo(
        name: name,
        description: description,
        imageUrl: image,
      );
    } catch (_) {
      return null;
    }
  }
}

// ===================== ESTADO / PERSISTÊNCIA =====================

class AppState extends ChangeNotifier {
  static const _kKeyGames = 'bp_games';
  static const _kKeyPlatforms = 'bp_platforms';
  static const _kKeyStatuses = 'bp_statuses';
  static const _kKeyDevices = 'bp_devices';
  static const _kKeyGoals = 'bp_goals';

  final List<Game> games = [];
  final List<String> platforms = [];
  final List<String> statuses = [];
  final List<String> devices = [];
  final List<Goal> goals = [];

  bool initialized = false;

  Future<void> init() async {
    if (initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final gamesJson = prefs.getString(_kKeyGames);
    if (gamesJson != null) {
      final list = (jsonDecode(gamesJson) as List).cast<Map>();
      games
        ..clear()
        ..addAll(list.map((e) => Game.fromJson(e.cast<String, dynamic>())).toList());
    }

    final platformsJson = prefs.getStringList(_kKeyPlatforms);
    final statusesJson = prefs.getStringList(_kKeyStatuses);
    final devicesJson = prefs.getStringList(_kKeyDevices);
    final goalsJson = prefs.getString(_kKeyGoals);

    platforms
      ..clear()
      ..addAll(platformsJson ?? [
        'PS2',
        'Wii',
        'Wii U',
        'GameCube',
        'Switch',
        '3DS',
        'PC',
        'Retro',
        'Emulação',
      ]);

    statuses
      ..clear()
      ..addAll(statusesJson ?? [
        'Quero jogar',
        'Jogando',
        'Zerado',
        'Platinado',
        'Abandonado',
        'Rejogando',
        'Wishlist',
        'Tenho físico',
        'Tenho digital',
        'Instalado',
      ]);

    devices
      ..clear()
      ..addAll(devicesJson ?? [
        'Todos',
        'PC',
        'Odin',
        'TV',
        'Quest 3s',
        'Outro...',
      ]);

    if (goalsJson != null) {
      final list = (jsonDecode(goalsJson) as List).cast<Map>();
      goals
        ..clear()
        ..addAll(list.map((e) => Goal.fromJson(e.cast<String, dynamic>())).toList());
    }

    initialized = true;
    notifyListeners();
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKeyGames, jsonEncode(games.map((e) => e.toJson()).toList()));
    await prefs.setStringList(_kKeyPlatforms, platforms);
    await prefs.setStringList(_kKeyStatuses, statuses);
    await prefs.setStringList(_kKeyDevices, devices);
    await prefs.setString(_kKeyGoals, jsonEncode(goals.map((e) => e.toJson()).toList()));
  }

  // ----------------- Jogos -----------------
  void addGame(Game g) {
    games.add(g);
    _saveAll();
    notifyListeners();
  }

  void updateGame(Game g) {
    final idx = games.indexWhere((x) => x.id == g.id);
    if (idx != -1) {
      games[idx] = g;
      _saveAll();
      notifyListeners();
    }
  }

  void deleteGame(String id) {
    games.removeWhere((x) => x.id == id);
    _saveAll();
    notifyListeners();
  }

  // ----------------- Listas editáveis -----------------
  void addPlatform(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!platforms.contains(n)) {
      platforms.add(n);
      _saveAll();
      notifyListeners();
    }
  }

  void removePlatform(String name) {
    platforms.remove(name);
    _saveAll();
    notifyListeners();
  }

  void addStatus(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!statuses.contains(n)) {
      statuses.add(n);
      _saveAll();
      notifyListeners();
    }
  }

  void removeStatus(String name) {
    statuses.remove(name);
    _saveAll();
    notifyListeners();
  }

  void addDevice(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!devices.contains(n)) {
      devices.add(n);
      _saveAll();
      notifyListeners();
    }
  }

  void removeDevice(String name) {
    devices.remove(name);
    _saveAll();
    notifyListeners();
  }

  // ----------------- Metas -----------------
  void addGoal(Goal g) {
    goals.add(g);
    _saveAll();
    notifyListeners();
  }

  void updateGoal(Goal g) {
    final idx = goals.indexWhere((x) => x.id == g.id);
    if (idx != -1) {
      goals[idx] = g;
      _saveAll();
      notifyListeners();
    }
  }

  void deleteGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    _saveAll();
    notifyListeners();
  }

  int countGamesForGoal(Goal goal) {
    return games.where((g) {
      final matchPlatform = goal.platform == null || g.platform == goal.platform;
      final matchStatus = goal.status == null || g.statuses.contains(goal.status);
      final matchDevice = goal.device == null || g.devices.contains(goal.device);
      return matchPlatform && matchStatus && matchDevice;
    }).length;
  }

  // ----------------- Backup -----------------
  String exportBackupAsJson() {
    final data = {
      'games': games.map((e) => e.toJson()).toList(),
      'platforms': platforms,
      'statuses': statuses,
      'devices': devices,
      'goals': goals.map((e) => e.toJson()).toList(),
      'version': 2,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String?> importBackupFromJson(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final g = (data['games'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final p = (data['platforms'] as List?)?.cast<String>() ?? [];
      final s = (data['statuses'] as List?)?.cast<String>() ?? [];
      final d = (data['devices'] as List?)?.cast<String>() ?? [];
      final goalsData = (data['goals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      games
        ..clear()
        ..addAll(g.map(Game.fromJson));
      if (p.isNotEmpty) {
        platforms
          ..clear()
          ..addAll(p);
      }
      if (s.isNotEmpty) {
        statuses
          ..clear()
          ..addAll(s);
      }
      if (d.isNotEmpty) {
        devices
          ..clear()
          ..addAll(d);
      }
      goals
        ..clear()
        ..addAll(goalsData.map(Goal.fromJson));

      await _saveAll();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// ===================== APP =====================

void main() {
  runApp(const GameListApp());
}

class GameListApp extends StatefulWidget {
  const GameListApp({super.key});

  @override
  State<GameListApp> createState() => _GameListAppState();
}

class _GameListAppState extends State<GameListApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GameList',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
            fontFamily: 'SF Pro Text',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            fontFamily: 'SF Pro Text',
          ),
          home: HomePage(state: state),
        );
      },
    );
  }
}

// ===================== TELAS =====================

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      GamesPage(state: widget.state),
      GoalsPage(state: widget.state),
      SettingsPage(state: widget.state),
    ];

    final titles = ['GameList', 'Metas', 'Configurações'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        centerTitle: true,
      ),
      body: tabs[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.videogame_asset_outlined), label: 'Jogos'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Metas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Config'),
        ],
        onDestinationSelected: (i) => setState(() => index = i),
      ),
    );
  }
}

// ----------------- Tela de Jogos -----------------

class GamesPage extends StatefulWidget {
  final AppState state;
  const GamesPage({super.key, required this.state});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  String search = '';
  String? selectedDevice; // null = Todos

  bool selectionMode = false;
  final Set<String> selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final games = widget.state.games.where((g) {
      final matchSearch = search.isEmpty || g.title.toLowerCase().contains(search.toLowerCase());
      final matchDevice = selectedDevice == null || g.devices.contains(selectedDevice) || selectedDevice == 'Todos';
      return matchSearch && matchDevice;
    }).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final deviceOptions = widget.state.devices;
    final currentSegment = selectedDevice ?? 'Todos';

    return Column(
      children: [
        // Device segmented control (iOS-like)
        if (deviceOptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: CupertinoSegmentedControl<String>(
              groupValue: currentSegment,
              children: {
                for (final d in deviceOptions) d: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(d, style: const TextStyle(fontSize: 12)),
                ),
              },
              onValueChanged: (val) {
                setState(() {
                  selectedDevice = val == 'Todos' ? null : val;
                });
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar jogo...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: selectionMode ? 'Sair do modo de seleção' : 'Selecionar vários',
                icon: Icon(selectionMode ? Icons.check_box : Icons.check_box_outline_blank),
                onPressed: () {
                  setState(() {
                    selectionMode = !selectionMode;
                    if (!selectionMode) selectedIds.clear();
                  });
                },
              ),
            ],
          ),
        ),
        if (selectionMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  selectedIds.isEmpty
                      ? 'Nenhum jogo selecionado'
                      : '${selectedIds.length} selecionado(s)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.devices_outlined, size: 18),
                  label: const Text('Definir dispositivos'),
                  onPressed: selectedIds.isEmpty ? null : _batchSetDevices,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.checklist_outlined, size: 18),
                  label: const Text('Definir status'),
                  onPressed: selectedIds.isEmpty ? null : _batchSetStatuses,
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, i) {
              final g = games[i];
              final isSelected = selectedIds.contains(g.id);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: selectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(g.id),
                        )
                      : (g.coverUrl.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(g.coverUrl),
                            )
                          : CircleAvatar(
                              child: Text(
                                g.title.isNotEmpty ? g.title.characters.first.toUpperCase() : '?',
                              ),
                            )),
                  title: Text(g.title),
                  subtitle: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _pill(g.platform, Icons.apps),
                      ...g.statuses.map((s) => _pill(s, Icons.check_circle_outline)),
                      if (g.devices.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: g.devices.map((d) => _pill(d, Icons.devices_outlined)).toList(),
                        ),
                    ],
                  ),
                  onTap: () async {
                    if (selectionMode) {
                      _toggleSelection(g.id);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditGamePage(state: widget.state, game: g)),
                      );
                      setState(() {});
                    }
                  },
                  onLongPress: () {
                    if (!selectionMode) {
                      setState(() {
                        selectionMode = true;
                        selectedIds.clear();
                        selectedIds.add(g.id);
                      });
                    }
                  },
                  trailing: !selectionMode
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(g),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Adicionar jogo'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditGamePage(state: widget.state)),
                  );
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text),
        ],
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  void _confirmDelete(Game g) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover jogo'),
        content: Text('Tem certeza que deseja remover "${g.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              widget.state.deleteGame(g.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchSetDevices() async {
    final selected = Set<String>.from(selectedIds);
    if (selected.isEmpty) return;

    final chosen = await _showMultiChoiceDialog(
      title: 'Selecionar dispositivos',
      options: widget.state.devices.where((d) => d != 'Todos').toList(),
    );
    if (chosen == null) return;

    for (final id in selected) {
      final idx = widget.state.games.indexWhere((g) => g.id == id);
      if (idx == -1) continue;
      final g = widget.state.games[idx];
      final newDevices = {...g.devices, ...chosen}.toList();
      final updated = Game(
        id: g.id,
        title: g.title,
        platform: g.platform,
        statuses: g.statuses,
        devices: newDevices,
        notes: g.notes,
        coverUrl: g.coverUrl,
      );
      widget.state.updateGame(updated);
    }
    setState(() {});
  }

  Future<void> _batchSetStatuses() async {
    final selected = Set<String>.from(selectedIds);
    if (selected.isEmpty) return;

    final chosen = await _showMultiChoiceDialog(
      title: 'Selecionar status',
      options: widget.state.statuses,
    );
    if (chosen == null) return;

    for (final id in selected) {
      final idx = widget.state.games.indexWhere((g) => g.id == id);
      if (idx == -1) continue;
      final g = widget.state.games[idx];
      final newStatuses = {...g.statuses, ...chosen}.toList();
      final updated = Game(
        id: g.id,
        title: g.title,
        platform: g.platform,
        statuses: newStatuses,
        devices: g.devices,
        notes: g.notes,
        coverUrl: g.coverUrl,
      );
      widget.state.updateGame(updated);
    }
    setState(() {});
  }

  Future<Set<String>?> _showMultiChoiceDialog({
    required String title,
    required List<String> options,
  }) async {
    final selected = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map((o) => CheckboxListTile(
                          title: Text(o),
                          value: selected.contains(o),
                          onChanged: (v) {
                            setSt(() {
                              if (v == true) {
                                selected.add(o);
                              } else {
                                selected.remove(o);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == true && selected.isNotEmpty) {
      return selected;
    }
    return null;
  }
}

// ----------------- Tela de Edição de Jogo -----------------

class EditGamePage extends StatefulWidget {
  final AppState state;
  final Game? game;

  const EditGamePage({super.key, required this.state, this.game});

  @override
  State<EditGamePage> createState() => _EditGamePageState();
}

class _EditGamePageState extends State<EditGamePage> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _notes;
  String? _platform;
  final Set<String> _statusesSel = {};
  final Set<String> _devicesSel = {};
  String _coverUrl = '';
  bool _loadingApi = false;

  @override
  void initState() {
    super.initState();
    final g = widget.game;
    _title = TextEditingController(text: g?.title ?? '');
    _notes = TextEditingController(text: g?.notes ?? '');
    _platform = g?.platform;
    _statusesSel.addAll(g?.statuses ?? []);
    _devicesSel.addAll(g?.devices ?? []);
    _coverUrl = g?.coverUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game == null ? 'Novo jogo' : 'Editar jogo'),
        actions: [
          IconButton(
            tooltip: 'Buscar info online',
            icon: _loadingApi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            onPressed: _loadingApi ? null : _fetchFromApi,
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_coverUrl.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _coverUrl,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (_coverUrl.isNotEmpty) const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título do jogo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o título' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _platform,
                    decoration: const InputDecoration(labelText: 'Plataforma'),
                    items: widget.state.platforms
                        .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _platform = v),
                    validator: (v) => v == null ? 'Selecione a plataforma' : null,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nova plataforma'),
                  onPressed: () => _promptAddPlatform(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.state.statuses.map((s) => FilterChip(
                      label: Text(s),
                      selected: _statusesSel.contains(s),
                      onSelected: (sel) =>
                          setState(() => sel ? _statusesSel.add(s) : _statusesSel.remove(s)),
                    )),
                ActionChip(
                  label: const Text('Novo status'),
                  avatar: const Icon(Icons.add, size: 18),
                  onPressed: _promptAddStatus,
                )
              ],
            ),
            const SizedBox(height: 16),
            const Text('Onde pretende jogar?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.state.devices.where((d) => d != 'Todos').map(
                      (d) => FilterChip(
                        label: Text(d),
                        selected: _devicesSel.contains(d),
                        onSelected: (sel) =>
                            setState(() => sel ? _devicesSel.add(d) : _devicesSel.remove(d)),
                      ),
                    ),
                ActionChip(
                  label: const Text('Novo dispositivo'),
                  avatar: const Icon(Icons.add, size: 18),
                  onPressed: _promptAddDevice,
                )
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notas pessoais / sinopse',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              minLines: 4,
              maxLines: 10,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final nowId = widget.game?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final g = Game(
      id: nowId,
      title: _title.text.trim(),
      platform: _platform!,
      statuses: _statusesSel.toList(),
      devices: _devicesSel.toList(),
      notes: _notes.text,
      coverUrl: _coverUrl,
    );

    if (widget.game == null) {
      widget.state.addGame(g);
    } else {
      widget.state.updateGame(g);
    }
    Navigator.pop(context);
  }

  Future<void> _fetchFromApi() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um título para buscar.')),
      );
      return;
    }
    setState(() => _loadingApi = true);
    final info = await GameApiService.fetchInfo(title);
    setState(() => _loadingApi = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter dados da API. Verifique a API key.')),
      );
      return;
    }

    setState(() {
      _title.text = info.name;
      if ((info.description ?? '').isNotEmpty) {
        _notes.text = info.description!;
      }
      if ((info.imageUrl ?? '').isNotEmpty) {
        _coverUrl = info.imageUrl!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados preenchidos com sucesso!')),
    );
  }

  Future<void> _promptAddPlatform() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova plataforma'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Ex.: PS5, PSP, Mega Drive...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      setState(() {
        widget.state.addPlatform(c.text.trim());
        _platform ??= c.text.trim();
      });
    }
  }

  Future<void> _promptAddStatus() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo status'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Ex.: Em pausa, Co-op, Speedrun...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      setState(() {
        widget.state.addStatus(c.text.trim());
        _statusesSel.add(c.text.trim());
      });
    }
  }

  Future<void> _promptAddDevice() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Novo dispositivo'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Ex.: Steam Deck, Notebook, Cloud...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      setState(() {
        widget.state.addDevice(c.text.trim());
        _devicesSel.add(c.text.trim());
      });
    }
  }
}

// ----------------- Tela de Metas -----------------

class GoalsPage extends StatefulWidget {
  final AppState state;
  const GoalsPage({super.key, required this.state});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  @override
  Widget build(BuildContext context) {
    final goals = widget.state.goals;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final g = goals[index];
              final count = widget.state.countGamesForGoal(g);
              final progress = g.targetCount == 0 ? 0.0 : (count / g.targetCount).clamp(0.0, 1.0);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(g.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text('$count / ${g.targetCount} jogos'),
                      if (g.platform != null || g.status != null || g.device != null)
                        Text(
                          [
                            if (g.platform != null) 'Plataforma: ${g.platform}',
                            if (g.status != null) 'Status: ${g.status}',
                            if (g.device != null) 'Dispositivo: ${g.device}',
                          ].join(' | '),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditGoalPage(state: widget.state, goal: g),
                      ),
                    );
                    setState(() {});
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(g),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nova meta'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditGoalPage(state: widget.state),
                    ),
                  );
                  setState(() {});
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(Goal g) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover meta'),
        content: Text('Tem certeza que deseja remover "${g.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              widget.state.deleteGoal(g.id);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

class EditGoalPage extends StatefulWidget {
  final AppState state;
  final Goal? goal;

  const EditGoalPage({super.key, required this.state, this.goal});

  @override
  State<EditGoalPage> createState() => _EditGoalPageState();
}

class _EditGoalPageState extends State<EditGoalPage> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _target;
  String? _platform;
  String? _status;
  String? _device;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _title = TextEditingController(text: g?.title ?? '');
    _target = TextEditingController(text: g?.targetCount.toString() ?? '1');
    _platform = g?.platform;
    _status = g?.status;
    _device = g?.device;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal == null ? 'Nova meta' : 'Editar meta'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título da meta'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade de jogos'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe um número';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return 'Número inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Filtro (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _platform,
              decoration: const InputDecoration(labelText: 'Plataforma'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Todas')),
                ...widget.state.platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))),
              ],
              onChanged: (v) => setState(() => _platform = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ...widget.state.statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _device,
              decoration: const InputDecoration(labelText: 'Dispositivo'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Todos')),
                ...widget.state.devices.where((d) => d != 'Todos').map(
                      (d) => DropdownMenuItem(value: d, child: Text(d)),
                    ),
              ],
              onChanged: (v) => setState(() => _device = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Salvar meta'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final id = widget.goal?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final goal = Goal(
      id: id,
      title: _title.text.trim(),
      targetCount: int.parse(_target.text.trim()),
      platform: _platform,
      status: _status,
      device: _device,
    );
    if (widget.goal == null) {
      widget.state.addGoal(goal);
    } else {
      widget.state.updateGoal(goal);
    }
    Navigator.pop(context);
  }
}

// ----------------- Tela de Configurações -----------------

class SettingsPage extends StatefulWidget {
  final AppState state;
  const SettingsPage({super.key, required this.state});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _backupCtrl = TextEditingController();

  @override
  void dispose() {
    _backupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Gerenciar listas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _sectionEditableList('Plataformas', widget.state.platforms, onAdd: (v) {
          widget.state.addPlatform(v);
          setState(() {});
        }, onRemove: (v) {
          widget.state.removePlatform(v);
          setState(() {});
        }),
        const SizedBox(height: 12),
        _sectionEditableList('Status', widget.state.statuses, onAdd: (v) {
          widget.state.addStatus(v);
          setState(() {});
        }, onRemove: (v) {
          widget.state.removeStatus(v);
          setState(() {});
        }),
        const SizedBox(height: 12),
        _sectionEditableList('Dispositivos', widget.state.devices, onAdd: (v) {
          widget.state.addDevice(v);
          setState(() {});
        }, onRemove: (v) {
          widget.state.removeDevice(v);
          setState(() {});
        }),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Backup (JSON)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Exportar (copiar)'),
              onPressed: () {
                final data = widget.state.exportBackupAsJson();
                _backupCtrl.text = data;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup gerado abaixo. Selecione e copie.')),
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Importar (colando)'),
              onPressed: () async {
                final err = await widget.state.importBackupFromJson(_backupCtrl.text);
                if (err == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup importado com sucesso!')),
                    );
                    setState(() {});
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Falha ao importar: $err')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _backupCtrl,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Aqui aparecerá o JSON do backup.\nPara importar, cole seu backup aqui e toque em "Importar".',
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Observação: este app é 100% offline. A API online só é usada quando você toca em "Buscar info online" na tela de edição de jogo.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _sectionEditableList(
    String title,
    List<String> items, {
    required void Function(String) onAdd,
    required void Function(String) onRemove,
  }) {
    final c = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...items.map((e) => Chip(
                      label: Text(e),
                      onDeleted: () => onRemove(e),
                    )),
                SizedBox(
                  width: 220,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: c,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Adicionar...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          if (c.text.trim().isNotEmpty) {
                            onAdd(c.text.trim());
                            c.clear();
                          }
                        },
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
