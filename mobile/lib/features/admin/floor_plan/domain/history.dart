import 'models.dart';

class DocHistory {
  DocHistory({this.limit = 80});

  final int limit;
  final List<FloorDoc> _past = [];
  final List<FloorDoc> _future = [];

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  void push(FloorDoc doc) {
    _past.add(doc.copy());
    if (_past.length > limit) _past.removeAt(0);
    _future.clear();
  }

  FloorDoc? undo(FloorDoc current) {
    if (_past.isEmpty) return null;
    _future.add(current.copy());
    return _past.removeLast();
  }

  FloorDoc? redo(FloorDoc current) {
    if (_future.isEmpty) return null;
    _past.add(current.copy());
    return _future.removeLast();
  }

  void clear() {
    _past.clear();
    _future.clear();
  }
}
