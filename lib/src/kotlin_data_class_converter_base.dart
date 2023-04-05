import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import 'kotlin_types_map.dart';

final _dartfmt = DartFormatter();

String convertOneOrMultipleKotlinDataClasses(
  String kotlinDataClasses, {
  AnnotationType annotationType = AnnotationType.none,
  bool includeDefaults = true,
  bool includeInterface = false,
}) {
  final classes = extractKotlinDataClasses(kotlinDataClasses);
  String output = "";
  for (final dataClass in classes) {
    output += convertKotlinDataClass(
      dataClass,
      annotationType: annotationType,
      includeDefaults: includeDefaults,
      includeInterface: includeInterface,
    );
  }
  return _dartfmt.format(output);
}

/// Generates code for a Dart class out of a Kotlin data class
///
/// `annotationType` will create classes which can be used
/// with the `freezed` or `json_serializable` packages
///
/// Set `includeDefaults` to false if fields with defaults are not serialized
///
/// Setting `includeInterface` to `true` will enrich the resulting class with the interface as a mixin
/// & annotate overriden fields with `@override`
String convertKotlinDataClass(
  String kotlinDataClass, {
  AnnotationType annotationType = AnnotationType.none,
  bool includeDefaults = true,
  bool includeInterface = false,
}) {
  final parsedClass = parseKotlinDataClass(
    kotlinDataClass,
    annotationType: annotationType,
    includeDefaults: includeDefaults,
    includeInterface: includeInterface,
  );
  return _dartfmt.format('${parsedClass.accept(DartEmitter())}');
}

List<String> extractKotlinDataClasses(String input) {
  List<String> dataClasses = [];

  final matches = "data class".allMatches(input);
  for (final match in matches) {
    final end = ")".allMatches(input, match.start);
    bool characterFound = false;
    String character = "";
    int max = input.length;
    int index = end.first.end;
    int endIndex = end.first.end;
    while (!characterFound && index < max) {
      character = input[index];
      if (character != " ") {
        characterFound = true;
      }
      index++;
    }
    if (character == ":") {
      character = input[index];
      index++;
      while (character == " " && index < max) {
        character = input[index];
        index++;
      }
      while (character.trim().isNotEmpty && character != "(" && index < max) {
        character = input[index];
        index++;
      }
      endIndex = index - 1;
    }
    dataClasses.add(input.substring(match.start, endIndex));
  }
  return dataClasses;
}

/// Parses a Kotlin data class String to the `Class` type of the `code_builder` package
///
/// `annotationType` will create classes which can be used
/// with the `freezed` or `json_serializable` packages
///
/// Set `includeDefaults` to false if fields with defaults are not serialized
///
/// Setting `includeInterface` to `true` will enrich the resulting class with the interface as a mixin
/// & annotate overriden fields with `@override`
Class parseKotlinDataClass(
  String kotlinDataClass, {
  AnnotationType annotationType = AnnotationType.none,
  bool includeDefaults = true,
  bool includeInterface = false,
}) {
  final matches = "data class".allMatches(kotlinDataClass);
  if (matches.length != 1) {
    throw Exception("None or more than 1 data class found");
  }
  kotlinDataClass = kotlinDataClass.replaceAll("data class ", "");
  var fragments = kotlinDataClass.split("(");
  fragments = [fragments.first, ...fragments.last.split(")")];
  final name = fragments[0];
  var fields = fragments[1].split(",");
  String? interface;
  if (includeInterface) {
    if (fragments.last.contains(":")) {
      interface = fragments.last.split(":").last.trim();
    }
  }
  if (!includeDefaults) {
    fields = fields.where((field) => !field.contains("=")).toList();
  }
  final convertedFields = fields
      .map(
        (field) => parseKotlinField(field, includeInterface),
      )
      .toList();
  return Class((b) => b
    ..name = name
    ..fields.addAll(convertedFields)
    ..constructors.addAll(
      [
        Constructor(
          (b) => b
            ..optionalParameters.addAll(
              convertedFields.map(
                (field) => Parameter(
                  (b) => b
                    ..name = field.name
                    ..toThis = true
                    ..named = true
                    ..required = !field.type!.symbol!.endsWith("?"),
                ),
              ),
            ),
        ),
        if (annotationType == AnnotationType.jsonSerializable)
          getJsonSerializableConstructor(name)
      ],
    )
    ..annotations.addAll([
      if (annotationType == AnnotationType.jsonSerializable)
        refer("JsonSerializable").call([])
    ])
    ..methods.addAll([
      if (annotationType == AnnotationType.jsonSerializable)
        Method(
          (b) => b
            ..returns = refer("Map<String, dynamic>")
            ..name = "toJson"
            ..lambda = true
            ..body = Code("_\$${name}ToJson(this)"),
        ),
    ])
    ..mixins.addAll([
      if (interface != null) refer(interface),
    ]));
}

Constructor getJsonSerializableConstructor(String className) {
  return Constructor((b) => b
    ..factory = true
    ..name = "fromJson"
    ..requiredParameters.add(
      Parameter(
        (b) => b
          ..name = "json"
          ..type = Reference("Map<String, dynamic>"),
      ),
    )
    ..lambda = true
    ..body = Code("_\$${className}FromJson(json)"));
}

Field parseKotlinField(String field, bool includeInterface) {
  final fragments = field.split(":");
  var type = fragments.last.split("=").first;
  final isOverride = fragments.first.startsWith("override");
  final convertedType = _getConvertedType(type);
  final name = fragments.first.split(" ").last;
  return Field(
    (b) => b
      ..name = name
      ..type = Reference(convertedType)
      ..annotations.addAll(
        [if (isOverride && includeInterface) refer("override")],
      ),
  );
}

String _getConvertedType(String type) {
  type = type.trim();
  final isNullable = type.endsWith("?");
  if (isNullable) {
    type = type.substring(0, type.length - 1);
  }
  final usesGenerics = type.endsWith(">");
  String genericsClause = "";
  if (usesGenerics) {
    final genericsStart = type.indexOf("<");
    final genericsString = type.substring(genericsStart);
    final genericsTypesString =
        genericsString.substring(1, genericsString.length - 1);
    List<String> genericTypes = [""];
    bool onGeneric = false;
    // split generic types up, but keep subtypes which are using generics whole
    for (final char in genericsTypesString.split('')) {
      if (onGeneric) {
        if (char == ">") {
          onGeneric = false;
        }
        genericTypes.last += char;
      } else if (char == "<") {
        onGeneric = true;
        genericTypes.last += char;
      } else if (char == ",") {
        genericTypes.add("");
      } else {
        genericTypes.last += char;
      }
    }
    genericsClause =
        "<${genericTypes.map((e) => _getConvertedType(e)).join(", ")}>";
    type = type.substring(0, genericsStart);
  }
  return (kotlinTypesMap[type] ?? type) +
      genericsClause +
      (isNullable ? "?" : "");
}

enum AnnotationType {
  none,
  // TODO: implement freezed
  // freezed,
  jsonSerializable,
}
