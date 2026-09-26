# Notes — Topic 5, GROUP BY, HAVING, aggregate functions
 
Working notes: what was found in the repository, what was checked against a live
database, what is still open.
 
Data for every task was read directly from the Supabase project
`construction-supply`.
 
---
 
## 1. Repository state at the start of the topic
 
**1.1 Fixed.** Double extension `…_create_suppliers_sites.sql.sql` renamed to
`.sql`.
 
**1.2 Five migrations with month and day transposed.** Five, not four:
`20261109124600_estimate_revisions.sql` was missing from the topic 4 list. Deferred
to the end of this topic.
 
| Now | Should be |
|---|---|
| `20261009133000_create_delivery_items.sql` | `20260910133000_…` |
| `20261009210000_add_not_empty_checks.sql` | `20260910210000_…` |
| `20261109111200_delivery_note_unique_per_year.sql` | `20260911111200_…` |
| `20261109124600_estimate_revisions.sql` | `20260911124600_…` |
| `20261109151900_unit_conversions.sql` | `20260911151900_…` |
 
**1.3 The remote project has no migration history.**
 
Tables were created by pasting SQL into the SQL Editor. The only tables with
"migration" in the name belong to Supabase itself, in schemas `auth`, `storage` and
`realtime`. Schema `supabase_migrations` does not exist.
 
Assessment, not fact: renaming the local files does not affect the remote project.
But `supabase db push` into this project would try to apply every migration from the
start and fail on the first `CREATE TABLE`.
 
**1.4 `schema-design.md` has drifted from the migrations in four places.** Deferred
to the end of this topic.
 
1. Line 5, "All nine tables" — there are eleven.
2. Section 6, column `estimates.number` still shows `UNIQUE`. The live database has
   only `estimates_number_revision_uq UNIQUE (number, revision)`;
   `estimates_number_uq` was dropped by `20261109124600`.
3. "Deferred to Block 2", item "Estimate versioning" describes `version` and
   `UNIQUE (number, version)` — already implemented in section 6 as `revision`.
4. "Deferred to Block 2", item "Unit conversion" — both tables exist and are
   described in sections 10 and 11.
**1.5 Estimate revisions.**
 
The topic 4 summary said the migration had no `revision` column; that was out of
date. `20261109124600_estimate_revisions.sql` adds it, and all six rows in the live
database have `revision = 1`.
 
Still open, from `notes.md` (topic 1), open question 6: which revision is in force.
Every candidate answer is an aggregate query of this topic:
 
- highest `revision` per `number`;
- highest `revision` per `number` among `status = 'approved'`;
- `max(revision) + 1` for the next revision, currently left to the application.
Planned as a task in the middle of this topic. Needs a second and third revision of
one estimate added to the data first; which rows is decided at that point.
 
---
 
## 2. Step 1: count, one group, GROUP BY, count over an outer join
 
**2.1 `count(*)` against `count(column)`.**
 
```sql
SELECT count(*) AS all_rows, count(description) AS with_description
FROM estimate_items;
```
 
