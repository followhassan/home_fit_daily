# Content and review status

All content is original text written for this app and bundled as JSON in
`assets/data/` (content version 1). It is checked automatically by
`CatalogValidator` (`test/data/catalog_content_test.dart`) for structure,
unique IDs, valid references, minimum text lengths, sensible ranges and
plan rules. Automated checks do not verify that the advice is correct.

## Review status

**No content has been reviewed by a qualified professional** (fitness
trainer, physiotherapist, physician or dietitian). Every article carries
`"reviewStatus": "unreviewed"`, and the app does not claim expert review
anywhere. The in-app health disclaimer states that the content is general
information and not medical advice.

Before release, a qualified reviewer should check at minimum:

- exercise instructions, cautions and easier/harder options;
- that workout and plan difficulty labels match their content;
- the safety, recovery and nutrition articles.

When an article is reviewed, record the reviewer and date, then change its
`reviewStatus`. Do not change it for content that was not reviewed.

## Inventory

| Type | Count | Breakdown |
| --- | --- | --- |
| Exercises | 88 | warm-up 7, full body 6, upper body 13, lower body 17, core 13, cardio 10, mobility 8, stretching 14 · beginner 56, intermediate 28, advanced 4 · 75 bodyweight, 13 using a chair, dumbbells or a resistance band |
| Workouts | 32 | full body 6, strength 5, upper body 2, lower body 3, core 4, cardio 3, quick break 3, mobility 3, stretching 3 · beginner 21, intermediate 9, advanced 2 |
| Plans (28 days each) | 4 | see below |
| Articles | 22 | getting started 3, technique 4, training 6, recovery 2, nutrition 2, mindset 3, safety 2 |
| Tips | 20 | short tips, each linked to an article |

### Plans

| Plan | Level | Workout days | Light recovery days | Rest days |
| --- | --- | --- | --- | --- |
| Beginner Home Fitness | Beginner | 12 | 4 | 12 |
| Bodyweight Strength Foundations | Intermediate | 15 | 4 | 9 |
| Low-Impact Movement | Beginner | 14 | 4 | 10 |
| Mobility & Consistency | Beginner | 20 (short mobility/stretch sessions) | 0 | 8 |

Every week of every plan contains at least one rest day.

## What the content deliberately avoids

- No calorie estimates, weight-loss promises or body-composition claims.
- No BMI, age- or sex-based targets.
- No diet plans or supplement advice; the nutrition articles stay general
  (hydration, balanced meals) and point to professionals for specific needs.
- No claims of medical or expert endorsement.

## References

Articles list references only as title, publisher and year (no links, since
the app is offline). Nine of the 22 articles list references; the other 13
are general guidance with none. The publications cited are:

- World Health Organization – *WHO guidelines on physical activity and
  sedentary behaviour* (2020)
- Department of Health and Social Care (UK) – *UK Chief Medical Officers'
  Physical Activity Guidelines* (2019)
- American College of Sports Medicine – *ACSM's Guidelines for Exercise
  Testing and Prescription*, 11th edition (2021)
- Borg, G. – *Borg's Perceived Exertion and Pain Scales*, Human Kinetics
  (1998)
- Watson et al. – *Recommended Amount of Sleep for a Healthy Adult*, Sleep
  (2015)
- EFSA – *Scientific Opinion on Dietary Reference Values for water* (2010)
- World Health Organization – *Healthy diet* fact sheet (undated)

These are real publications, cited from general knowledge of their
contents. The article text was **not** checked line by line against them;
a reviewer should do that before release.
