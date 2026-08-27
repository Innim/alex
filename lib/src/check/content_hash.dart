/// Returns a mark of the [bytes] that changes with their content.
///
/// It's not a cryptographic hash: it's used to tell whether a file has
/// changed between two moments, not to protect anything. FNV-1a is enough
/// for that and needs no dependencies.
String contentHash(List<int> bytes) {
  const offsetBasis = 0xcbf29ce484222325;
  const prime = 0x100000001b3;

  // `int` of the Dart VM is a fixed width 64 bit value: the multiplication
  // overflows and wraps around, so the state stays bounded and no masking
  // is needed. The value can be negative because of that, which is fine -
  // it's a mark, not a number.
  var hash = offsetBasis;
  for (final byte in bytes) {
    hash ^= byte;
    hash *= prime;
  }

  // The length is a part of the mark, so a collision of the hash
  // is not enough for two different files to look the same.
  return '${bytes.length}:${hash.toRadixString(16)}';
}
