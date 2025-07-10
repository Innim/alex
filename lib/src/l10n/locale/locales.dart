import 'package:list_ext/list_ext.dart';

const _kArbLocaleMap = {
  // Use Norwegian Bokmål for Norwegian
  'no': 'nb',
};

const _kJsonLocaleMap = {
  // Use Norwegian Bokmål for Norwegian
  'no': 'nb',
};

// http://developer.android.com/reference/java/util/Locale.html
// Note that Java uses several deprecated two-letter codes.
// The Hebrew ("he") language code is rewritten as "iw",
// Indonesian ("id") as "in", and Yiddish ("yi") as "ji".
// This rewriting happens even if you construct your own Locale object,
// not just for instances returned by the various lookup methods.
const _kAndroidLocaleMap = <String, String>{
  'he': 'iw',
  'id': 'in',
  'yi': 'ji',
  // Custom map: use nb for Norwegian
  'no': 'nb',
};

class ArbLocale extends LocaleValue {
  const ArbLocale(super.value);

  String get codeFileSuffix => value;

  XmlLocale toXmlLocale() {
    final mapEntry =
        _kArbLocaleMap.entries.firstWhereOrNull((e) => e.value == value);

    return XmlLocale(mapEntry?.key ?? value);
  }
}

class XmlLocale extends LocaleValue {
  const XmlLocale(super.value);

  ArbLocale toArbLocale() {
    final arbValue = _kArbLocaleMap[value] ?? value;
    return ArbLocale(arbValue);
  }

  JsonLocale toJsonLocale() {
    final jsonValue = _kJsonLocaleMap[value] ?? value.replaceAll('_', '-');
    return JsonLocale(jsonValue);
  }

  IosLocale toIosLocale() {
    final iosValue = value.replaceAll('_', '-');
    return IosLocale(iosValue);
  }

  AndroidLocale toAndroidLocale() {
    final androidValue =
        (_kAndroidLocaleMap[value] ?? value).replaceAll('_', '-r');
    return AndroidLocale(androidValue);
  }
}

class JsonLocale extends LocaleValue {
  const JsonLocale(super.value);
}

class IosLocale extends LocaleValue {
  const IosLocale(super.value);

  List<IosLocale> getAltLocales() {
    final Iterable<String> altLocales;
    if (value.startsWith('zh-') && value.split('-').length == 2) {
      // chinese
      altLocales = const ['Hans', 'Hant']
          .map((s) => value.replaceFirst('zh-', 'zh-$s-'));
    } else if (value == 'no') {
      // norwegian
      altLocales = const ['nb'];
    } else {
      altLocales = const [];
    }

    return altLocales.map(IosLocale.new).toList();
  }
}

class AndroidLocale extends LocaleValue {
  AndroidLocale(super.value);
}

abstract class LocaleValue implements Comparable<LocaleValue> {
  final String value;

  const LocaleValue(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocaleValue &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  int compareTo(LocaleValue other) => value.compareTo(other.value);
}

extension LocaleValueStringExt on String {
  ArbLocale asArbLocale() => ArbLocale(this);
  XmlLocale asXmlLocale() => XmlLocale(this);
}
