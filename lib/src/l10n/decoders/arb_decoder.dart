// ignore: implementation_imports
import 'package:intl_translation/src/icu_parser.dart';
// ignore: implementation_imports
import 'package:intl_translation/src/intl_message.dart';

import '../l10n_entry.dart';

final _pluralAndGenderParser = IcuParser().message;
final _plainParser = IcuParser().nonIcuMessage;

/// Decoder for ARB.
class ArbDecoder {
  const ArbDecoder();

  L10nEntry decodeValue(String key, String value) {
    final parsed = _decodeValue(value);

    if (parsed is LiteralString) {
      return _convertString(key, parsed);
    } else if (parsed is Plural) {
      return _convertPlural(key, parsed);
    } else if (parsed is CompositeMessage) {
      // doesn't process message with args, just add it as is
      return L10nTextEntry(value);
    } else {
      throw UnimplementedError(
          'Decode is not implemented for type ${parsed.runtimeType}. '
          'Key: $key');
    }
  }

  Object _decodeValue(String value) {
    var parsed = _pluralAndGenderParser.parse(value).value as Object;
    if (parsed is LiteralString && parsed.string.isEmpty) {
      parsed = _plainParser.parse(value).value;
    }

    return parsed;
  }

  // L10nTextEntry decodeString(String value) {
  //   return convertIfString(decodeValue(value));
  // }

  // L10nTextEntry convertIfString(Object parsed) {
  //   return parsed is LiteralString ? convertString(parsed) : null;
  // }

  L10nTextEntry _convertString(String key, LiteralString value) {
    return L10nTextEntry(value.string);
  }

  // L10nPluralEntry decodePlural(String value) {
  //   final parsed = decodeValue(value);
  //   return parsed is Plural ? convertPlural(parsed) : null;
  // }

  L10nPluralEntry _convertPlural(String key, Plural value) {
    String toStr(Message val) {
      if (val == null) return null;
      return val.expanded((msg, chunk) {
        if (chunk is String) return chunk;
        if (chunk is LiteralString) return chunk.string;

        if (chunk is VariableSubstitution) {
          return '{${value.mainArgument}}';
        }

        throw Exception('Unhandled chunk type for plural <$key>:'
            ' ${chunk.runtimeType}.\n'
            'Value: $value\n'
            'Parsed: $value\n'
            'Chunk: $chunk');
      });
    }

    return L10nPluralEntry(
      toStr(value.zero),
      toStr(value.one),
      toStr(value.two),
      toStr(value.few),
      toStr(value.many),
      toStr(value.other),
    );
  }
}

const arbDecoder = ArbDecoder();
