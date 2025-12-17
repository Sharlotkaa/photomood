// Создайте файл optimized_screen.dart
import 'package:flutter/material.dart';

abstract class OptimizedScreenState<T extends StatefulWidget> extends State<T> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }
}