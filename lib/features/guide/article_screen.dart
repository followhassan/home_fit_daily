import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/guide_article.dart';
import '../../state/guide_controller.dart';
import '../exercise_library/exercise_detail_screen.dart';
import '../workouts/workout_detail_screen.dart';

/// Reads an article and records how far the user has scrolled.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.article});

  final GuideArticle article;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  final _scroll = ScrollController();
  late final GuideController _guide = context.read<GuideController>();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _guide.markOpened(widget.article.id).ignore();
    // Short articles may fit without scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final fraction = position.maxScrollExtent <= 0
        ? 1.0
        : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    _guide.recordProgress(widget.article.id, fraction).ignore();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    final catalog = context.read<Catalog>();
    final bookmarked = context.select<GuideController, bool>((g) => g.isBookmarked(a.id));
    final related = catalog.articlesByIds(a.relatedArticleIds);
    final exercises = catalog.exercisesByIds(a.relatedExerciseIds);
    final workouts = catalog.workoutsByIds(a.relatedWorkoutIds);
    final text = context.text;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.category.label),
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            color: bookmarked ? context.palette.accentInk : null,
            onPressed: () async {
              try {
                final now = await context.read<GuideController>().toggleBookmark(a.id);
                if (context.mounted) showMessage(context, now ? 'Bookmarked' : 'Bookmark removed');
              } catch (_) {
                if (context.mounted) showMessage(context, 'Could not update the bookmark.');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 680,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
            children: [
              Semantics(header: true, child: Text(a.title, style: text.headlineMedium)),
              const SizedBox(height: Space.xs),
              Text('${a.readingTimeMinutes} min read', style: text.bodySmall),
              const SizedBox(height: Space.md),
              Text(
                a.summary,
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.5),
              ),
              for (final section in a.sections) ...[
                SectionHeader(title: section.heading),
                for (final p in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.md),
                    child: Text(p, style: text.bodyLarge?.copyWith(height: 1.55)),
                  ),
                for (final b in section.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: Space.sm),
                          child: Icon(Icons.circle, size: 6, color: context.palette.accentInk),
                        ),
                        Expanded(child: Text(b, style: text.bodyLarge?.copyWith(height: 1.5))),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: Space.lg),
              AppCard(
                padding: const EdgeInsets.all(Space.md),
                child: Text(
                  'General information only, not medical advice. ${a.reviewStatus.label}. '
                  'If a health condition or injury affects how you exercise, ask a qualified professional.',
                  style: text.bodySmall,
                ),
              ),
              if (a.references.isNotEmpty) ...[
                const SectionHeader(title: 'References'),
                for (final r in a.references)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: Text('• ${r.citation}', style: text.bodySmall),
                  ),
              ],
              if (workouts.isNotEmpty || exercises.isNotEmpty) ...[
                const SectionHeader(title: 'Try it'),
                for (final w in workouts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text(w.title),
                    subtitle: const Text('Workout'),
                    onTap: () => Nav.push(context, WorkoutDetailScreen(workout: w)),
                  ),
                for (final e in exercises)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.accessibility_new_rounded),
                    title: Text(e.name),
                    subtitle: const Text('Exercise'),
                    onTap: () => Nav.push(context, ExerciseDetailScreen(exercise: e)),
                  ),
              ],
              if (related.isNotEmpty) ...[
                const SectionHeader(title: 'Related articles'),
                for (final r in related)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(r.title),
                    subtitle: Text('${r.readingTimeMinutes} min read'),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: r)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
