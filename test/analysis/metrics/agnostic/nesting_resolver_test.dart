import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/fsm_lexer.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/nesting_resolver.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/profiles/default_profiles.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/language_profile.dart';

NestingResolution resolveWith(LanguageProfile profile, String source) {
  final tokens = FsmLexer(source, profile.lexical).tokenize();
  return NestingResolver(profile).resolve(tokens);
}

void main() {
  group('NestingResolver braces mode', () {
    final dart = DefaultProfiles.dart;

    test('function and class bodies are neutral frames', () {
      final r = resolveWith(dart, '''
        class A {
          void main() {
            int x = 1;
          }
        }
      ''');
      expect(r.maxDepth, 0);
      expect(r.frameCount, 0);
    });

    test('control blocks nest, expression brackets do not', () {
      final r = resolveWith(dart, '''
        void main() {
          final xs = [1, [2, [3]]];
          foo(bar(baz(1)));
          if (a) {
            if (b) {}
          }
        }
      ''');
      expect(r.maxDepth, 2);
      expect(r.frameCount, 2);
    });

    test('closure argument opens a lambda frame', () {
      final r = resolveWith(dart, '''
        void main() {
          items.forEach((x) {
            if (x) {}
          });
        }
      ''');
      // lambda frame + if frame
      expect(r.maxDepth, 2);
    });

    test('arrow lambda opens a lambda frame via introducer', () {
      final js = DefaultProfiles.javascript;
      final r = resolveWith(js, '''
        const f = () => {
          if (a) {}
        };
      ''');
      expect(r.maxDepth, 2);
    });

    test('brace-less bodies clear the pending clause at the semicolon', () {
      final r = resolveWith(dart, '''
        void main() {
          if (a) return;
          {
            int x = 1;
          }
        }
      ''');
      // The standalone block after the brace-less if is neutral.
      expect(r.maxDepth, 0);
      expect(r.frameCount, 0);
    });

    test('unbalanced closers never drive depth negative', () {
      final r = resolveWith(dart, '} } if (a) {}');
      expect(r.maxDepth, 1);
      expect(r.depths.every((d) => d >= 0), isTrue);
    });
  });

  group('NestingResolver indentation mode', () {
    final python = DefaultProfiles.python;

    test('control indents nest, def/class indents do not', () {
      final r = resolveWith(python, '''
class A:
    def f(self):
        if a:
            for x in xs:
                pass
''');
      expect(r.maxDepth, 2); // if + for; class/def are structural
      expect(r.frameCount, 2);
    });

    test('flat siblings return to the same depth', () {
      final r = resolveWith(python, '''
def f():
    if a:
        pass
    if b:
        pass
''');
      expect(r.maxDepth, 1);
      expect(r.frameCount, 2);
    });

    test('blank and comment lines do not dedent', () {
      final r = resolveWith(python, '''
def f():
    if a:
        x = 1

        # interior comment
        y = 2
        if b:
            pass
''');
      expect(r.maxDepth, 2);
    });

    test('bracketed continuation lines do not dedent', () {
      final r = resolveWith(python, '''
def f():
    if a:
        g(x,
  y)
        if b:
            pass
''');
      expect(r.maxDepth, 2);
    });
  });

  group('NestingResolver keyword-end mode', () {
    test('ruby def is structural, control keywords nest, end pops', () {
      final r = resolveWith(DefaultProfiles.ruby, '''
def f
  if a
    while b
      x = 1
    end
  end
end
''');
      expect(r.maxDepth, 2);
      expect(r.frameCount, 2);
    });

    test('ruby modifier-if opens no block', () {
      final r = resolveWith(DefaultProfiles.ruby, '''
def f
  x = 1 if a
  y = 2
end
''');
      expect(r.maxDepth, 0);
    });

    test('ruby do-block counts as a lambda frame', () {
      final r = resolveWith(DefaultProfiles.ruby, '''
items.each do |x|
  if x
    y = 1
  end
end
''');
      expect(r.maxDepth, 2);
    });

    test('ruby while-do line opens a single frame', () {
      final r = resolveWith(DefaultProfiles.ruby, '''
while a do
  x = 1
end
''');
      expect(r.maxDepth, 1);
      expect(r.frameCount, 1);
    });

    test('shell if/for close with fi/done', () {
      final r = resolveWith(DefaultProfiles.shell, '''
for f in *; do
  if b; then
    echo x
  fi
done
''');
      expect(r.maxDepth, 2);
      expect(r.frameCount, 2);
    });

    test('lua function is structural and if nests', () {
      final r = resolveWith(DefaultProfiles.lua, '''
function f()
  if a then
    while b do
      x = 1
    end
  end
end
''');
      expect(r.maxDepth, 2);
    });
  });

  group('NestingResolver frame events', () {
    List<String> describe(NestingResolution r) => [
      for (final e in r.events) '${e.isOpen ? 'open' : 'close'}:${e.kind.name}',
    ];

    test('braces mode reports neutral, control, and lambda frames', () {
      final r = resolveWith(DefaultProfiles.dart, '''
        void main() {
          if (a) {}
          items.forEach((x) {});
        }
      ''');
      expect(describe(r), [
        'open:neutral',
        'open:control',
        'close:control',
        'open:lambda',
        'close:lambda',
        'close:neutral',
      ]);
    });

    test('indentation mode emits one close per dedented block', () {
      final r = resolveWith(DefaultProfiles.python, '''
def f():
    if a:
        if b:
            pass
x = 1
''');
      expect(describe(r), [
        'open:neutral',
        'open:control',
        'open:control',
        'close:control',
        'close:control',
        'close:neutral',
      ]);
    });

    test('keyword-end mode pairs openers with closers', () {
      final r = resolveWith(DefaultProfiles.ruby, '''
def f
  if a
    x = 1
  end
end
''');
      expect(describe(r), [
        'open:neutral',
        'open:control',
        'close:control',
        'close:neutral',
      ]);
    });

    test('events balance and existing depth metrics are unchanged', () {
      final r = resolveWith(DefaultProfiles.lua, '''
function f()
  if a then
    while b do
      x = 1
    end
  end
end
''');
      expect(r.maxDepth, 2);
      expect(r.frameCount, 2);
      final opens = r.events.where((e) => e.isOpen).length;
      final closes = r.events.where((e) => !e.isOpen).length;
      expect(opens, closes);
      expect(
        r.events.where((e) => e.kind != FrameKind.neutral && e.isOpen).length,
        r.frameCount,
      );
    });
  });
}
