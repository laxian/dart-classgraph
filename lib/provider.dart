import 'dart:convert';
import 'dart:io';

import 'package:classgraph/abs.dart';
import 'package:classgraph/class_graph.dart';
import 'package:classgraph/class_parser.dart';

class MyEnvironmentProvider extends EnvironmentProvider {
  getDartHome() {
    ProcessResult result = Process.runSync('which', ['dart']);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw Exception('执行命令：which dart 发生错误，code: ${result.exitCode}');
    }
    String dartPath = result.stdout.toString();
    String dartHome = dartPath.replaceAll('/bin/dart\n', '');
    return Uri.parse(dartHome);
  }

  @deprecated
  @override
  getPackages() {
    var root = getProjectRoot();
    ProcessResult result =
        Process.runSync('pub', ['list-package-dirs'], workingDirectory: root);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw Exception(
          '执行命令：pub list-package-dirs 发生错误，code: ${result.exitCode}');
    }
    return result.stdout;
  }

  @override
  getProjectRoot() {
    return Platform.environment['PWD'];
  }

  @override
  getPackagePath(String name) {
    var map = getPackageList();
    if (map == null) {
      return null;
    }
    return map[name];
  }

  @override
  getPackageList() {
    var root = getProjectRoot();
    ProcessResult result =
        Process.runSync('pub', ['list-package-dirs'], workingDirectory: root);
    if (result.exitCode != 0) {
      print(result.stderr);
      throw Exception(
          '执行命令：pub list-package-dirs 发生错误，code: ${result.exitCode}');
    }
    Map<String, dynamic> jmap = jsonDecode(result.stdout);
    if (jmap.containsKey('packages')) ;
    return jmap['packages'];
  }
}

class FileTraversal<String> extends Traversal {
  @override
  List<FileSystemEntity> traverse(entry) {
    var dir = new Directory.fromUri(Uri.parse(entry));
    List<FileSystemEntity> files =
        dir.listSync(recursive: true, followLinks: true);
    return files;
  }
}

class DartFileTraversal extends FileTraversal {
  @override
  traverse(entry) {
    return super.traverse(entry).where((f) => isDartFile(f.path)).toList();
  }

  bool isDartFile(String path) {
    return path.endsWith('.dart');
  }
}

class SingleFileProvider extends Traversal {
  @override
  traverse(entry) {
    return entry;
  }
}

class RootFinderImpl extends RootFinder {
  List<ClassNode> _rootNodes = <ClassNode>[];

  @override
  findRoot(dynamic _clsList) {
    if (_clsList == null) {
      return null;
    }

    Iterator<EntityClassParser> it = _clsList.iterator;

    // find out all root node.
    // 找到所有没有extends语句的类，把他们作为顶级类，加入到rootNodes
    while (it.moveNext()) {
      EntityClassParser cls = it.current;
      ClassNode node = ClassNode(cls);
      if (cls.getSuper() == null) {
        // print(cls.clazz.name.name);
        _rootNodes.add(node);
      }
    }
    return _rootNodes;
  }
}

class SingleFileScanner extends ClassScanner<EntityClassParser> {
  @override
  List<EntityClassParser> scan(Iterable<Uri> files, [String forName]) {
    Uri uri = files.single;
    if (forName == null) {
      return ParsedSourceImpl.fromUri(uri).clsList;
    } else {
      return ParsedSourceImpl.fromUri(uri)
          .clsList
          .where((c) => c.getName() == forName)
          .toList();
    }
  }
}

class FileScanner extends ClassScanner<EntityClassParser> {
  @override
  Iterable<EntityClassParser> scan(Iterable<Uri> files, [String forName]) {
    if (forName == null) {
      return files?.expand((f) => ParsedSourceImpl.fromUri(f).clsList);
    } else {
      return files
          ?.expand((f) => ParsedSourceImpl.fromUri(f)
              .clsList
              .where((c) => c.getName() == forName))
          .toList();
    }
  }
}

main(List<String> args) {
  Uri uri = MyEnvironmentProvider().getDartHome();
  print(uri.path);
}
