// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'server_abstract.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ServerTest);
  });
}

@reflectiveTest
class ServerTest extends AbstractLspAnalysisServerTest {
  test_inconsistentStateError() async {
    await initialize();
    await openFile(mainFileUri, '');
    // Attempt to make an illegal modification to the file. This indicates the
    // client and server are out of sync and we expect the server to shut down.
    final error = await expectErrorNotification<ShowMessageParams>(() async {
      await changeFile(222, mainFileUri, [
        new TextDocumentContentChangeEvent(
            new Range(new Position(99, 99), new Position(99, 99)), null, ' '),
      ]);
    });

    expect(error, isNotNull);
    expect(error.message, contains('Invalid line'));

    // Wait for up to 10 seconds for the server to shutdown.
    await server.exited.timeout(const Duration(seconds: 10));
  }

  test_shutdown_initialized() async {
    await initialize();
    final request = makeRequest(Method.shutdown, null);
    final response = await channel.sendRequestToServer(request);
    expect(response.id, equals(request.id));
    expect(response.error, isNull);
    expect(response.result, isNull);
  }

  test_shutdown_uninitialized() async {
    final request = makeRequest(Method.shutdown, null);
    final response = await channel.sendRequestToServer(request);
    expect(response.id, equals(request.id));
    expect(response.error, isNull);
    expect(response.result, isNull);
  }

  test_unknownNotifications_logError() async {
    await initialize();

    final notification =
        makeNotification(new Method.fromJson(r'some/randomNotification'), null);

    final notificationParams = await expectErrorNotification<ShowMessageParams>(
      () => channel.sendNotificationToServer(notification),
    );
    expect(notificationParams, isNotNull);
    expect(
      notificationParams.message,
      contains('Unknown method some/randomNotification'),
    );
  }

  test_unknownOptionalNotifications_silentlyDropped() async {
    await initialize();
    final notification =
        makeNotification(new Method.fromJson(r'$/randomNotification'), null);
    final firstError = channel.errorNotificationsFromServer.first;
    channel.sendNotificationToServer(notification);

    // Wait up to 1sec to ensure no error/log notifications were sent back.
    var didTimeout = false;
    final notificationFromServer = await firstError.timeout(
      const Duration(seconds: 1),
      onTimeout: () {
        didTimeout = true;
      },
    );

    expect(notificationFromServer, isNull);
    expect(didTimeout, isTrue);
  }

  test_unknownRequest_rejected() async {
    await initialize();
    final request = makeRequest(new Method.fromJson('randomRequest'), null);
    final response = await channel.sendRequestToServer(request);
    expect(response.id, equals(request.id));
    expect(response.error, isNotNull);
    expect(response.error.code, equals(ErrorCodes.MethodNotFound));
    expect(response.result, isNull);
  }

  test_unknownOptionalRequest_rejected() async {
    await initialize();
    final request = makeRequest(new Method.fromJson(r'$/randomRequest'), null);
    final response = await channel.sendRequestToServer(request);
    expect(response.id, equals(request.id));
    expect(response.error, isNotNull);
    expect(response.error.code, equals(ErrorCodes.MethodNotFound));
    expect(response.result, isNull);
  }
}
