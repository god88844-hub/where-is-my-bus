// One-shot migration tool for the theme toggle feature.
//
// AppTheme's colors become runtime-switchable getters (dark/light), so any
// `const` constructor whose argument list references AppTheme.* must lose
// its `const`. This tool rewrites lib/**.dart (except app_theme.dart)
// accordingly:
//   - scans token-wise, skipping strings and comments
//   - for every `const` followed by an identifier or `[`/`{`, finds the
//     matching close bracket and checks the span for `AppTheme.`
//   - nested `const`s are separate tokens and stay valid in non-const scope
//
// Usage: dart run tool/deconst_theme.dart
import 'dart:io';

bool _changed = false;

String _transform(String src) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  var stringChar = '';
  var inLineComment = false;
  var inBlockComment = false;

  bool isIdentChar(int c) =>
      (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F;

  while (i < src.length) {
    final ch = src[i];
    final next = i + 1 < src.length ? src[i + 1] : '';

    if (inLineComment) {
      out.write(ch);
      if (ch == '\n') inLineComment = false;
      i++;
      continue;
    }
    if (inBlockComment) {
      out.write(ch);
      if (ch == '*' && next == '/') {
        out.write(next);
        i += 2;
        inBlockComment = false;
        continue;
      }
      i++;
      continue;
    }
    if (inString) {
      out.write(ch);
      if (ch == r'\') {
        if (i + 1 < src.length) {
          out.write(src[i + 1]);
          i += 2;
          continue;
        }
      } else if (ch == stringChar) {
        inString = false;
      }
      i++;
      continue;
    }

    if (ch == '/' && next == '/') {
      inLineComment = true;
      out.write(ch);
      i++;
      continue;
    }
    if (ch == '/' && next == '*') {
      inBlockComment = true;
      out.write(ch);
      out.write(next);
      i += 2;
      continue;
    }
    if (ch == "'" || ch == '"') {
      inString = true;
      stringChar = ch;
      out.write(ch);
      i++;
      continue;
    }

    // `const` keyword?
    if (ch == 'c' &&
        i + 5 <= src.length &&
        src.substring(i, i + 5) == 'const' &&
        (i == 0 || !isIdentChar(src.codeUnitAt(i - 1))) &&
        (i + 5 >= src.length || !isIdentChar(src.codeUnitAt(i + 5)))) {
      var j = i + 5;
      // whitespace
      while (j < src.length && (src[j] == ' ' || src[j] == '\n' || src[j] == '\t' || src[j] == '\r')) {
        j++;
      }
      if (j < src.length) {
        final startChar = src[j];
        final isOpenBracket = startChar == '[' || startChar == '{';
        final isIdent = isIdentChar(src.codeUnitAt(j));
        if (isOpenBracket || isIdent) {
          // Find the matching close for the construct that follows.
          String open, close;
          if (isOpenBracket) {
            open = startChar;
            close = startChar == '[' ? ']' : '}';
          } else {
            // Skip the constructor chain (Ident.ident2) to its '('.
            var k = j;
            while (k < src.length && (isIdentChar(src.codeUnitAt(k)) || src[k] == '.')) {
              k++;
            }
            if (k < src.length && src[k] == '(') {
              open = '(';
              close = ')';
              j = k;
            } else {
              // const x = ... (a const variable declaration) — leave it.
              out.write(ch);
              i++;
              continue;
            }
          }
          // Balanced scan for `close`.
          var depth = 0;
          var k = j;
          var s = inString;
          var sc = '';
          var lc = false;
          var bc = false;
          var end = -1;
          while (k < src.length) {
            final c = src[k];
            final n2 = k + 1 < src.length ? src[k + 1] : '';
            if (lc) {
              if (c == '\n') lc = false;
              k++;
              continue;
            }
            if (bc) {
              if (c == '*' && n2 == '/') {
                bc = false;
                k++;
              }
              k++;
              continue;
            }
            if (s) {
              if (c == r'\') {
                k++;
              } else if (c == sc) {
                s = false;
              }
              k++;
              continue;
            }
            if (c == '/' && n2 == '/') {
              lc = true;
              k++;
              continue;
            }
            if (c == '/' && n2 == '*') {
              bc = true;
              k += 2;
              continue;
            }
            if (c == "'" || c == '"') {
              s = true;
              sc = c;
              k++;
              continue;
            }
            if (c == open) {
              depth++;
            } else if (c == close) {
              depth--;
              if (depth == 0) {
                end = k;
                break;
              }
            }
            k++;
          }
          if (end != -1) {
            final span = src.substring(j, end + 1);
            if (span.contains('AppTheme.')) {
              // Drop this `const` keyword.
              _changed = true;
              i += 5; // skip 'const'
              continue;
            }
          }
        }
      }
    }

    out.write(ch);
    i++;
  }
  return out.toString();
}

void main() {
  final root = Directory('lib');
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.replaceAll('\\', '/').endsWith('utils/app_theme.dart'))
      .toList();

  var touched = 0;
  for (final f in files) {
    _changed = false;
    final result = _transform(f.readAsStringSync());
    if (_changed) {
      f.writeAsStringSync(result);
      touched++;
      stdout.writeln('rewrote ${f.path}');
    }
  }
  stdout.writeln('done — $touched files updated');
}
