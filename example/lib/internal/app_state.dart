import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

AppLifecycleState parseStateFromString(String state) {
  final values = <String, AppLifecycleState>{
    AppLifecycleState.inactive.toString(): AppLifecycleState.inactive,
    AppLifecycleState.paused.toString(): AppLifecycleState.paused,
    AppLifecycleState.resumed.toString(): AppLifecycleState.resumed,
    AppLifecycleState.detached.toString(): AppLifecycleState.detached,
  };

  return values[state]!;
}
