// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/src/lsp/constants.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'server_abstract.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RenameTest);
  });
}

@reflectiveTest
class RenameTest extends AbstractLspAnalysisServerTest {
  // TODO(dantup): send a rename without a version
  // TODO(dantup): file changes during computation?
  // TODO(dantup): send an old version of the doc?
  // TODO(dantup): check the version return matches?
  // TODO(dantup): a rename that fails on options step
  // TODO(dantup): a rename that fails on final step
  // TODO(dantup): renames across multiple files

  test_prepare_class() {
    const content = '''
    class MyClass {}
    final a = new [[My^Class]]();
    ''';

    return _test_prepare(content, 'MyClass');
  }

  test_prepare_classNewKeyword() async {
    const content = '''
    class MyClass {}
    final a = n^ew [[MyClass]]();
    ''';

    return _test_prepare(content, 'MyClass');
  }

  test_prepare_importPrefix() async {
    const content = '''
    import 'dart:async' as [[myPr^efix]];
    ''';

    return _test_prepare(content, 'myPrefix');
  }

  test_prepare_importWithoutPrefix() async {
    const content = '''
    imp[[^]]ort 'dart:async';
    ''';

    return _test_prepare(content, '');
  }

  test_prepare_importWithPrefix() async {
    const content = '''
    imp^ort 'dart:async' as [[myPrefix]];
    ''';

    return _test_prepare(content, 'myPrefix');
  }

  test_prepare_invalidRenameLocation() async {
    const content = '''
    main() {
      // comm^ent
    }
    ''';

    return _test_prepare(content, null);
  }

  test_prepare_sdkClass() async {
    const content = '''
    final a = new [[Ob^ject]]();
    ''';

    await initialize();
    await openFile(mainFileUri, withoutMarkers(content));

    final request = makeRequest(
      Method.textDocument_prepareRename,
      new TextDocumentPositionParams(
        new TextDocumentIdentifier(mainFileUri.toString()),
        positionFromMarker(content),
      ),
    );
    final response = await channel.sendRequestToServer(request);

    expect(response.id, equals(request.id));
    expect(response.result, isNull);
    expect(response.error, isNotNull);
    expect(response.error.code, ServerErrorCodes.FatalRefactoringProblem);
    expect(response.error.message, contains('is defined in the SDK'));
  }

  test_prepare_variable() async {
    const content = '''
    main() {
      var variable = 0;
      print([[vari^able]]);
    }
    ''';

    return _test_prepare(content, 'variable');
  }

  test_rename_class() {
    const content = '''
    class MyClass {}
    final a = new [[My^Class]]();
    ''';
    const expectedContent = '''
    class MyNewClass {}
    final a = new MyNewClass();
    ''';
    return _test_rename_withDocumentChanges(
        content, 'MyNewClass', expectedContent);
  }

  test_rename_classNewKeyword() async {
    const content = '''
    class MyClass {}
    final a = n^ew MyClass();
    ''';
    const expectedContent = '''
    class MyNewClass {}
    final a = new MyNewClass();
    ''';
    return _test_rename_withDocumentChanges(
        content, 'MyNewClass', expectedContent);
  }

  test_rename_importPrefix() {
    const content = '''
    import 'dart:async' as myPr^efix;
    ''';
    const expectedContent = '''
    import 'dart:async' as myNewPrefix;
    ''';
    return _test_rename_withDocumentChanges(
        content, 'myNewPrefix', expectedContent);
  }

  test_rename_importWithoutPrefix() {
    const content = '''
    imp^ort 'dart:async';
    ''';
    const expectedContent = '''
    import 'dart:async' as myAddedPrefix;
    ''';
    return _test_rename_withDocumentChanges(
        content, 'myAddedPrefix', expectedContent);
  }

  test_rename_importWithPrefix() {
    const content = '''
    imp^ort 'dart:async' as myPrefix;
    ''';
    const expectedContent = '''
    import 'dart:async' as myNewPrefix;
    ''';
    return _test_rename_withDocumentChanges(
        content, 'myNewPrefix', expectedContent);
  }

  test_rename_invalidRenameLocation() {
    const content = '''
    main() {
      // comm^ent
    }
    ''';
    return _test_rename_withDocumentChanges(content, 'MyNewClass', null);
  }

  test_rename_sdkClass() async {
    const content = '''
    final a = new [[Ob^ject]]();
    ''';

    await newFile(mainFilePath, content: withoutMarkers(content));
    await initialize();

    final request = makeRequest(
      Method.textDocument_rename,
      new RenameParams(
        new TextDocumentIdentifier(mainFileUri.toString()),
        positionFromMarker(content),
        'Object2',
      ),
    );
    final response = await channel.sendRequestToServer(request);

    expect(response.id, equals(request.id));
    expect(response.result, isNull);
    expect(response.error, isNotNull);
    expect(response.error.code, ServerErrorCodes.FatalRefactoringProblem);
    expect(response.error.message, contains('is defined in the SDK'));
  }

  test_rename_usingLegacyChangeInterface() async {
    // This test initializes without support for DocumentChanges (versioning)
    // whereas the other tests all use DocumentChanges support (preferred).
    const content = '''
    class MyClass {}
    final a = new My^Class();
    ''';
    const expectedContent = '''
    class MyNewClass {}
    final a = new MyNewClass();
    ''';

    await initialize();
    await openFile(mainFileUri, withoutMarkers(content), version: 222);

    final result = await rename(
      mainFileUri,
      222,
      positionFromMarker(content),
      'MyNewClass',
    );

    // Ensure applying the changes will give us the expected content.
    final contents = {
      mainFilePath: withoutMarkers(content),
    };
    applyChanges(contents, result.changes);
    expect(contents[mainFilePath], equals(expectedContent));
  }

  test_rename_variable() {
    const content = '''
    main() {
      var variable = 0;
      print([[vari^able]]);
    }
    ''';
    const expectedContent = '''
    main() {
      var foo = 0;
      print(foo);
    }
    ''';
    return _test_rename_withDocumentChanges(content, 'foo', expectedContent);
  }

  _test_prepare(String content, String expectedPlaceholder) async {
    await initialize();
    await openFile(mainFileUri, withoutMarkers(content));

    final result =
        await prepareRename(mainFileUri, positionFromMarker(content));

    if (expectedPlaceholder == null) {
      expect(result, isNull);
    } else {
      expect(result.range, equals(rangeFromMarkers(content)));
      expect(result.placeholder, equals(expectedPlaceholder));
    }
  }

  _test_rename_withDocumentChanges(
      String content, String newName, String expectedContent) async {
    await initialize(
      workspaceCapabilities:
          withDocumentChangesSupport(emptyWorkspaceClientCapabilities),
    );
    await openFile(mainFileUri, withoutMarkers(content), version: 222);

    final result = await rename(
      mainFileUri,
      222,
      positionFromMarker(content),
      newName,
    );

    if (expectedContent == null) {
      expect(result, isNull);
    } else {
      // Ensure applying the changes will give us the expected content.
      final contents = {
        mainFilePath: withoutMarkers(content),
      };
      applyDocumentChanges(contents, result.documentChanges);
      expect(contents[mainFilePath], equals(expectedContent));
    }
  }
}
