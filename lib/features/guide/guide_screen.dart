import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/guide_article.dart';
import '../../state/guide_controller.dart';
import '../shell/main_shell.dart';
import 'article_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _search = TextEditingController();
  String _query = '';
  ArticleCategory? _category;
  bool _bookmarksOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(GuideArticle a, GuideController guide) {
    if (_category != null && a.category != _category) return false;
    if (_bookmarksOnly && !guide.isBookmarked(a.id)) return false;
    final terms = _query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return terms.every(a.searchText.contains);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<Catalog>();
    final guide = context.watch<GuideController>();
    final results = catalog.articles.where((a) => _matches(a, guide)).toList();
    final continueId = guide.continueReadingId;
    final continueArticle = continueId == null ? null : catalog.article(continueId);
    final filtering = _query.isNotEmpty || _category != null || _bookmarksOnly;

    return Scaffold(
      appBar: AppBar(title: const Text('Guide'), actions: const [SettingsAction()]),
      body: ContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
              sliver: SliverList.list(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search the guide',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (q) => setState(() => _query = q),
                  ),
                  const SizedBox(height: Space.sm),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: Space.sm),
                          child: FilterChip(
                            avatar: const Icon(Icons.bookmark_border_rounded, size: 16),
                            label: const Text('Bookmarked'),
                            selected: _bookmarksOnly,
                            onSelected: (v) => setState(() => _bookmarksOnly = v),
                          ),
                        ),
                        for (final c in ArticleCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(right: Space.sm),
                            child: ChoiceChip(
                              label: Text(c.label),
                              selected: _category == c,
                              onSelected: (on) => setState(() => _category = on ? c : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (continueArticle != null && !filtering) ...[
                    const SectionHeader(title: 'Continue reading'),
                    _ArticleCard(article: continueArticle),
                  ],
                  SectionHeader(
                    title: filtering ? '${results.length} articles' : 'All articles',
                    actionLabel: filtering ? 'Clear' : null,
                    onAction: () {
                      _search.clear();
                      setState(() {
                        _query = '';
                        _category = null;
                        _bookmarksOnly = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            if (results.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: _bookmarksOnly ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
                  title: _bookmarksOnly ? 'No bookmarks yet' : 'No articles match',
                  message: _bookmarksOnly
                      ? 'Tap the bookmark icon on an article to save it here.'
                      : 'Try a different word or category.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) => _ArticleCard(article: results[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final GuideArticle article;

  @override
  Widget build(BuildContext context) {
    final guide = context.watch<GuideController>();
    final state = guide.stateOf(article.id);
    return AppCard(
      onTap: () => Nav.push(context, ArticleScreen(article: article)),
      semanticLabel:
          '${article.title}. ${article.category.label}, '
          '${article.readingTimeMinutes} minute read'
          '${state.isFinished
              ? ', read'
              : state.isStarted
              ? ', ${(state.progress * 100).round()} percent read'
              : ''}'
          '${state.bookmarked ? ', bookmarked' : ''}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${article.category.label} · ${article.readingTimeMinutes} min read',
                    style: context.text.labelMedium?.copyWith(color: context.palette.accentInk),
                  ),
                ),
                if (state.bookmarked)
                  Icon(Icons.bookmark_rounded, size: 18, color: context.palette.accentInk),
                if (state.isFinished)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.xs),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: context.palette.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(article.title, style: context.text.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              article.summary,
              style: context.text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (state.isStarted && !state.isFinished) ...[
              const SizedBox(height: Space.sm),
              LinearProgressIndicator(
                value: state.progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
