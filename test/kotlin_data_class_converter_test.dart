import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:kotlin_data_class_converter/kotlin_data_class_converter.dart';
import 'package:test/test.dart';

void main() {
  group('Unit Tests:', () {
    group('parseKotlinField -', () {
      test('Parse simple field', () {
        final field = "val name: String";

        final convertedField = parseKotlinField(field, false);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "String name;");
      });

      test('Parse field with default', () {
        final field = 'val name: String = "hello"';

        final convertedField = parseKotlinField(field, false);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "String name;");
      });

      test('Parse field with default method optional', () {
        final field = 'val customClass: List<CustomClass> = emptyList()';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "List<CustomClass> customClass;");
      });

      test('Parse field with override, includeInterface false', () {
        final field = 'override val name: String = "hello"';

        final convertedField = parseKotlinField(field, false);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "String name;");
      });

      test('Parse field with override, includeInterface true', () {
        final field = 'override val name: String = "hello"';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "@override String name;");
      });

      test('Parse int field to ensure mapping is used', () {
        final field = 'val number: Int = 1';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "int number;");
      });

      test('Parse nullable field', () {
        final field = 'val flag: Boolean?';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "bool? flag;");
      });

      test('Parse field of custom class', () {
        final field = 'val customField: Custom';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "Custom customField;");
      });

      test('Parse nullable field of custom class', () {
        final field = 'val customField: Custom?';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "Custom? customField;");
      });

      test('Parse list field', () {
        final field = 'val customField: List<Boolean?>';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "List<bool?> customField;");
      });

      test('Parse set field', () {
        final field = 'val setField: Set<Int>';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "Set<int> setField;");
      });

      test('Parse map field', () {
        final field = 'val mapField: Map<String, Int>';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "Map<String, int> mapField;");
      });

      test('Parse nested map field', () {
        final field = 'val nestedMapField: Map<Map<String, Int>, Int>';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(
            fieldOutput.trim(), "Map<Map<String, int>, int> nestedMapField;");
      });

      test('Parse generics array', () {
        final field = 'val arrayField: Array<Boolean>';

        final convertedField = parseKotlinField(field, true);
        final fieldOutput = convertedField.accept(DartEmitter()).toString();

        expect(fieldOutput.trim(), "List<bool> arrayField;");
      });
    });

    group('convertKotlinDataClass -', () {
      final dartfmt = DartFormatter();
      test('Simple class conversion', () {
        final convertedClass = convertKotlinDataClass(
          "data class User(val name: String, val age: Int)",
        );
        final expectedClass = '''
        class User {
          User({
            required this.name,
            required this.age,
          });

          String name;

          int age;
        }
        ''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with comma at end', () {
        final convertedClass = convertKotlinDataClass(
          "data class User(val name: String, val age: Int,)",
        );
        final expectedClass = '''
        class User {
          User({
            required this.name,
            required this.age,
          });

          String name;

          int age;
        }
        ''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with comma at end & new line', () {
        final convertedClass = convertKotlinDataClass('''data class User(
            val name: String,
            val age: Int,
        )''');
        final expectedClass = '''
        class User {
          User({
            required this.name,
            required this.age,
          });

          String name;

          int age;
        }
        ''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with JsonSerializable', () {
        final convertedClass = convertKotlinDataClass(
            "data class User(val name: String, val age: Int)",
            annotationType: AnnotationType.jsonSerializable);
        final expectedClass = '''
      @JsonSerializable()
      class User{
        User({
            required this.name,
            required this.age,
          });

        factory User.fromJson(Map<String, dynamic> json) => _\$UserFromJson(json);

        String name;

        int age;

        Map<String, dynamic> toJson() => _\$UserToJson(this);
      }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with body', () {
        final input = '''
          data class Person(val name: String?) {
              var age: Int = 0
          }''';
        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class Person{
            Person({this.name});

            String? name;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with Map using generics', () {
        final input = '''
          data class Person(val features: Map<String, Any?>)''';
        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class Person{
            Person({required this.features});

            Map<String, Object?> features;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with Map using nested generics', () {
        final input = '''
          data class Person(val features: Map<String, Map<String, Any?>>)''';
        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class Person{
            Person({required this.features});

            Map<String, Map<String, Object?>> features;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with defaults', () {
        final input = '''
          data class User(val name: String = "", val age: Int? = 0)
          ''';
        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class User{
            User({required this.name, this.age,});

            String name;

            int? age;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion with defaults with method', () {
        final input = '''
          data class User(val name: String = "", val customClass: List<CustomClass> = emptyList())
          ''';

        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class User{
            User({required this.name, required this.customClass,});

            String name;

            List<CustomClass> customClass;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion exclude defaults', () {
        final input = '''
          data class User(val name: String, val age: Int? = 0)
          ''';
        final convertedClass =
            convertKotlinDataClass(input, includeDefaults: false);
        final expectedClass = '''
          class User{
            User({required this.name});

            String name;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion including interface', () {
        final input = '''
          data class User(override val name: String, override val age: Int? = 0, val isMale: Boolean) : Person
          ''';
        final convertedClass = convertKotlinDataClass(input,
            includeDefaults: false, includeInterface: true);
        final expectedClass = '''
          class User with Person{
            User({required this.name, required this.isMale,});

            @override
            String name;

            bool isMale;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });

      test('Simple class conversion excluding interface', () {
        final input = '''
          data class User(override val name: String, override val age: Int? = 0) : Person
          ''';
        final convertedClass =
            convertKotlinDataClass(input, includeDefaults: false);
        final expectedClass = '''
          class User{
            User({required this.name});

            String name;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });
      test('Failure when converting regular class', () {
        final input = '''
          class User(override val name: String, override val age: Int? = 0) : Person
          ''';
        expect(() => convertKotlinDataClass(input), throwsException);
      });

      test('Failure when converting multiple data classes', () {
        final input = '''
          data class User(override val name: String, override val age: Int? = 0) : Person

          data class Member(override val name: String, override val age: Int? = 0)
          ''';
        expect(() => convertKotlinDataClass(input), throwsException);
      });

      test('Class conversion including custom types', () {
        final input = '''
          data class User(val mother: Person, val brother: Person?)
          ''';
        final convertedClass = convertKotlinDataClass(input);
        final expectedClass = '''
          class User{
            User({required this.mother, this.brother,});

            Person mother;

            Person? brother;
          }''';

        expect(convertedClass, dartfmt.format(expectedClass));
      });
    });

    group('extractKotlinDataClasses -', () {
      test('Extract 3 data classes', () {
        final input = '''
          data class User(override val name: String, override val age: Int? = 0, override val test: List<Int> = emptyList()) : Person
          class User(override val name: String, override val age: Int? = 0) : Person
          data class Member(override val name: String, override val age: Int? = 0)
          class Member(override val name: String, override val age: Int? = 0)
          data class User(override val name: String, override val age: Int? = 0) : Person()
          ''';
        expect(extractKotlinDataClasses(input), [
          "data class User(override val name: String, override val age: Int? = 0, override val test: List<Int> = emptyList()) : Person",
          "data class Member(override val name: String, override val age: Int? = 0)",
          "data class User(override val name: String, override val age: Int? = 0) : Person"
        ]);
      });
    });
  });
}
