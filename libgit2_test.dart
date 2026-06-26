import 'package:libgit2dart/libgit2dart.dart';

void main() {
  final repo = Repository.open('test');
  repo.setHead('refs/heads/branch');
  Checkout.head(repo: repo);
  repo.free();
}