One row: 12 and 0. All twelve `estimate_items.description` values are NULL.
`count(*)` counts every input row; `count(description)` counts only rows where the
expression is not NULL
([4.2.7](https://www.postgresql.org/docs/17/sql-expressions.html#SYNTAX-AGGREGATES)).
With aggregates and no `GROUP BY` the result is a single row.
 
**2.2 Two aggregates without labels lose a column.**
 
`SELECT count(*), count(description)` without `AS`: both output columns are named
`count`, after the function
([7.3.2](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-COLUMN-LABELS)).
Postgres returns both. The SQL Editor turns each row into an object keyed by column
name, so the second key overwrites the first and only one column is shown. Same as
topic 4, experiment 3.2 (`s.name, m.name`). Fixed by labelling every aggregate.
 
**2.3 `GROUP BY` forms groups only from rows that exist.**
 
`SELECT estimate_id, count(*) FROM estimate_items GROUP BY estimate_id` — 5 rows:
 
| estimate_items.estimate_id | count(*) |
|---|---|
| 1 | 4 |
| 2 | 2 |
| 3 | 3 |
| 4 | 1 |
| 6 | 2 |
 
Estimate 5 is absent: no row in `estimate_items` has `estimate_id = 5`, so there is
nothing to group. Check: 4 + 2 + 3 + 1 + 2 = 12, the row count of `estimate_items`.
 
**2.4 `count(*)` and `count(ei.id)` after `LEFT OUTER JOIN`.**
 
```sql
SELECT e.id, count(*) AS all_rows, count(ei.id) AS item_rows
FROM estimates AS e
LEFT OUTER JOIN estimate_items AS ei ON ei.estimate_id = e.id
GROUP BY e.id
ORDER BY e.id;
```
 
`FROM` gives 13 rows: 12 matched, plus one added for estimate 5 with NULL in every
`ei` column. `GROUP BY` gives 6 groups.
 
| id | all_rows | item_rows |
|---|---|---|
| 1 | 4 | 4 |
| 2 | 2 | 2 |
| 3 | 3 | 3 |
| 4 | 1 | 1 |
| 5 | 1 | 0 |
| 6 | 2 | 2 |
 
Check from the other side:
 
- Sum of `all_rows` = 13 = rows of the intermediate table from `FROM`. Every row of
  it falls into exactly one group, so the two must match. If they do not, the
  grouping lost or multiplied rows.
- Sum of `item_rows` = 12 = rows of `estimate_items`. The added row for estimate 5
  has `ei.id` NULL and is not counted.
Why the check matters: in topic 4, experiment 3.4, estimate 1 joined to
`supplier_materials` became 7 rows and summed to 27520.00 instead of 15080.00.
 
---
 
## 3. Step 2: sum, NULL, HAVING, WHERE against HAVING
 
**3.1 Estimate totals.**
 
```sql
SELECT e.id, sum(ei.total) AS estimate_total
FROM estimates AS e
LEFT OUTER JOIN estimate_items AS ei ON e.id = ei.estimate_id
GROUP BY e.id
ORDER BY e.id;
```
 
| estimates.id | estimates.number | estimate_total |
|---|---|---|
| 1 | EST-2025-001 | 15080.00 |
| 2 | EST-2025-014 | 1288.00 |
| 3 | EST-2025-022 | 13965.00 |
| 4 | EST-2025-019 | 1380.00 |
| 5 | EST-2026-003 | NULL |
| 6 | EST-2024-007 | 9730.00 |
 
Check: sum of `estimate_total` = 41443.00 = sum of all twelve
`estimate_items.total`.
 
**3.2 Estimate 5 gives NULL, not 0.** Three steps:
 
1. `LEFT OUTER JOIN` adds one row for estimate 5 with `ei.total` NULL.
2. `sum` skips rows where the expression is NULL (4.2.7). No input values are left.
3. Except for `count`, aggregates return NULL when no rows are selected; `sum` of no
   rows is NULL, not zero
   ([9.21](https://www.postgresql.org/docs/17/functions-aggregate.html)).
If `ei.total` were 0, the result would be 0: zero is an ordinary value.
 
**3.3 `HAVING sum(ei.total) > 10000` returns 2 rows.**
 
Estimate 1 (15080.00) and estimate 3 (13965.00). Excluded 4 groups: 2, 4, 5, 6;
2 + 4 = 6.
 
Estimate 5: `NULL > 10000` is NULL. `HAVING`, like `WHERE`, keeps a group only when
the condition is true. The group exists; it is excluded from the result.
 
**3.4 `WHERE ei.total > 1000` instead of `HAVING`.**
 
`WHERE` selects input rows before groups and aggregates are computed; `HAVING`
selects group rows after
([2.7](https://www.postgresql.org/docs/17/tutorial-agg.html)).
 
- Of the 13 rows from `FROM`, `WHERE` drops four: `estimate_items.id` 6, 9, 12,
  and the row added for estimate 5 (`NULL > 1000` is NULL). 9 rows remain.
- 5 groups: 1 — 15080.00, 2 — 1080.00, 3 — 13560.00, 4 — 1380.00, 6 — 9480.00.
- Check: sum of `estimate_total` = 40580.00 = sum of the nine rows `WHERE` kept.
  Dropped rows: 208.00 + 405.00 + 250.00 = 863.00; 40580.00 + 863.00 = 41443.00.
- Estimate 5 disappears at `WHERE`. A condition on a column of the right table in
  `WHERE` turns the `LEFT OUTER JOIN` into an inner join — rules_04, 7.3.
---
 
## 4. Practice
 
- Six tasks so far. Two queries written by the student, tasks 4 and 5, both correct
  on the first send.
- Predictions checked from the other side: tasks 2, 3, 4, 5, 6.
- Not done: PGExercises, sections Joins and Aggregates.
---
 
## 5. Open questions
 
1. **Five migrations with transposed dates** (1.2). End of this topic.
2. **`schema-design.md`, four drifts** (1.4). End of this topic.
3. **No migration history in the remote project** (1.3). Decide how the remote is
   updated from now on, before the first `db push`.
4. **Which revision is in force** (1.5). Task in this topic.
5. **Carried from topic 4, unchanged.** `seed.sql` hard-codes surrogate ids; no
   `CHECK` on date consistency in `sites`; delivery line 7 dated before its site's
   `start_date`; no constraint for `from_unit_id <> materials.unit_id` in
   `material_unit_conversions`.
---
 
## 6. How the tutoring should run (for the next chat)
 
Carried from topic 4:
 
- One question at a time. The question itself is one or two lines, and the data
  needed to answer it is in the same message.
- Every value in the data is named `table.column`. Each column header says what it
  holds: a value, a reference to another table's column, or a count.
- One documentation link plus two or three lines summarising it — no more. The
  summary repeats what the section says and contains no inferences; inferences are
  the student's job.
- Only terms that appear in the official documentation. Anything else is flagged as
  such.
- Tasks name the file, table and line explicitly. No "as above", "in the same
  style".
- Nothing outside the current topic, and nothing about constructions the query does
  not contain.
- Wrong answer: do not give the right one, do not explain — ask a narrowing
  question against the student's own data, until he answers or asks for the answer.
- Right answer: one word plus one sentence of why, then the next question.
- The mistakes log is kept silently and shown only in the topic summary.
Added in this topic:
 
- Repository files are written by the tutor, only when asked. At the end of each
  major step the tutor asks whether to record it.
- No ranges or abbreviations in data: every value written out. Nothing that can be
  read two ways — `1–4` was read as either "1, 2, 3, 4" or "1 and 4".
- Tasks use a fixed format, sections in this order: where to read; short, by the
  text of the documentation; what is needed; what to output; relation; data;
  requirements; what to send, numbered.
- Every aggregate in a given query carries an `AS` label.
