import 'package:kotlin_data_class_converter/kotlin_data_class_converter.dart';

void main() {
  final input = "data class User(val name: String, val age: Int)";
  final convertedClass = convertKotlinDataClass(
    input,
  );
  final convertedClassWithJsonSerializable = convertKotlinDataClass(
    input,
    annotationType: AnnotationType.jsonSerializable,
  );
  print(convertedClass);
  print(convertedClassWithJsonSerializable);
}
