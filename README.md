rw_git is a GIT wrapper that provides out-of-the-box execution of common, useful
GIT operations.

## Features

- `init`: Initialize a local GIT directory. If the local directory does not exist, it will be created.
- `clone`: Clone a remote repository into a local folder. If the local directory does not exist, it will be created.
- `checkout`: Checkout a GIT branch on the specified, existing directory.
- `fetchTags`: Retrieve a list of tags of the specified repository.

- `getCommitsBetween`: Retrieve a list of commits between two given tags.
- `stats`: Get the number of lines inserted, deleted and number of files changed.

## Getting started



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

Retrieve statistics regarding code changes between two tags:
```dart
  ShortStatDto shortStatDto = await rwGit.stats(localDirectoryToCloneInto, oldTag, newTag);
  print('Number of lines inserted: ${shortStatDto.insertions}'
      ' Number of lines deleted: ${shortStatDto.deletions}'
      ' Number of files changed: ${shortStatDto.numberOfChangedFiles}');
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
