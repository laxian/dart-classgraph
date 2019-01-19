import 'dart:convert';

import 'package:classgraph/class_graph.dart';
import 'package:classgraph/class_parser.dart';
import 'package:classgraph/provider.dart';


List<ClassNode> _rootNodes = <ClassNode>[];
List<Map<String, dynamic>> maps = [];

main(List<String> args) {
//  var root = MyEnvironmentProvider().getPackagePath('analyzer');
  var root = '/Users/etiantian/flutter/flutter-0.10.0/packages/flutter/lib/';
  print(root);
  var files = new DartFileTraversal().traverse('$root');
//  files = files.where((f)=>f.uri.path.contains('byte_stream.dart')).toList();
  print(files);

  var cls;
  try {
    cls = files
        .map((f) => f.uri)
        .expand((u) => ParsedSourceImpl.fromUri(u).clsList)
        ?.toList();
  } catch (e) {
    print(e);
  }

  Iterable clsOuter;
  try {
    clsOuter = files
        .map((f) => f.uri)
        .expand((u) => ParsedSourceImpl.fromUri(u).findImportedClass())
        ?.toList();
  } catch (e) {
    print(e);
  }

  print(cls.length);
  cls.map((f) => f.getName()).forEach((f) => print(f));

  _rootNodes.addAll(RootFinderImpl().findRoot(cls));
  if (clsOuter != null) {
    _rootNodes.addAll(clsOuter.map((e) => ClassNode(e)));
  }

  clsOuter ??= <EntityClassParser>[];
  (clsOuter as List).addAll(cls);

  for (var node in _rootNodes) {
    TreeBuilderImpl().buildTree(node, clsOuter);
  }
  for (var node in _rootNodes) {
    var map = TreeToMapConverter().convert(node);
    maps.add(map);
  }
  // 关键字模糊过滤
//  var jsons = maps.map((m) => jsonEncode(m)).toList();
//  jsons.forEach((j) => print(j));
//  jsons.where((e)=>e.contains('Widget')).forEach((j)=>print(j));

  /// 根节点过滤
  maps.where((m)=>m.containsKey('Diagnosticable')).map((e)=>jsonEncode(e)).forEach((j)=>print(j));

}
