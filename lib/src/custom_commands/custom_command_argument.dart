import 'package:yaml/yaml.dart';

/// Argument type for custom command.
enum CustomCommandArgumentType {
  /// Option argument (--name value).
  option,

  /// Flag argument (--name).
  flag,
}

/// Argument definition for custom command.
class CustomCommandArgument {
  /// Name of the argument.
  final String name;

  /// Type of the argument.
  final CustomCommandArgumentType type;

  /// Help text for the argument.
  final String? help;

  /// Abbreviation for the argument.
  final String? abbr;

  /// Default value.
  final String? defaultValue;

  /// Allowed values (for option type).
  final List<String>? allowed;

  /// Is this argument required?
  final bool required;

  CustomCommandArgument({
    required this.name,
    required this.type,
    this.help,
    this.abbr,
    this.defaultValue,
    this.allowed,
    this.required = false,
  });

  factory CustomCommandArgument.fromYaml(YamlMap data) {
    final typeStr = data['type'] as String? ?? 'option';
    final CustomCommandArgumentType type;
    switch (typeStr) {
      case 'option':
        type = CustomCommandArgumentType.option;
        break;
      case 'flag':
        type = CustomCommandArgumentType.flag;
        break;
      default:
        throw Exception('Unknown argument type: $typeStr');
    }

    final allowedList = data['allowed'] as YamlList?;

    return CustomCommandArgument(
      name: data['name'] as String? ??
          (throw Exception('Argument requires "name" field')),
      type: type,
      help: data['help'] as String?,
      abbr: data['abbr'] as String?,
      defaultValue: data['default'] as String?,
      allowed: allowedList?.map((e) => e.toString()).toList(),
      required: data['required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'name': name,
      'type': type == CustomCommandArgumentType.option ? 'option' : 'flag',
    };

    if (help != null) result['help'] = help;
    if (abbr != null) result['abbr'] = abbr;
    if (defaultValue != null) result['default'] = defaultValue;
    if (allowed != null && allowed!.isNotEmpty) result['allowed'] = allowed;
    if (required) result['required'] = true;

    return result;
  }
}
