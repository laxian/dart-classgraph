// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

final _dartfmt = DartFormatter();

void main() {
  print('animalClass():\n${'=' * 40}\n${animalClass()}');
  print('scopedLibrary():\n${'=' * 40}\n${scopedLibrary()}');
}

/// Outputs:
///
/// ```dart
/// class Animal extends Organism {
///   void eat() => print('Yum!');
/// }
/// ```
String animalClass() {
  final $LinkedHashMap = refer('LinkedHashMap', 'dart:collection');
  final animal = Class((b) => b
    ..name = 'Cat'
    ..extend = refer('Animal')
    ..fields.add(Field((b) => b
      ..name = 'age'
      ..type = refer('num')))
    ..constructors.add(Constructor((b) => b
      ..initializers.add(Code('super(name)'))
      ..requiredParameters.addAll([
        Parameter((b) => b..name = 'name'),
        Parameter((b) => b
          ..name = 'age'
          ..toThis = true)
      ])))
    ..methods.add(Method.returnsVoid((b) => b
      ..name = 'eat'
      ..body = refer('print').call([literalString('Yum!')]).code)));
  return animal.accept(DartEmitter()).toString();
}

/// Outputs:
///
/// ```dart
/// import 'package:a/a.dart' as _i1;
/// import 'package:b/b.dart' as _i2;
///
/// _i1.Thing doThing() {}
/// _i2.Other doOther() {}
/// ```
String scopedLibrary() {
  final methods = [
    Method((b) => b
      ..body = const Code('')
      ..name = 'doThing'
      ..returns = refer('Thing', 'package:a/a.dart')),
    Method((b) => b
      ..body = const Code('')
      ..name = 'doOther'
      ..returns = refer('Other', 'package:b/b.dart')),
  ];
  final library = Library((b) => b.body.addAll(methods));
  return _dartfmt.format('${library.accept(DartEmitter.scoped())}');
}

class Animal {
  String name;
  Animal(this.name);

  void eat() => print('Yum!');
}

class Tiger extends Animal {
  num age;
  Tiger(String name, num age)
      : age = 1,
        super(name);
}