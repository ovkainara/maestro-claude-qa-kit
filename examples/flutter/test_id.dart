import 'package:flutter/widgets.dart';

/// Stable id for UI automation (Maestro E2E flows in `.maestro/`).
///
/// Maestro cannot see Flutter [Key]s: it reads the platform accessibility
/// tree. [Semantics.identifier] becomes the Android `resource-id` / iOS
/// `accessibilityIdentifier`, which Maestro matches with `id:`. Unlike a text
/// selector it does not change with the UI language (en / es / ...).
///
/// `container: true` gives the id its own semantics node. Without it the id
/// is merged into an ancestor's node and lands on the wrong element.
///
/// `explicitChildNodes: true` keeps that node empty: the wrapped widgets keep
/// their own nodes instead of merging their labels and actions into it.
/// Without it, wrapping a whole screen pulled the login slogan's text into
/// the full-screen node, so a screen reader would outline the entire screen
/// when reading one line (found by a Maestro smoke flow).
///
/// Naming: snake_case `<area>_<element>` (`auth_login_email`, `nav_home`),
/// equal to the widget's Key where one exists. Ids are a contract with the
/// flows: before renaming or removing one, grep `.maestro/` for it.
class TestId extends StatelessWidget {
  const TestId(this.id, {super.key, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        explicitChildNodes: true,
        identifier: id,
        child: child,
      );
}
