// Lazy loading list implementation.
// Pattern: Lazy Load Pattern with Virtual Scrolling.
// Single Responsibility: Efficient list rendering.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lazy loading list view with pagination
class LazyLoadListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) loadMore;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final int pageSize;
  final double loadThreshold;
  final bool enablePullToRefresh;
  
  const LazyLoadListView({
    super.key,
    required this.loadMore,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.pageSize = 20,
    this.loadThreshold = 200,
    this.enablePullToRefresh = true,
  });
  
  @override
  State<LazyLoadListView<T>> createState() => _LazyLoadListViewState<T>();
}

class _LazyLoadListViewState<T> extends State<LazyLoadListView<T>> {
  final List<T> _items = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  Object? _error;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final items = await widget.loadMore(0, widget.pageSize);
      setState(() {
        _items.clear();
        _items.addAll(items);
        _currentPage = 0;
        _hasMore = items.length == widget.pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final nextPage = _currentPage + 1;
      final items = await widget.loadMore(nextPage, widget.pageSize);
      
      setState(() {
        _items.addAll(items);
        _currentPage = nextPage;
        _hasMore = items.length == widget.pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - widget.loadThreshold) {
      _loadMoreData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return widget.errorBuilder?.call(context, _error!) ?? 
        Center(child: Text('Error: $_error'));
    }
    
    if (_items.isEmpty && _isLoading) {
      return widget.loadingBuilder?.call(context) ?? 
        const Center(child: CircularProgressIndicator());
    }
    
    if (_items.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? 
        const Center(child: const Text('No items'));
    }
    
    final listView = ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _items.length) {
          return widget.itemBuilder(context, _items[index], index);
        }
        
        // Loading indicator at the bottom
        return Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: _isLoading
              ? const CircularProgressIndicator()
              : SizedBox.shrink(),
          ),
        );
      },
    );
    
    if (widget.enablePullToRefresh) {
      return RefreshIndicator(
        onRefresh: _loadInitialData,
        child: listView,
      );
    }
    
    return listView;
  }
}

/// Virtual scrolling list for huge datasets
class VirtualScrollList<T> extends StatefulWidget {
  final int itemCount;
  final double itemHeight;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int cacheExtent;
  
  const VirtualScrollList({
    super.key,
    required this.itemCount,
    required this.itemHeight,
    required this.itemBuilder,
    this.cacheExtent = 3,
  });
  
  @override
  State<VirtualScrollList<T>> createState() => _VirtualScrollListState<T>();
}

class _VirtualScrollListState<T> extends State<VirtualScrollList<T>> {
  late ScrollController _scrollController;
  int _firstVisibleIndex = 0;
  int _visibleItemCount = 0;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    final scrollOffset = _scrollController.offset;
    final newFirstVisible = (scrollOffset / widget.itemHeight).floor();
    
    if (newFirstVisible != _firstVisibleIndex) {
      setState(() {
        _firstVisibleIndex = newFirstVisible;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _visibleItemCount = (constraints.maxHeight / widget.itemHeight).ceil();
        final totalHeight = widget.itemCount * widget.itemHeight;
        
        // Calculate visible range with cache
        final startIndex = (_firstVisibleIndex - widget.cacheExtent).clamp(0, widget.itemCount);
        final endIndex = (_firstVisibleIndex + _visibleItemCount + widget.cacheExtent)
            .clamp(0, widget.itemCount);
        
        return Stack(
          children: [
            // Invisible container to maintain scroll height
            SizedBox(
        height: totalHeight),
            
            // Scrollable area
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // Spacer for items above viewport
                    SizedBox(
        height: startIndex * widget.itemHeight),
                    
                    // Visible items
                    ...List.generate(
                      endIndex - startIndex,
                      (index) => SizedBox(
        height: widget.itemHeight,
                        child: widget.itemBuilder(context, startIndex + index),
                      ),
                    ),
                    
                    // Spacer for items below viewport
                    SizedBox(
                      height: (widget.itemCount - endIndex) * widget.itemHeight,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sliver-based lazy list for custom scroll views
class LazyLoadSliverList<T> extends StatefulWidget {
  final Future<List<T>> Function(int page) loadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;
  
  const LazyLoadSliverList({
    super.key,
    required this.loadMore,
    required this.itemBuilder,
    this.pageSize = 20,
  });
  
  @override
  State<LazyLoadSliverList<T>> createState() => _LazyLoadSliverListState<T>();
}

class _LazyLoadSliverListState<T> extends State<LazyLoadSliverList<T>> {
  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _loadMore();
  }
  
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);
    
    try {
      final items = await widget.loadMore(_currentPage);
      setState(() {
        _items.addAll(items);
        _currentPage++;
        _hasMore = items.length == widget.pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < _items.length) {
            return widget.itemBuilder(context, _items[index]);
          }
          
          if (_hasMore) {
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          return null;
        },
        childCount: _items.length + (_hasMore ? 1 : 0),
      ),
    );
  }
}