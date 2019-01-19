import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:classgraph/class_graph.dart';
import 'package:classgraph/class_parser.dart';
import 'package:classgraph/provider.dart';

abstract class Traversal<T> {
  List<FileSystemEntity> traverse(T entry);
}

abstract class ImportResolver {
  resolve(input);
}

abstract class ClassScanner<T> {
  Iterable<T> scan(Iterable<Uri> files);
}

abstract class NodeScanner {
  scan(classes);
}

abstract class PoolMaker {
  makePool(src, added);
}

abstract class EnvironmentProvider {
  getProjectRoot();

  getPackages();

  getPackageList();

  getPackagePath(String name);
}

abstract class RootFinder {
  Iterable findRoot(Iterable clsList);
}

abstract class ClassParser {
  ConstructorDeclaration getConstructor();

  getFields();

  getMethods();

  getSuper();

  List<TypeName> getImplements();
}

abstract class MapConverter {
  Map<String, dynamic> convert(ClassNode rootNode);
}

abstract class TreeBuilder {
  void buildTree(ClassNode root, List<EntityClassParser> clsList);
}

abstract class Composer {
  PoolMaker poolMaker;
  Traversal traversal;
  ClassScanner classScanner;
  ImportResolver importResolver;
  NodeScanner nodeScanner;
  TreeBuilder treeBuilder;
  MapConverter mapConverter;
  EnvironmentProvider environmentProvider;

  Composer(
      {this.poolMaker,
      this.traversal,
      this.classScanner,
      this.importResolver,
      this.nodeScanner,
      this.treeBuilder,
      this.mapConverter,
      this.environmentProvider});

  void execute();
}

class OneComposer extends Composer {
  OneComposer(
    PoolMaker poolMaker,
    Traversal traversal,
    ClassScanner classScanner,
    ImportResolver importResolver,
    NodeScanner nodeScanner,
    TreeBuilder treeBuilder,
    MapConverter mapConverter,
    EnvironmentProvider environmentProvider,
  ) : super(
            poolMaker: poolMaker,
            traversal: traversal,
            classScanner: classScanner,
            importResolver: importResolver,
            nodeScanner: nodeScanner,
            treeBuilder: treeBuilder,
            mapConverter: mapConverter,
            environmentProvider: environmentProvider);

  @override
  void execute() {
    List<FileSystemEntity> input = traversal.traverse('input');
    var imports = importResolver.resolve(input.map((f) => f));
    var classes = classScanner.scan(input.map((f) => f.uri));
    var rootNodes = nodeScanner.scan(classes);
    var pool = poolMaker.makePool(classes, imports);
//    treeBuilder.buildTree(classes, pool);
    var maps = mapConverter.convert(rootNodes);
  }
}

main(List<String> args) {
  var uri = Uri.parse('/a/b/c/ddd.dart');
  print(uri.pathSegments.last);

  var traverse = DartFileTraversal().traverse(
      '/Users/etiantian/flutter/flutter-0.10.0/bin/cache/dart-sdk/lib/async');
  var list =
      FileScanner().scan(traverse.map((f) => f.uri).toList(), 'BaseRequest');
  print(list.length);
}
