import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/api/api_client.dart';
import '../data/floor_plan_repository.dart';
import '../domain/geometry.dart';
import '../domain/history.dart';
import '../domain/models.dart';

enum SaveMark { saved, saving, unsaved, failed }

class FloorEditor extends ChangeNotifier {
  FloorEditor(this._repo, this.restaurantId);

  final FloorPlanRepository _repo;
  final int restaurantId;
  final DocHistory _history = DocHistory();

  /// Bumped on every drag frame so the canvas can repaint without rebuilding chrome.
  final canvasGen = ValueNotifier<int>(0);

  List<FloorSummary> floors = [];
  FloorDoc? doc;
  final selected = <int>{};
  int? selectedZone;
  LayoutKind? placing;
  bool preview = false;
  bool snap = true;
  SaveMark save = SaveMark.saved;
  bool dirty = false;
  bool loading = true;
  String? error;
  List<AlignGuide> guides = [];
  int _nextId = -1;
  LayoutNode? clipboard;
  bool conflict = false;
  List<(int, String, String)> versions = [];

  List<LayoutWarning> get warnings {
    final d = doc;
    if (d == null) return const [];
    return layoutWarnings(
      objects: d.objects,
      floorW: d.widthCm,
      floorH: d.heightCm,
    );
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      floors = await _repo.list(restaurantId);
      if (floors.isEmpty) {
        doc = null;
      } else {
        await openFloor(floors.first.id);
      }
    } catch (e) {
      error = errorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> openFloor(int id) async {
    try {
      doc = await _repo.get(id);
      selected.clear();
      selectedZone = null;
      dirty = false;
      save = SaveMark.saved;
      conflict = false;
      error = null;
      _history.clear();
      notifyListeners();
      await refreshVersions();
    } catch (e) {
      error = errorMessage(e);
      notifyListeners();
    }
  }

  Future<void> createFloor({required String name, String? template}) async {
    final created = await _repo.create(
      restaurantId,
      name: name,
      template: template,
    );
    floors = await _repo.list(restaurantId);
    doc = created;
    selected.clear();
    selectedZone = null;
    dirty = false;
    save = SaveMark.saved;
    conflict = false;
    _history.clear();
    notifyListeners();
    await refreshVersions();
  }

  Future<void> renameFloor(String name) async {
    final d = doc;
    if (d == null) return;
    await _repo.rename(d.id, name);
    d.name = name;
    floors = await _repo.list(restaurantId);
    notifyListeners();
  }

  Future<void> deleteFloor() async {
    final d = doc;
    if (d == null) return;
    await _repo.delete(d.id);
    await load();
  }

  Future<void> duplicateFloor() async {
    final d = doc;
    if (d == null) return;
    final copy = await _repo.duplicate(d.id);
    floors = await _repo.list(restaurantId);
    doc = copy;
    selected.clear();
    dirty = false;
    save = SaveMark.saved;
    _history.clear();
    notifyListeners();
    await refreshVersions();
  }

  Future<void> refreshVersions() async {
    final d = doc;
    if (d == null) return;
    try {
      versions = await _repo.versions(d.id);
      notifyListeners();
    } catch (_) {
      // History is optional; the editor still works without it.
    }
  }

  Future<void> restoreVersion(int versionId) async {
    final d = doc;
    if (d == null) return;
    doc = await _repo.restore(d.id, versionId);
    selected.clear();
    dirty = false;
    save = SaveMark.saved;
    conflict = false;
    _history.clear();
    notifyListeners();
    await refreshVersions();
  }

  void _commit() {
    final d = doc;
    if (d == null) return;
    _history.push(d);
    dirty = true;
    save = SaveMark.unsaved;
  }

  void undo() {
    final d = doc;
    if (d == null) return;
    final prev = _history.undo(d);
    if (prev == null) return;
    doc = prev;
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void redo() {
    final d = doc;
    if (d == null) return;
    final next = _history.redo(d);
    if (next == null) return;
    doc = next;
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  String? _groupOf(LayoutNode n) {
    final g = n.extra['group'];
    return g is String && g.isNotEmpty ? g : n.mergeGroup;
  }

  void select(int id, {bool additive = false}) {
    selectedZone = null;
    if (!additive) {
      selected
        ..clear()
        ..add(id);
      final n = _byId(id);
      final group = n == null ? null : _groupOf(n);
      if (group != null && doc != null) {
        selected.addAll([
          for (final o in doc!.objects)
            if (_groupOf(o) == group) o.id,
        ]);
      }
    } else if (!selected.add(id)) {
      selected.remove(id);
    }
    placing = null;
    notifyListeners();
  }

  void selectOnly(Set<int> ids) {
    selected
      ..clear()
      ..addAll(ids);
    selectedZone = null;
    placing = null;
    notifyListeners();
  }

  void selectZone(int? id) {
    selectedZone = id;
    selected.clear();
    placing = null;
    notifyListeners();
  }

  void deselect() {
    selected.clear();
    selectedZone = null;
    placing = null;
    notifyListeners();
  }

  void setPlacing(LayoutKind? kind) {
    placing = kind;
    selected.clear();
    selectedZone = null;
    notifyListeners();
  }

  LayoutNode? get primary {
    if (selected.isEmpty) return null;
    return _byId(selected.first);
  }

  LayoutZone? get primaryZone {
    final id = selectedZone;
    if (id == null || doc == null) return null;
    for (final z in doc!.zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  void placeAt(double x, double y) {
    final d = doc;
    final kind = placing;
    if (d == null || kind == null) return;
    _commit();
    final size = kind.defaultSize;
    final gx = snap
        ? snapValue(x - size.w / 2, d.gridCm.toDouble())
        : x - size.w / 2;
    final gy = snap
        ? snapValue(y - size.h / 2, d.gridCm.toDouble())
        : y - size.h / 2;
    final n = LayoutNode(
      id: _nextId--,
      kind: kind,
      name: kind.isTable ? _nextTableName(d) : kind.label,
      x: gx,
      y: gy,
      width: size.w,
      height: size.h,
      capacity: kind.defaultCapacity,
      minGuests: kind.isTable ? 1 : null,
      maxGuests: kind.defaultCapacity,
      zoneId: selectedZone ?? _zoneAt(d, gx + size.w / 2, gy + size.h / 2),
    );
    d.objects.add(n);
    selected
      ..clear()
      ..add(n.id);
    placing = null;
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  int? _zoneAt(FloorDoc d, double x, double y) {
    for (final z in d.zones.reversed) {
      if (z.rect.containsPoint(x, y)) return z.id;
    }
    return null;
  }

  String _nextTableName(FloorDoc d) {
    final nums = d.objects
        .where((o) => o.kind.isTable)
        .map((o) => int.tryParse(o.name) ?? 0);
    final max = nums.isEmpty ? 11 : nums.reduce((a, b) => a > b ? a : b);
    return '${max + 1}';
  }

  void beginEdit() {
    _commit();
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void moveSelectedTo(int id, double x, double y) {
    final d = doc;
    if (d == null) return;
    LayoutNode? n;
    for (final o in d.objects) {
      if (o.id == id) n = o;
    }
    if (n == null) return;
    final rest = [
      for (final o in d.objects)
        if (o.id != id) o.rect,
    ];
    final snapped = snapMove(
      moving: LayoutRect(x, y, n.width, n.height),
      others: rest,
      grid: d.gridCm.toDouble(),
      snapGrid: snap,
    );
    final dx = snapped.x - n.x;
    final dy = snapped.y - n.y;
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      if (o.id == id) {
        o.x = snapped.x;
        o.y = snapped.y;
      } else {
        o.x += dx;
        o.y += dy;
      }
    }
    guides = snapped.guides;
    dirty = true;
    save = SaveMark.unsaved;
    canvasGen.value++;
  }

  void moveZoneTo(int id, double x, double y) {
    final z = primaryZone;
    if (z == null || z.id != id) return;
    final g = doc?.gridCm.toDouble() ?? 40;
    z.x = snap ? snapValue(x, g) : x;
    z.y = snap ? snapValue(y, g) : y;
    dirty = true;
    save = SaveMark.unsaved;
    canvasGen.value++;
  }

  void applyRect(int id, double x, double y, double w, double h) {
    final n = _byId(id);
    if (n == null) return;
    final g = doc?.gridCm.toDouble() ?? 40;
    n.x = snap ? snapValue(x, g) : x;
    n.y = snap ? snapValue(y, g) : y;
    n.width = (snap ? snapValue(w, g) : w).clamp(16, 2000);
    n.height = (snap ? snapValue(h, g) : h).clamp(16, 2000);
    dirty = true;
    save = SaveMark.unsaved;
    canvasGen.value++;
  }

  void resize(int id, double w, double h) {
    final n = _byId(id);
    if (n == null) return;
    n.width = w.clamp(16, 2000);
    n.height = h.clamp(16, 2000);
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void rotate(int id, double deg) {
    final n = _byId(id);
    if (n == null) return;
    var v = ((deg % 360) + 360) % 360;
    if (snap) v = (v / 15).round() * 15.0;
    n.rotation = v;
    dirty = true;
    save = SaveMark.unsaved;
    canvasGen.value++;
  }

  void endGesture() {
    guides = [];
    canvasGen.value++;
    notifyListeners();
  }

  void deleteSelected() {
    final d = doc;
    if (d == null) return;
    if (selectedZone != null && selected.isEmpty) {
      _commit();
      d.zones.removeWhere((z) => z.id == selectedZone);
      for (final o in d.objects) {
        if (o.zoneId == selectedZone) o.zoneId = null;
      }
      selectedZone = null;
      dirty = true;
      save = SaveMark.unsaved;
      notifyListeners();
      return;
    }
    if (selected.isEmpty) return;
    _commit();
    d.objects.removeWhere((o) => selected.contains(o.id));
    selected.clear();
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void duplicateSelected() {
    final d = doc;
    if (d == null || selected.isEmpty) return;
    _commit();
    final copies = <LayoutNode>[];
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      final c = o.copy()
        ..id = _nextId--
        ..x = o.x + 40
        ..y = o.y + 40
        ..name = o.kind.isTable ? _nextTableName(d) : o.name;
      copies.add(c);
    }
    d.objects.addAll(copies);
    selected
      ..clear()
      ..addAll(copies.map((c) => c.id));
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void copySelected() {
    clipboard = primary?.copy();
  }

  void paste() {
    final d = doc;
    final clip = clipboard;
    if (d == null || clip == null) return;
    _commit();
    final c = clip.copy()
      ..id = _nextId--
      ..x = clip.x + 40
      ..y = clip.y + 40
      ..name = clip.kind.isTable ? _nextTableName(d) : clip.name;
    d.objects.add(c);
    selected
      ..clear()
      ..add(c.id);
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void mergeSelected() {
    final d = doc;
    if (d == null || selected.length < 2) return;
    _commit();
    final group = 'g${DateTime.now().millisecondsSinceEpoch}';
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      o.mergeable = true;
      o.mergeGroup = group;
    }
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void unmergeSelected() {
    final d = doc;
    if (d == null) return;
    _commit();
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      o.mergeGroup = null;
    }
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void groupSelected() {
    final d = doc;
    if (d == null || selected.length < 2) return;
    _commit();
    final group = 'grp${DateTime.now().millisecondsSinceEpoch}';
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      o.extra = {...o.extra, 'group': group};
    }
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void ungroupSelected() {
    final d = doc;
    if (d == null) return;
    _commit();
    for (final o in d.objects.where((o) => selected.contains(o.id))) {
      final next = Map<String, dynamic>.from(o.extra)..remove('group');
      o.extra = next;
    }
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void applyAlign(void Function(List<LayoutNode>) fn) {
    final d = doc;
    if (d == null || selected.length < 2) return;
    _commit();
    fn(d.objects.where((o) => selected.contains(o.id)).toList());
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void patchPrimary(void Function(LayoutNode n) fn) {
    final n = primary;
    if (n == null) return;
    _commit();
    fn(n);
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void patchZone(void Function(LayoutZone z) fn) {
    final z = primaryZone;
    if (z == null) return;
    _commit();
    fn(z);
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void addZone(ZoneKind kind) {
    final d = doc;
    if (d == null) return;
    _commit();
    final z = LayoutZone(
      id: _nextId--,
      name: kind.label,
      kind: kind,
      color: kind.tint,
      x: 80,
      y: 80,
      width: 600,
      height: 400,
    );
    d.zones.add(z);
    selectedZone = z.id;
    selected.clear();
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  void togglePreview() {
    preview = !preview;
    placing = null;
    notifyListeners();
  }

  void toggleSnap() {
    snap = !snap;
    notifyListeners();
  }

  void setGrid(int cm) {
    final d = doc;
    if (d == null) return;
    d.gridCm = cm;
    dirty = true;
    save = SaveMark.unsaved;
    notifyListeners();
  }

  Future<void> persist() async {
    final d = doc;
    if (d == null) return;
    save = SaveMark.saving;
    error = null;
    conflict = false;
    notifyListeners();
    try {
      doc = await _repo.save(d);
      floors = await _repo.list(restaurantId);
      selected.clear();
      dirty = false;
      save = SaveMark.saved;
      _history.clear();
      await refreshVersions();
    } catch (e) {
      save = SaveMark.failed;
      conflict = _statusCode(e) == 409;
      error = errorMessage(e);
    }
    notifyListeners();
  }

  Future<void> reloadFromServer() async {
    final d = doc;
    if (d == null) return;
    await openFloor(d.id);
  }

  int? _statusCode(Object e) {
    if (e is ApiException) return e.statusCode;
    if (e is DioException) {
      if (e.error is ApiException) return (e.error as ApiException).statusCode;
      return e.response?.statusCode;
    }
    return null;
  }

  LayoutNode? _byId(int id) {
    final d = doc;
    if (d == null) return null;
    for (final o in d.objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  void dispose() {
    canvasGen.dispose();
    super.dispose();
  }
}

final floorEditorProvider = ChangeNotifierProvider.autoDispose
    .family<FloorEditor, int>((ref, id) {
      final editor = FloorEditor(
        FloorPlanRepository(ref.watch(dioProvider)),
        id,
      );
      editor.load();
      return editor;
    });
