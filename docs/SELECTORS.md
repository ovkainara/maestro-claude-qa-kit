# Test ids: the contract between your app and the flows

Maestro does not see Flutter `Key`s or React `key`s. It reads the platform
accessibility tree, so an element is findable by `id:` only if your code puts an
identifier into that tree. This page shows how, per framework, and which ids the
kit's subflows expect.

## Naming

`snake_case`, `<area>_<element>`: `auth_login_email`, `nav_home`, `screen_main`.
Ids are a contract with the flows: before renaming or removing one, grep `.maestro/`.

Ids the kit's subflows expect out of the box:

| Id | Where | Used by |
|---|---|---|
| `screen_login` | root of the login screen | `launch`, `login`, `logout` |
| `screen_main` | root of the main shell shown after login | `launch`, `login`, `smoke/01` |
| `auth_login_email` | email field | `login` |
| `auth_login_password` | password field | `login` |
| `auth_login_submit` | login button | `login` |
| `nav_home`, `nav_search`, `nav_profile` | bottom-nav tabs (rename to yours) | `smoke/01`, `logout` |
| `home_avatar`, `drawer_logout` | opens profile menu, logout item (adapt) | `logout` |

Having ids on every **screen root** is the single most useful thing: it lets a flow
assert "I am on screen X" without depending on texts.

## Flutter

Use `Semantics(identifier: ...)`. It becomes the Android `resource-id` / iOS
`accessibilityIdentifier`. The kit ships a small widget for it:
[`examples/flutter/test_id.dart`](../examples/flutter/test_id.dart).

```dart
TestId('auth_login_submit', child: ElevatedButton(...))

// a whole screen
TestId('screen_login', child: Scaffold(...))
```

Why the widget sets `container: true` and `explicitChildNodes: true`:

- `container: true` gives the id its own semantics node; without it the id merges
  into an ancestor and lands on the wrong element.
- `explicitChildNodes: true` keeps that node empty, so the wrapped widgets keep their
  own labels and actions. Without it, wrapping a whole screen pulled a text into the
  full-screen node and a screen reader would outline the entire screen.

Consequence for flows: the `id:` node is an empty wrapper. `tapOn: id:` works (its
bounds match the child), but `enabled` / `clickable` checks on it look at the wrapper
and give a wrong answer. For those, target the nested element.

If a Flutter `Key` already exists, give the identifier the same name.

## React Native / Expo

Use `testID`. On Android it maps to `resource-id`, on iOS to
`accessibilityIdentifier`.

```tsx
<TextInput testID="auth_login_email" ... />
<Pressable testID="auth_login_submit" ... />

// screen root
<View testID="screen_login" style={{ flex: 1 }}>...</View>
```

Gotchas:

- `testID` on a custom component does nothing unless the component forwards it to a
  native view. Check your UI library.
- On Android, `testID` is exposed as `resource-id` only on views that are actually
  rendered natively (a `View` with `collapsable={false}` if it gets optimized away).
- Lists: give rows a stable id (`order_row_<id>`), not an index.

## Native Android (Kotlin / Java)

`android:id="@+id/auth_login_email"` in XML or `Modifier.testTag("auth_login_email")`
with `testTagsAsResourceId = true` on the Compose root:

```kotlin
Scaffold(modifier = Modifier.semantics { testTagsAsResourceId = true }) { ... }
```

## Selector priority in flows

1. `id:` — stable, language-independent.
2. `text:` — only when no id exists. Then set the UI language explicitly in the flow.
3. Relative / positional selectors — last resort, documented in the flow comment.

When a needed id is missing, the tester writes the flow by text and lists the id as a
candidate in the report. Adding the id is a one-line change in the app; after that the
flow is switched to `id:`.
