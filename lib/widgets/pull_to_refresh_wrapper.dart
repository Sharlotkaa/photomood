import 'package:flutter/material.dart';

class PullToRefreshWrapper extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool isLoading;
  final Widget? loadingWidget;

  const PullToRefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
    this.isLoading = false,
    this.loadingWidget,
  });

  @override
  State<PullToRefreshWrapper> createState() => _PullToRefreshWrapperState();
}

class _PullToRefreshWrapperState extends State<PullToRefreshWrapper> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } catch (e) {
      // Ошибка уже обработана в методах, просто завершаем анимацию
      print('Ошибка в PullToRefreshWrapper: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: widget.isLoading && !_isRefreshing
          ? (widget.loadingWidget ?? const Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: widget.child,
            ),
    );
  }
}