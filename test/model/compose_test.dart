import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/model/compose.dart';
import 'package:zulip/model/narrow.dart';

import '../example_data.dart' as eg;
import 'test_store.dart';

void main() {
  group('wrapWithBacktickFence', () {
    /// Check `wrapWithBacktickFence` on example input and expected output.
    ///
    /// The intended input (content passed to `wrapWithBacktickFence`)
    /// is straightforward to infer from `expected`.
    /// To do that, this helper takes `expected` and removes the opening and
    /// closing fences.
    ///
    /// Then we have the input to the test, as well as the expected output.
    void checkFenceWrap(String expected, {String? infoString, bool chopNewline = false}) {
      final re = RegExp(r'^.*?\n(.*\n|).*\n$', dotAll: true);
      String content = re.firstMatch(expected)![1]!;
      if (chopNewline) content = content.substring(0, content.length - 1);
      check(wrapWithBacktickFence(content: content, infoString: infoString)).equals(expected);
    }

    test('empty content', () {
      checkFenceWrap('''
```
```
''');
    });

    test('content consisting of blank lines', () {
      checkFenceWrap('''
```



```
''');
    });

    test('single line with no code blocks', () {
      checkFenceWrap('''
```
hello world
```
''');
    });

    test('multiple lines with no code blocks', () {
      checkFenceWrap('''
```
hello
world
```
''');
    });

    test('no code blocks; incomplete final line', () {
      checkFenceWrap(chopNewline: true, '''
```
hello
world
```
''');
    });

    test('three-backtick block', () {
      checkFenceWrap('''
````
hello
```
code
```
world
````
''');
    });

    test('multiple three-backtick blocks; one has info string', () {
      checkFenceWrap('''
````
hello
```
code
```
world
```javascript
// more code
```
````
''');
    });

    test('whitespace around info string', () {
      checkFenceWrap('''
````
``` javascript 
// hello world
```
````
''');
    });

    test('four-backtick block', () {
      checkFenceWrap('''
`````
````
hello world
````
`````
''');
    });

    test('five-backtick block', () {
      checkFenceWrap('''
``````
`````
hello world
`````
``````
''');
    });

    test('five-backtick block; incomplete final line', () {
      checkFenceWrap(chopNewline: true, '''
``````
`````
hello world
`````
``````
''');
    });

    test('three-, four-, and five-backtick blocks', () {
      checkFenceWrap('''
``````
```
hello world
```

````
hello world
````

`````
hello world
`````
``````
''');
    });

    test('dangling opening fence', () {
      checkFenceWrap('''
`````
````javascript
// hello world
`````
''');
    });

    test('code blocks marked by indentation or tilde fences don\'t affect result', () {
      checkFenceWrap('''
```
    // hello world

~~~~~~
code
~~~~~~
```
''');
    });

    test('backtick fences may be indented up to three spaces', () {
      checkFenceWrap('''
````
 ```
````
''');
      checkFenceWrap('''
````
  ```
````
''');
      checkFenceWrap('''
````
   ```
````
''');
      // but at 4 spaces of indentation it no longer counts:
      checkFenceWrap('''
```
    ```
```
''');
    });

    test('fence ignored if info string has backtick', () {
      checkFenceWrap('''
```
```java`script
hello
```
''');
    });

    test('with info string', () {
      checkFenceWrap(infoString: 'info', '''
`````info
```
hello
```
info
````python
hello
````
`````
''');
    });
  });

  group('narrowLink', () {
    test('AllMessagesNarrow', () {
      final store = eg.store();
      check(narrowLink(store, const AllMessagesNarrow())).equals(store.account.realmUrl.resolve('#narrow'));
    });

    test('StreamNarrow / TopicNarrow', () {
      void checkNarrow(String expectedFragment, {
        required int streamId,
        required String name,
        String? topic,
      }) {
        assert(expectedFragment.startsWith('#'), 'wrong-looking expectedFragment');
        final store = eg.store();
        store.addStream(eg.stream(streamId: streamId, name: name));
        final narrow = topic == null
          ? StreamNarrow(streamId)
          : TopicNarrow(streamId, topic);
        check(narrowLink(store, narrow)).equals(store.account.realmUrl.resolve(expectedFragment));
      }

      checkNarrow(streamId: 1,   name: 'announce',       '#narrow/stream/1-announce');
      checkNarrow(streamId: 378, name: 'api design',     '#narrow/stream/378-api-design');
      checkNarrow(streamId: 391, name: 'Outreachy',      '#narrow/stream/391-Outreachy');
      checkNarrow(streamId: 415, name: 'chat.zulip.org', '#narrow/stream/415-chat.2Ezulip.2Eorg');
      checkNarrow(streamId: 419, name: 'français',       '#narrow/stream/419-fran.C3.A7ais');
      checkNarrow(streamId: 403, name: 'Hshs[™~}(.',     '#narrow/stream/403-Hshs.5B.E2.84.A2~.7D.28.2E');

      checkNarrow(streamId: 48,  name: 'mobile', topic: 'Welcome screen UI',
                  '#narrow/stream/48-mobile/topic/Welcome.20screen.20UI');
      checkNarrow(streamId: 243, name: 'mobile-team', topic: 'Podfile.lock clash #F92',
                  '#narrow/stream/243-mobile-team/topic/Podfile.2Elock.20clash.20.23F92');
      checkNarrow(streamId: 377, name: 'translation/zh_tw', topic: '翻譯 "stream"',
                  '#narrow/stream/377-translation.2Fzh_tw/topic/.E7.BF.BB.E8.AD.AF.20.22stream.22');
    });

    test('DmNarrow', () {
      void checkNarrow(String expectedFragment, String legacyExpectedFragment, {
        required List<int> allRecipientIds,
        required int selfUserId,
      }) {
        assert(expectedFragment.startsWith('#'), 'wrong-looking expectedFragment');
        final store = eg.store();
        final narrow = DmNarrow(allRecipientIds: allRecipientIds, selfUserId: selfUserId);
        check(narrowLink(store, narrow)).equals(store.account.realmUrl.resolve(expectedFragment));
        store.connection.zulipFeatureLevel = 176;
        check(narrowLink(store, narrow)).equals(store.account.realmUrl.resolve(legacyExpectedFragment));
      }

      checkNarrow(allRecipientIds: [1], selfUserId: 1,
        '#narrow/dm/1-dm',
        '#narrow/pm-with/1-pm');
      checkNarrow(allRecipientIds: [1, 2], selfUserId: 1,
        '#narrow/dm/1,2-dm',
        '#narrow/pm-with/1,2-pm');
      checkNarrow(allRecipientIds: [1, 2, 3], selfUserId: 1,
        '#narrow/dm/1,2,3-group',
        '#narrow/pm-with/1,2,3-group');
      checkNarrow(allRecipientIds: [1, 2, 3, 4], selfUserId: 4,
        '#narrow/dm/1,2,3,4-group',
        '#narrow/pm-with/1,2,3,4-group');
    });

    // TODO other Narrow subclasses as we add them:
    //   starred, mentioned; searches; arbitrary
  });
}