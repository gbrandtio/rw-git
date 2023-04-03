<p align="center">
  <img src="https://user-images.githubusercontent.com/72696535/226140405-3bd31f1e-8cbb-4506-99db-1f0abce7c3fe.png" style="width: 20%;"/>
</p>
<p align="center">
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg"/>
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/coverage.yml/badge.svg"/>
  <a href="https://codecov.io/gh/gbrandtio/rw-git" ><img src="https://codecov.io/gh/gbrandtio/rw-git/branch/main/graph/badge.svg?token=ETZPSI51EH"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

## About

`rw_git` is a git wrapper that facilitates the out-of-the-box execution of common git operations.  

<a href='https://pub.dev/documentation/rw_git/latest/rw_git/rw_git-library.html'><img src="https://img.shields.io/badge/Check-Documentation-blue?style=for-the-badge&logo=readthedocs" alt="Documentation" /></a><br>

## Features

- [x] `init`: Initialize a local GIT directory. If the local directory does not exist, it will be created.
- [x] `clone`: Clone a remote repository into a local folder. If the local directory does not exist, it will be created.
- [x] `checkout`: Checkout a GIT branch on the specified, existing directory.
- [x] `fetchTags`: Retrieve a list of tags of the specified repository.
- [x] `getCommitsBetween`: Retrieve a list of commits between two given tags.
- [x] `stats`: Get the number of lines inserted, deleted and number of files changed.
- [x] `contibutionsByAuthor`: Returns the number of contributions for every author of the repository.

## Getting started

pubspec.yaml:
`rw_git: 1.0.3`

## Usage
Import library:
```
import 'package:rw_git/rw_git.dart';
```

Initialize RwGit:
```dart
RwGit rwGit = RwGit();
```

Clone a remote repository:
```dart
String localDirectoryToCloneInto = _createCheckoutDirectory(localDirectoryName);
rwGit.clone(localDirectoryToCloneInto, repositoryToClone);
```

Fetch tags of a remote repository:
```dart
List<String> tags = await rwGit.fetchTags(localDirectoryToCloneInto);
print("Number of tags: ${tags.length}");
```

Retrieve the commits between two tags:
```dart
  List<String> listOfCommitsBetweenTwoTags = await rwGit.getCommitsBetween(localDirectoryToCloneInto, oldTag, newTag);
  print("Number of commits between $oldTag and $newTag: ${listOfCommitsBetweenTwoTags.length}");
```

Retrieve code-change statistics between two tags:
```dart
  ShortStatDto shortStatDto = await rwGit.stats(localDirectoryToCloneInto, oldTag, newTag);
  print('Number of lines inserted: ${shortStatDto.insertions}'
      ' Number of lines deleted: ${shortStatDto.deletions}'
      ' Number of files changed: ${shortStatDto.numberOfChangedFiles}');
```

## Additional information

Please file any issues on the [github issue tracker](https://github.com/gbrandtio/rw-git/issues).
