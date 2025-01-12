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

/// A reorderable dock widget that displays a list of items in a horizontal row.
///
/// The dock supports drag-and-drop reordering of items with smooth animations.
/// Each item is built using the provided [builder] function.
///
/// Example usage:
/// ```dart
/// Dock(
///   items: const [Icons.home, Icons.person, Icons.settings],
///   builder: (icon) => Icon(icon),
///   onReorder: (oldIndex, newIndex) {
///     // Handle reorder
///   },
/// )
/// ```
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

/// State for managing drag-and-drop reordering animations in the [Dock] widget.
///
/// Handles:
/// * Item dragging and dropping
/// * Position animations during reordering
/// * Scale animations for drag feedback
/// * Return-to-position animations after cancelled drags
class _DockState<T> extends State<Dock<T>> with SingleTickerProviderStateMixin {
  static const double _itemWidth = 64.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  late final List<T> _items = widget.items.toList();
  int? _dragIndex;
  int? _targetIndex;

  late final AnimationController _dragController;
  Offset? _dragOffset;
  int? _lastDragIndex;

  @override
  void initState() {
    super.initState();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  /// Calculates the horizontal offset for an item during reordering.
  ///
  /// Returns the offset in pixels that should be applied to the item at [index]
  /// based on the current drag operation.
  double _calculateOffset(int index) {
    // During return animation, all items should remain stationary
    if (_lastDragIndex != null) {
      return 0.0;
    }

    // Skip offset for the currently dragged item
    if (_dragIndex == null || _targetIndex == null || index == _dragIndex) {
      return 0.0;
    }

    final bool isMovingForward = _dragIndex! < _targetIndex!;
    final bool isInRange = isMovingForward
        ? index > _dragIndex! && index <= _targetIndex!
        : index < _dragIndex! && index >= _targetIndex!;

    return isInRange ? (isMovingForward ? -_itemWidth : _itemWidth) : 0.0;
  }

  /// Calculates the scale factor for an item during reordering.
  ///
  /// Returns a scale multiplier between 0.8 and 1.1 depending on whether
  /// the item is being dragged or is a drop target.
  double _calculateScale(int index) {
    if (_dragIndex == null || _targetIndex == null) return 1.0;
    if (_lastDragIndex != null) return 1.0;

    if (index == _targetIndex) return 1.1;
    if (index == _dragIndex) return 0.8;
    return 1.0;
  }

  /// Handles when a dragged item is dropped onto a new position.
  ///
  /// Updates the items list and calls [onReorder] callback if provided.
  void _handleDrop(int draggedIndex, int newIndex) {
    if (_dragController.isAnimating) {
      _dragController.stop();
    }

    final item = _items[draggedIndex];
    _items.removeAt(draggedIndex);
    _items.insert(newIndex, item);
    widget.onReorder?.call(draggedIndex, newIndex);

    setState(() {
      _dragIndex = null;
      _targetIndex = null;
      _dragOffset = null;
      _lastDragIndex = null;
    });
  }

  /// Handles the end of a drag operation.
  ///
  /// Manages the return animation if the drag was cancelled.
  void _handleDragEnd(DraggableDetails details) {
    if (_dragIndex == null) return;

    if (_targetIndex != null) {
      setState(() {
        _dragIndex = _targetIndex = null;
      });
      return;
    }

    final box = context.findRenderObject() as RenderBox;
    _lastDragIndex = _dragIndex;

    // Calculate the final position including velocity
    final endPosition =
        details.offset + details.velocity.pixelsPerSecond * 0.0166;
    _dragOffset = box.globalToLocal(endPosition) -
        Offset(_lastDragIndex! * _itemWidth, 0);

    setState(() => _dragIndex = null);

    _dragController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = null;
          _lastDragIndex = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
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

  /// Builds a single dock item at the specified [index].
  ///
  /// Wraps the item in drag target and handles animations during reordering.
  Widget _buildDockItem(int index) {
    final isLastDragged = index == _lastDragIndex;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (!isLastDragged) {
          setState(() => _targetIndex = index);
        }
        return true;
      },
      onLeave: (_) => setState(() => _targetIndex = null),
      onAcceptWithDetails: (details) => _handleDrop(details.data, index),
      builder: (context, candidateData, rejectedData) {
        Widget child = _buildDraggable(index);

        // Return animation
        if (isLastDragged && _dragOffset != null) {
          return AnimatedBuilder(
            animation: _dragController,
            builder: (context, child) {
              final progress = 1 - _dragController.value;
              final dragOffset = _dragOffset! * progress;
              return SizedBox(
                width: _itemWidth,
                child: Transform.translate(
                  offset: dragOffset,
                  child: child,
                ),
              );
            },
            child: child,
          );
        }

        // Dragging animation
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
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Builds a draggable item at the specified [index].
  ///
  /// Creates the drag feedback and handles drag start/end states.
  Widget _buildDraggable(int index) {
    return Draggable<int>(
      data: index,
      onDragStarted: () {
        setState(() {
          _dragIndex = index;
          _dragOffset = null;
          _lastDragIndex = null;
        });
      },
      onDragEnd: _handleDragEnd,
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
