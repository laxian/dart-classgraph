import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/source/source_resource.dart';
import 'package:classgraph/abs.dart';
import 'package:classgraph/provider.dart';
import 'package:path/path.dart';

class PackageUriResolver extends UriResolver {
  static const String PACKAGE_SCHEME = 'package';

  @override
  Source resolveAbsolute(Uri uri, [Uri actualUri]) {
    uri ??= actualUri;
    if (uri.scheme != PACKAGE_SCHEME) {
      return null;
    }
    // Prepare path.
    String path = uri.path;
    // Prepare path components.
    int index = path.indexOf('/');
    if (index == -1 || index == 0) {
      return null;
    }
    // <pkgName>/<relPath>
    String pkgName = path.substring(0, index);
    String packageRoot = MyEnvironmentProvider().getPackagePath(pkgName);
    String relPath = path.substring(index + 1);
    String fullPath = join(packageRoot, relPath);
    var file = PhysicalResourceProvider.INSTANCE.getFile(fullPath);
    return new FileSource(file);
  }
}

class DartUriResolver extends UriResolver {
  @override
  Source resolveAbsolute(Uri uri, [Uri actualUri]) {
    uri ??= actualUri;
    if (uri.scheme != 'dart') {
      throw new ArgumentError(
          'The URI of the unit to patch must have the "dart" scheme: $uri');
    }
    List<String> uriSegments = uri.pathSegments;
    String libraryName = uriSegments.first;
    Uri dartHome = MyEnvironmentProvider().getDartHome();
    var fullPath = '${dartHome}/lib/$libraryName/$libraryName.dart';
    var file = PhysicalResourceProvider.INSTANCE.getFile(fullPath);
    return new FileSource(file);
  }
}

/// parse import directives from file
class PackageImportResolver extends ImportResolver {
  @override
  resolve(input) {
    var src = File.fromUri(input);
    var compilationUnit = parseCompilationUnit(src.readAsStringSync());
    var imports =
        compilationUnit.directives.where((d) => d is ImportDirective).toList();
    return imports;
  }
}
