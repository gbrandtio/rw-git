![CI | rw_git](https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg)
## About

`rw_git` is a git wrapper that facilitates the out-of-the-box execution of common git operations.

## Features

- [x] `init`: Initialize a local GIT directory. If the local directory does not exist, it will be created.
- [x] `clone`: Clone a remote repository into a local folder. If the local directory does not exist, it will be created.
- [x] `checkout`: Checkout a GIT branch on the specified, existing directory.
- [x] `fetchTags`: Retrieve a list of tags of the specified repository.
- [x] `getCommitsBetween`: Retrieve a list of commits between two given tags.
- [x] `stats`: Get the number of lines inserted, deleted and number of files changed.

## Getting started

pubspec.yaml:
`rw_git: 1.0.0`

## Usage
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
