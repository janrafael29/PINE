// Multi-page tour of main app navigation (modal replay from Settings).
library;

import 'package:flutter/material.dart';

import '../core/navigation_guide_content.dart';
import '../core/theme.dart';
import 'navigation_guide_preference_screen.dart';

class AppNavigationGuideScreen extends StatefulWidget {
  const AppNavigationGuideScreen({
    super.key,
    this.showPreferenceChooser = true,
  });

  /// If false (e.g. opened from Settings as a replay), last page is only "Close".
  final bool showPreferenceChooser;

  @override
  State<AppNavigationGuideScreen> createState() =>
      _AppNavigationGuideScreenState();
}

class _AppNavigationGuideScreenState extends State<AppNavigationGuideScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  late final List<NavigationGuideSlide> _slides =
      navigationGuideSlidesForCurrentUser();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _page >= _slides.length;

  void _closeReplay() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('App guide'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              if (widget.showPreferenceChooser) {
                _pageController.jumpToPage(_slides.length);
                setState(() => _page = _slides.length);
              } else {
                _closeReplay();
              }
            },
            child: Text(
              widget.showPreferenceChooser ? 'Skip to choice' : 'Close',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int i) => setState(() => _page = i),
              itemCount: _slides.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index < _slides.length) {
                  final NavigationGuideSlide slide =
                      _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            size: 56,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: (textTheme.titleLarge ?? const TextStyle())
                              .copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        NavigationGuideBodyText(segments: slide.body),
                      ],
                    ),
                  );
                }
                return _buildFinalPage(context);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _slides.length + 1,
                (int i) => Container(
                  width: i == _page ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: i == _page
                        ? AppTheme.primaryGreen
                        : colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          if (!_isLast)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFinalPage(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!widget.showPreferenceChooser) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 72,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'That’s the tour',
              textAlign: TextAlign.center,
              style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const NavigationGuideBodyText(
              segments: <({String text, bool highlight})>[
                (
                  text: 'You can open this guide anytime from ',
                  highlight: false,
                ),
                (
                  text: 'Settings',
                  highlight: true,
                ),
                (
                  text: '.',
                  highlight: false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _closeReplay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SingleChildScrollView(
      child: NavigationGuidePreferencePanel(),
    );
  }
}
