import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/npath_complexity.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/fsm_lexer.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/profiles/default_profiles.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/language_profile.dart';

int npath(LanguageProfile profile, String source) {
  final tokens = FsmLexer(source, profile.lexical).tokenize();
  return NpathComplexityAlgorithm().calculate(tokens, profile);
}

int npathDart(String body) =>
    npath(DefaultProfiles.dart, 'void f() {\n$body\n}');

void main() {
  group('NPath composition within a function (Dart)', () {
    test('branchless function is 1', () {
      expect(npathDart('print(1);'), 1);
    });

    test('single if', () {
      expect(npathDart('if (a) { x(); }'), 2);
    });

    test('if/else', () {
      expect(npathDart('if (a) { x(); } else { y(); }'), 2);
    });

    test('if/else-if/else chain', () {
      expect(
        npathDart('if (a) { x(); } else if (b) { y(); } else { z(); }'),
        3,
      );
    });

    test('if/else-if without else keeps the fall-through path', () {
      expect(npathDart('if (a) { x(); } else if (b) { y(); }'), 3);
    });

    test('two sequential ifs multiply', () {
      expect(npathDart('if (a) { x(); }\nif (b) { y(); }'), 4);
    });

    test('nested if adds to its branch', () {
      expect(npathDart('if (a) { if (b) { x(); } }'), 3);
    });

    test('composition is order-independent', () {
      // 3 (nested if) * 2 (plain if) regardless of statement order.
      expect(npathDart('if (a) { if (b) { x(); } }\nif (c) { y(); }'), 6);
      expect(npathDart('if (c) { y(); }\nif (a) { if (b) { x(); } }'), 6);
    });

    test('boolean operator in a condition adds a path', () {
      expect(npathDart('if (a && b) { x(); }'), 3);
    });

    test('standalone boolean operator doubles the statement', () {
      expect(npathDart('x = a && b;'), 2);
    });

    test('ternary doubles the statement', () {
      expect(npathDart('x = a ? b : c;'), 2);
    });

    test('nullable type and null-aware operators are not paths', () {
      expect(npathDart('int? x;\nfinal y = a?.b;\nfinal z = a ?? b;'), 1);
    });

    test('loop adds the skip path', () {
      expect(npathDart('for (var i = 0; i < n; i++) { x(); }'), 2);
    });

    test('do-while counts once', () {
      expect(npathDart('do { x(); } while (a);'), 2);
    });

    test('braceless if', () {
      expect(npathDart('if (a) return;'), 2);
    });

    test('braceless if/else', () {
      expect(npathDart('if (a) x(); else y();'), 2);
    });

    test('switch arms sum, default covers the fall-through', () {
      expect(
        npathDart(
          'switch (v) {\n'
          'case 1: a(); break;\n'
          'case 2: b(); break;\n'
          'case 3: c(); break;\n'
          'default: d();\n'
          '}',
        ),
        4,
      );
    });

    test('switch without default keeps the fall-through path', () {
      expect(
        npathDart(
          'switch (v) {\n'
          'case 1: a(); break;\n'
          'case 2: b(); break;\n'
          'case 3: c(); break;\n'
          '}',
        ),
        4,
      );
    });

    test('try is transparent, catch adds the exception path', () {
      expect(npathDart('try { if (a) { x(); } } catch (e) { y(); }'), 4);
    });

    test('clamps at 2^30', () {
      final ifs = List.filled(40, 'if (a) { x(); }').join('\n');
      expect(npathDart(ifs), 1 << 30);
    });
  });

  group('NPath function segmentation', () {
    test('paths of separate functions never multiply', () {
      const source = '''
void f() {
  if (a) {}
  if (b) {}
  if (c) {}
}

void g() {
  if (d) {}
  if (e) {}
  if (h) {}
}
''';
      // Each function is 2^3 = 8; the file reports the worst function.
      expect(npath(DefaultProfiles.dart, source), 8);
    });

    test('closure body is its own segment', () {
      const source = '''
void f() {
  items.forEach((x) {
    if (x) {}
  });
  if (a) {}
}
''';
      expect(npath(DefaultProfiles.dart, source), 2);
    });

    test('methods in a class are separate segments', () {
      const source = '''
class A {
  void f() {
    if (a) {}
    if (b) {}
  }

  void g() {
    if (c) {}
  }
}
''';
      expect(npath(DefaultProfiles.dart, source), 4);
    });

    test('branchless file with several functions is 1', () {
      const source = '''
void f() { print(1); }
void g() { print(2); }
void h() { print(3); }
''';
      expect(npath(DefaultProfiles.dart, source), 1);
    });
  });

  group('NPath indentation mode (Python)', () {
    test('nested ifs and separate defs', () {
      const source = '''
def f():
    if a:
        if b:
            pass

def g():
    if c:
        pass
''';
      // f = 3 (nested if), g = 2; max wins.
      expect(npath(DefaultProfiles.python, source), 3);
    });

    test('elif chain', () {
      const source = '''
def f():
    if a:
        pass
    elif b:
        pass
    else:
        pass
''';
      expect(npath(DefaultProfiles.python, source), 3);
    });

    test('single-line if body', () {
      const source = '''
def f():
    if a: return 1
    return 2
''';
      expect(npath(DefaultProfiles.python, source), 2);
    });
  });

  group('NPath keyword-end mode (Ruby)', () {
    test('separate defs do not multiply', () {
      const source = '''
def f
  if a
    x = 1
  end
end

def g
  if b
    y = 1
  end
end
''';
      expect(npath(DefaultProfiles.ruby, source), 2);
    });

    test('if/elsif/else arms sum', () {
      const source = '''
def f
  if a
    x = 1
  elsif b
    x = 2
  else
    x = 3
  end
end
''';
      expect(npath(DefaultProfiles.ruby, source), 3);
    });

    test('modifier if doubles the statement', () {
      const source = '''
def f
  x = 1 if a
end
''';
      expect(npath(DefaultProfiles.ruby, source), 2);
    });
  });

  group('NPath guard-clause (jump-terminator) folding — ADR-0019', () {
    test('single guard clause (return) is 2', () {
      // Guard: 1 terminated path + 1 fall-through = 2.
      expect(npathDart('if (a) { return; }\nx();'), 2);
    });

    test('two sequential guards are 3, not 4', () {
      // 2 terminated guard paths + 1 fall-through continuation = 3.
      // Standard NPath would be 2 × 2 = 4.
      expect(npathDart('if (a) { return; }\nif (b) { return; }\nx();'), 3);
    });

    test('three sequential guards are 4, not 8', () {
      // 3 terminated paths + 1 continuation = 4.
      // Standard NPath would be 2³ = 8.
      expect(
        npathDart(
          'if (a) { return; }\n'
          'if (b) { return; }\n'
          'if (c) { return; }\n'
          'x();',
        ),
        4,
      );
    });

    test('guard with throw is also folded additively', () {
      expect(npathDart('if (a) { throw e; }\nx();'), 2);
    });

    test('guard clause followed by non-guard if', () {
      // 1 terminated guard path + 2 (non-guard if: then + implicit else)
      // = 3.
      expect(npathDart('if (a) { return; }\nif (b) { x(); }'), 3);
    });

    test('non-guard if (no jump) is unchanged', () {
      // Standard: 2 × 2 = 4.  Neither branch ends with a jump.
      expect(npathDart('if (a) { x(); }\nif (b) { y(); }'), 4);
    });

    test('guard with compound condition keeps standard behaviour', () {
      // `if (a && b) return;` has boolOps > 0, so additive folding
      // does NOT apply — standard multiplication (3) is used.
      expect(npathDart('if (a && b) { return; }\nx();'), 3);
    });

    test('braceless guard clauses', () {
      // Braceless form: `if (a) return;`
      expect(npathDart('if (a) return;\nif (b) return;\nx();'), 3);
    });

    test('guard inside a loop with continue', () {
      // The loop body has: guard (continue) + x().
      // Guard (continue) = 1 terminated path; fall-through = x() = 1.
      // Body NPath = 1 + 1 = 2.  Loop = body + skip = 2 + 1 = 3.
      expect(
        npathDart(
          'for (var i = 0; i < n; i++) {\n'
          'if (bad) { continue; }\n'
          'x();\n'
          '}',
        ),
        3,
      );
    });

    test('if/else where else terminates is still 2', () {
      // Both branches are present, so it is a standard if/else = 2.
      // The `return` in else does not change the count since both
      // arms already sum.
      expect(npathDart('if (a) { x(); } else { return; }'), 2);
    });

    test('Python guard clauses (indentation mode)', () {
      const source = '''
def f():
    if a: return
    if b: return
    x()
''';
      expect(npath(DefaultProfiles.python, source), 3);
    });

    test('Ruby guard clauses (keyword-end mode)', () {
      const source = '''
def f
  if a
    return
  end
  if b
    return
  end
  x = 1
end
''';
      expect(npath(DefaultProfiles.ruby, source), 3);
    });
  });
}
