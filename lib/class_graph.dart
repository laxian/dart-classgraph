import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:classgraph/abs.dart';
import 'package:classgraph/class_parser.dart';
import 'package:classgraph/provider.dart';
import 'package:classgraph/resolver.dart';
import 'package:path/path.dart';

/// A [ClassNode] represents a node in inheritance tree
/// 将类的继承关系描绘成一棵多树，[ClassNode]则是树上的一个节点
class ClassNode {
  EntityClassParser curr;
  ClassNode pre;
  List<ClassNode> children = [];

  ClassNode(this.curr, [this.pre, ClassNode child]) {
    if (child != null) {
      children.add(child);
    }
  }
}

abstract class ParsedSource {
  ParsedSource(this._src, [this._uri]);

  CompilationUnit compilationUnit;

  Uri _uri;

  /// Dart file uri
  Uri get uri => _uri;

  String _src;

  /// Dart source code
  String get src => _src;

  List<EntityClassParser> _clsList;

  /// All classes declared
  List<EntityClassParser> get clsList => _clsList;

  /// 导入语句
  List<ImportDirective> imports;

  /// 声明的类的名字列表
  List<String> get clsNames => _clsList.map((c) => c.getName()).toList();

  /// 显式继承自外部包中父类的类
  List<EntityClassParser> classesHaveOuterSuper;
}

/// 读取dart源码，将类的继承关系（extends）转化成map，通过工具，可视化展示
class ParsedSourceImpl extends ParsedSource {
  ParsedSourceImpl.fromUri(Uri _uri) : super(null, _uri) {
    _init();
  }

  ParsedSourceImpl.fromSrc(String src) : super(src) {
    _init();
  }

  /// read all class declarations to a List and return.
  _readClassList() {
    if (_clsList != null) {
      return;
    }

    var src = _src ?? File.fromUri(_uri).readAsStringSync();
    compilationUnit = parseCompilationUnit(src);
    _src = src;

    // 读取源码中的类声明到列表
    _clsList = compilationUnit.declarations
        .whereType<ClassDeclaration>()
        .map((cls) => EntityClassParser.fromClassDeclaration(cls))
        .toList();
  }

  /// 一个类的直接显式父类来自import
  _findClassesExtendsOuterClass() {
    if (_clsList == null) {
      return;
    }

    classesHaveOuterSuper = _clsList
        .where((c) => c.getSuper() != null)
        .where((c) => !clsNames.contains(c.getSuperName()))
        .toList();
  }

  _findImportDirective() {
    if (compilationUnit == null) {
      return;
    }
    List<ImportDirective> directives =
        compilationUnit.directives.whereType<ImportDirective>().toList();
//    print(directives.last.uri.stringValue);
    imports = directives;
  }

  void _init() {
    // find all class declared in file
    _readClassList();

    // 查找导入语句
    _findImportDirective();
    // 查找导入的类的子类
    _findClassesExtendsOuterClass();
    // 查找导入的类
//    findImportedClass();
  }

  List<EntityClassParser> findImportedClass() {
    List<EntityClassParser> outerSuper = [];
    if (classesHaveOuterSuper == null) {
      return outerSuper;
    }
    if (imports == null || imports.isEmpty) {
      return outerSuper;
    }
    for (var i in imports) {
      var iterator = classesHaveOuterSuper.iterator;
      while (classesHaveOuterSuper.length > 0 && iterator.moveNext()) {
        var c = iterator.current;
        var uri = Uri.parse(i.uri.stringValue);
        Uri resolvedUri;
        if (uri.isScheme('package')) {
          resolvedUri = PackageUriResolver().resolveAbsolute(uri).uri;
        } else if (uri.isScheme('dart')) {
          resolvedUri = DartUriResolver().resolveAbsolute(uri).uri;
        }
        var found =
            SingleFileScanner().scan([resolvedUri ?? uri], c.getSuperName());
        if (found == null || found.isEmpty) {
          var parent = dirname(resolvedUri.path);
          var traverse = DartFileTraversal().traverse(parent);
          found = FileScanner()
              .scan(traverse.map((f) => f.uri).toList(), c.getSuperName())
              .toList();
        }
        if (found != null && !found.isEmpty) {
          outerSuper.addAll(found);
          classesHaveOuterSuper.remove(c);
        }
      }
    }
    return outerSuper;
  }
}

class TreeToMapConverter implements MapConverter {
  get emptyMap => <String, dynamic>{};

  @override
  Map<String, dynamic> convert(ClassNode root) {
    if (root == null) {
      return null;
    }
    String name = root.curr.getName();

    Map<String, dynamic> rootMap = emptyMap;
    rootMap[name] = emptyMap;
    List<ClassNode> pending = [root];
    while (pending.length > 0) {
      // travel curr node,
      ClassNode currNode = pending.removeAt(0);
      String key = currNode.curr.getName();
      Map<String, dynamic> innerMap = _getCurrMap(currNode, rootMap);
      if (currNode.children.length == 0) continue;

      for (var child in currNode.children) {
        String key = child.curr.getName();
        innerMap[key] = emptyMap;
        pending.add(child);
      }
    }

    return rootMap;
  }

  /// rootMap 对应一个tree，
  /// 这个方法的功能是根据子节点，找到节点在rootMap中的位置。
  _getCurrMap(ClassNode node, Map<String, dynamic> rootMap) {
    ClassNode tmp = node;
    List<String> path = [];
    path.add(tmp.curr.getName());
    while (tmp.pre != null) {
      tmp = tmp.pre;
      path.add(tmp.curr.getName());
    }
    Map<String, dynamic> tmpMap = rootMap;

    for (var i = path.length - 1; i >= 0; i--) {
      var key = path[i];
      tmpMap = tmpMap[key];
    }
    return tmpMap;
  }
}

class TreeBuilderImpl extends TreeBuilder {
  @override
  void buildTree(ClassNode node, List<EntityClassParser> clsList) {
    Iterable<EntityClassParser> children;
    List<ClassNode> pending = [node];
    while (pending.length > 0) {
      ClassNode the = pending.removeAt(0);
      children = _findChildren(the.curr.clazz.name.name, clsList);

      // nil node, continue
      if (children == null || children.length == 0) continue;

      for (var child in children) {
        // she cNode's parent
        ClassNode cNode = ClassNode(child, the);

        // parent's child
        the.children.add(cNode);
        pending.add(cNode);
      }
    }
  }

  /// 从[ClassDeclaration]列表中，找到直接父类是superName的，并返回
  Iterable<EntityClassParser> _findChildren(
      String superName, List<EntityClassParser> _clsList) {
    if (_clsList == null || _clsList.isEmpty || superName == null) {
      return null;
    }

    return _clsList.where((cls) {
      return cls.getSuper() != null && cls.getSuperName() == superName;
    }).toList();
  }
}
