# Formatting patches to vendored sources

The upstream repository revisions and version declarations remain unchanged. Local vendored files have leading-whitespace-only formatting patches for the required inherited EditorConfig rules. They are no longer described as byte-for-byte upstream copies. No algorithm, identifier, numeric constant, string/character literal, preprocessor token or trailing continuation backslash is changed.

Tabs in indentation expand to two-space tab stops; odd leading spaces round up to the next even column. Every line retains identical bytes after its leading spaces/tabs. There are no raw strings in the affected sources, and comment-aware scans prove every ordinary string/character literal byte-identical, including escaped newlines. This preserves macro continuations and C/C++ lexical semantics.

The original upstream provenance remains in each vendor VERSION.txt or original source header. The exact patch can be reproduced with `git diff` from the previous clean library revision over the listed paths. Required native and typed corpus tests and full hooks must pass on the patched source before qualification.

Patched files:

- `vendor/stb/stb_image_write.h`
- `vendor/flip/FLIP.h`
- `vendor/flip/VERSION.txt`
