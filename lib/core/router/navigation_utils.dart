import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/app_router.dart';

/// Pops the current go_router page without leaving a browser history entry that
/// re-opens it.
///
/// The default [BackButton] / AppBar leading calls [Navigator.maybePop]. With
/// go_router on web, that updates the URL by *pushing* the parent location, so
/// mouse/browser back returns to the page you just left.
///
/// This helper:
/// 1. Uses [GoRouter.pop] so the correct nested navigator is popped (raw
///    [Navigator.pop] on a root context can remove the last [ShellRoute] page
///    and assert "no pages left to show").
/// 2. Wraps the pop in [Router.neglect] so the parent URL *replaces* the
///    current history entry instead of stacking a new one.
///
/// When nothing can be popped (cold deep link), optionally [go]s to
/// [fallbackLocation].
void popPage(BuildContext context, {String? fallbackLocation}) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    Router.neglect(context, () {
      router.pop();
    });
    return;
  }
  if (fallbackLocation != null) {
    context.go(fallbackLocation);
  }
}

/// AppBar leading control that uses [popPage] instead of [Navigator.maybePop].
class AppBackButton extends StatelessWidget {
  /// Route to [go] to when the stack cannot pop (e.g. deep link).
  final String? fallbackLocation;

  const AppBackButton({super.key, this.fallbackLocation});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => popPage(context, fallbackLocation: fallbackLocation),
    );
  }
}

/// Handles desktop mouse "back" (side button) and OS browser-back keys.
///
/// On web the browser already maps mouse back to history navigation. Native
/// desktop does not, so we listen for [kBackMouseButton] pointer events and
/// [LogicalKeyboardKey.browserBack] / [LogicalKeyboardKey.goBack] and call
/// [popPage].
///
/// Place this around the [MaterialApp.router] child via `builder:`.
class DesktopBackGestureHandler extends StatefulWidget {
  final Widget child;

  const DesktopBackGestureHandler({super.key, required this.child});

  @override
  State<DesktopBackGestureHandler> createState() =>
      _DesktopBackGestureHandlerState();
}

class _DesktopBackGestureHandlerState extends State<DesktopBackGestureHandler> {
  @override
  void initState() {
    super.initState();
    if (AppPlatform.isDesktop) {
      HardwareKeyboard.instance.addHandler(_onKeyEvent);
    }
  }

  @override
  void dispose() {
    if (AppPlatform.isDesktop) {
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    }
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.goBack) {
      return _handleBack();
    }
    return false;
  }

  /// Context that can see [InheritedGoRouter] / the active navigator.
  ///
  /// [MaterialApp.builder] sits *above* go_router's [InheritedGoRouter], so
  /// this State's [context] cannot call [GoRouter.of]. Prefer the shell
  /// navigator (where tab/settings routes live), then the root navigator
  /// (full-screen overlays like now-playing).
  BuildContext? get _navContext =>
      shellNavigatorKey.currentContext ?? rootNavigatorKey.currentContext;

  /// Returns true when the event was consumed (route popped).
  bool _handleBack() {
    final navContext = _navContext;
    if (navContext == null || !navContext.mounted) return false;
    final router = GoRouter.maybeOf(navContext);
    if (router == null || !router.canPop()) return false;
    popPage(navContext);
    return true;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if ((event.buttons & kBackMouseButton) == 0) return;
    _handleBack();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.isDesktop) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
