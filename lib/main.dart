import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
    this.onReorder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  /// Callback called when items are reordered.
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T> extends State<Dock<T>> {
  static const double _itemWidth = 64.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  late final List<T> _items = widget.items.toList();
  int? _dragIndex;
  int? _targetIndex;

  double _calculateOffset(int index) {
    if (_dragIndex == null || _targetIndex == null) return 0.0;

    final isDraggedItem = index == _dragIndex;
    final isInDragRange = index > _dragIndex! && index <= _targetIndex!;
    final isInDropRange = index < _dragIndex! && index >= _targetIndex!;

    if (isDraggedItem) return 0.0;
    if (_dragIndex! < _targetIndex! && isInDragRange) return -_itemWidth;
    if (_dragIndex! > _targetIndex! && isInDropRange) return _itemWidth;
    return 0.0;
  }

  double _calculateScale(int index) {
    if (_dragIndex == null || _targetIndex == null) return 1.0;

    if (index == _targetIndex) return 1.1;
    if (index == _dragIndex) return 0.8;
    return 1.0;
  }

  void _handleDrop(int draggedIndex, int newIndex) {
    final item = _items.removeAt(draggedIndex);
    _items.insert(newIndex, item);
    widget.onReorder?.call(draggedIndex, newIndex);

    setState(() {
      _dragIndex = null;
      _targetIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_items.length, _buildDockItem),
        ),
      ),
    );
  }

  Widget _buildDockItem(int index) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _targetIndex = index);
        return true;
      },
      onLeave: (_) => setState(() => _targetIndex = null),
      onAcceptWithDetails: (details) => _handleDrop(details.data, index),
      builder: (context, candidateData, rejectedData) {
        return SizedBox(
          width: _itemWidth,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(_calculateOffset(index), 0.0)
              ..scale(_calculateScale(index)),
            child: Opacity(
              opacity: _dragIndex == index ? 0.0 : 1.0,
              child: _buildDraggable(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggable(int index) {
    return Draggable<int>(
      data: index,
      onDragStarted: () => setState(() => _dragIndex = index),
      onDragEnd: (_) => setState(() {
        _dragIndex = null;
        _targetIndex = null;
      }),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: widget.builder(_items[index]),
        ),
      ),
      childWhenDragging: const SizedBox(width: _itemWidth),
      child: widget.builder(_items[index]),
    );
  }
}
