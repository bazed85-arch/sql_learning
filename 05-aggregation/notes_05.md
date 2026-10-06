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
- 5 groups: 1 — 15080.00, 2 — 1080.00, 3 — 13560.00, 4 — 1380.00,
  6 — 9480.00.
- Check: sum of `estimate_total` = 40580.00 = sum of the nine rows `WHERE` kept.
  Dropped rows: 208.00 + 405.00 + 250.00 = 863.00; 40580.00 + 863.00 = 41443.00.
- Estimate 5 disappears at `WHERE`. A condition on a column of the right table in
  `WHERE` turns the `LEFT OUTER JOIN` into an inner join — rules_04, 7.3.
---
 
## 4. Step 3: columns outside GROUP BY, DISTINCT, avg / min / max
 
**4.1 A column that is not in `GROUP BY` and not inside an aggregate.**
 
```sql
SELECT ei.estimate_id, ei.material_id, count(*) AS item_rows
FROM estimate_items AS ei
GROUP BY ei.estimate_id
ORDER BY ei.estimate_id;
```
 
Not run; the student predicted the error and named the cause. Rule
([7.2.3](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-GROUP)):
once a table is grouped, columns not listed in `GROUP BY` can be referenced only
inside aggregate expressions.
 
- Group `estimate_id` = 1 has four rows with `ei.material_id` 1, 5, 8, 4. The group
  row has room for one value; none of the four is preferred. The value 4, first
  named by the student, followed from neither the data nor the rule.
- Group `estimate_id` = 4 has one row, `ei.material_id` = 2. The query would still
  fail: the check runs on the text of the query, not on how many rows the groups
  happen to hold.
Term: "group row" is the whole result row built for a group — grouping value,
aggregate results, everything. `count(*)` is one value inside it, not the row.
 
**4.2 `count(DISTINCT …)`.**
 
```sql
SELECT count(ei.material_id) AS item_rows,
       count(DISTINCT ei.material_id) AS distinct_materials
FROM estimate_items AS ei;
```
 
One row: 12 and 10
([4.2.7](https://www.postgresql.org/docs/17/sql-expressions.html#SYNTAX-AGGREGATES)).
 
- Repeated values: `ei.material_id` 4 in `estimate_items.id` 4 and 5; 11 in
  `estimate_items.id` 6 and 12.
- Distinct values: 1, 2, 3, 4, 5, 6, 8, 9, 10, 11 — ten.
  12 rows − 2 repeats = 10.
- `item_rows` is 12 because `count(expression)` counts rows where the expression is
  not NULL, and `NOT NULL` on `estimate_items.material_id` leaves no NULL to skip.
  Same rule as task 1, where all twelve `description` values were NULL and the count
  was 0.
**4.3 `avg`, `min`, `max` and NULL.**
 
```sql
SELECT count(*) AS all_rows,
       count(sm.lead_time_days) AS with_lead_time,
       avg(sm.lead_time_days) AS avg_days,
       min(sm.lead_time_days) AS min_days,
       max(sm.lead_time_days) AS max_days
FROM supplier_materials AS sm;
```
 
([9.21](https://www.postgresql.org/docs/17/functions-aggregate.html).) One row:
 
| all_rows | with_lead_time | avg_days | min_days | max_days |
|---|---|---|---|---|
| 13 | 12 | 2.42 | 0 | 7 |
 
- One NULL: `supplier_materials` supplier 7, material 10 (inactive row).
- `avg_days` = 29 / 12 = 2.4166…, rounded 2.42. The sum of the twelve non-NULL
  values is 29; the divisor is `with_lead_time`, not `all_rows`.
- With divisor 13 the result would be 2.23. They differ, so NULL enters neither the
  sum nor the divisor.
- `avg` of an `integer` column is `numeric`, hence 2.4166…, not 2.
- `min_days` = 0 from supplier 6, materials 1 and 11. `max_days` = 7 from
  supplier 4, material 3. The NULL row does not take part in either.
---
 
## 5. Step 4: GROUP BY on two columns, row multiplication, min / max over a join
 
**5.1 `GROUP BY` on two columns.**
 
```sql
SELECT d.status, d.year_no, count(*) AS delivery_rows
FROM deliveries AS d
GROUP BY d.status, d.year_no
ORDER BY d.year_no, d.status;
```
 
A group is formed only from rows that have the same values in all listed columns
([7.2.3](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-GROUP)).
`deliveries.year_no` is the generated column from `20261109111200`. 6 groups:
 
| status | year_no | delivery_rows |
|---|---|---|
| received | 2024 | 1 |
| rejected | 2024 | 1 |
| received | 2025 | 3 |
| received_with_issues | 2025 | 1 |
| draft | 2026 | 1 |
| received | 2026 | 2 |
 
- `received` in 2025 and `received` in 2026 are two groups: one column matches, the
  other does not.
- `GROUP BY d.status` alone gives 4 groups: received 6, received_with_issues 1,
  rejected 1, draft 1.
- Check: sum of `delivery_rows` = 9 = rows of `deliveries`.
**5.2 `sum` after a join that multiplies rows.**
 
```sql
SELECT sum(ei.total) AS joined_total,
       count(*) AS joined_rows,
       count(DISTINCT ei.id) AS item_rows
FROM estimate_items AS ei
INNER JOIN supplier_materials AS sm ON ei.material_id = sm.material_id
WHERE ei.estimate_id = 1;
```
 
For each row R1 of T1, the joined table has a row for each row of T2 that satisfies
the join condition with R1
([7.2.1.1](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-JOIN)).
 
| estimate_items.id | estimate_items.total | matching `supplier_materials` rows |
|---|---|---|
| 1 | 2760.00 | 2 |
| 2 | 6800.00 | 2 |
| 3 | 2640.00 | 1 |
| 4 | 2880.00 | 2 |
 
- `joined_rows` = 2 + 2 + 1 + 2 = 7; `item_rows` = 4.
- `joined_total` = 2760.00 × 2 + 6800.00 × 2 + 2640.00 × 1 + 2880.00 × 2
  = 27520.00. The sum of the four rows without the join is 15080.00.
- The query runs without error and returns a plausible number. The sign that rows
  were multiplied is `count(*)` ≠ `count(DISTINCT ei.id)`: 7 against 4.
- Same numbers as topic 4, experiment 3.4.
- The join in this task is deliberately wrong for a total. It is right for looking
  at the supplier rows one by one (5.3). The price of a material at a given supplier
  is `supplier_materials.price`, one row per supplier-material pair.
**5.3 `min` and `max` over a grouped join.**
 
```sql
SELECT ei.id AS id,
       ei.material_id AS material_id,
       count(*) AS supplier_rows,
       min(sm.price) AS min_price,
       max(sm.price) AS max_price
FROM estimate_items AS ei
INNER JOIN supplier_materials AS sm ON ei.material_id = sm.material_id
WHERE ei.estimate_id = 1
GROUP BY ei.id, ei.material_id
ORDER BY ei.id;
```
 
4 rows:
 
| id | material_id | supplier_rows | min_price | max_price |
|---|---|---|---|---|
| 1 | 1 | 2 | 6.80 | 7.40 |
| 2 | 5 | 2 | 780.00 | 845.00 |
| 3 | 8 | 1 | 41.50 | 41.50 |
| 4 | 4 | 2 | 8.60 | 9.40 |
 
- Check: sum of `supplier_rows` = 7 = `joined_rows` of 5.2. Same join condition,
  same `WHERE`.
- `min_price` = `max_price` in row 3: material 8 has one supplier row (supplier 3),
  so the group holds one value.
---
 
## 6. Step 5: aggregate in WHERE, ON against WHERE, HAVING over a join
 
**6.1 An aggregate in `WHERE`.**
 
```sql
SELECT e.id, sum(ei.total) AS estimate_total
FROM estimates AS e
LEFT OUTER JOIN estimate_items AS ei ON e.id = ei.estimate_id
WHERE sum(ei.total) > 10000
GROUP BY e.id
ORDER BY e.id;
```
 
Not run; the student predicted the error and named the clause. Aggregate functions
can appear only in the select list or in `HAVING`
([4.2.7](https://www.postgresql.org/docs/17/sql-expressions.html#SYNTAX-AGGREGATES)).
`WHERE` is evaluated before aggregate results exist; `HAVING` after. The condition
belongs in `HAVING sum(ei.total) > 10000`, after `GROUP BY`; it returns estimates 1
and 3 (3.3).
 
**6.2 `ON` against `WHERE` when counting the right table.**
 
Query A, condition in `ON`; query B, the same condition in `WHERE`:
 
```sql
-- A
SELECT s.id AS id, count(e.id) AS approved_estimates
FROM sites AS s
LEFT OUTER JOIN estimates AS e ON e.site_id = s.id AND e.status = 'approved'
GROUP BY s.id
ORDER BY s.id;
-- B: ON e.site_id = s.id only, and WHERE e.status = 'approved'
```
 
| sites.id | A: approved_estimates | B: approved_estimates |
|---|---|---|
| 1 | 1 | 1 |
| 2 | 1 | 1 |
| 3 | 1 | 1 |
| 4 | 0 | — |
| 5 | 0 | — |
| 6 | 0 | — |
 
A returns 6 rows, B returns 3. Both sums are 3 = the approved estimates in the data
(`estimates.id` 1, 3, 6).
 
Site 4 has one estimate, `estimates.id` = 4, status `rejected`.
 
- **In A** the condition of `ON` is
  `e.site_id = s.id AND e.status = 'approved'`. For the pair (site 4, estimate 4)
  the first part is true, the second false, so the whole condition is false and
  the pair is never formed. Site 4 has no pair, so `LEFT OUTER JOIN` adds one row
  with NULL in every `estimates` column. The site stays in the result with 0.
- **In B** the join forms the pair (4, 4, `rejected`). `WHERE` then discards it:
  `rejected = 'approved'` is false. Site 4 has no rows left, so its group does not
  exist. The outer join collapsed into an inner join: rules_04, 7.3.
- **`count(*)` in A** would give 1 for all six sites, sum 6. Each group holds one
  row, and in sites 4, 5 and 6 that row is the one the outer join added. A site
  with one approved estimate and a site with none would look the same. After a
  `LEFT OUTER JOIN`, count a column of the right table that is not NULL in a real
  row: `e.id`.
**6.3 `HAVING count(e.id) = 0` finds left rows without a match.**
 
```sql
SELECT s.id AS id
FROM sites AS s
LEFT OUTER JOIN estimates AS e ON e.site_id = s.id AND e.status = 'approved'
GROUP BY s.id
HAVING count(e.id) = 0
ORDER BY s.id;
```
 
3 rows: sites 4, 5, 6. `HAVING` excluded 3 groups (1, 2, 3); 3 + 3 = 6 = rows of
`sites`.
 
- In the group of site 4 the single row has `e.id` NULL. `count(expression)` skips
  NULL (4.2.7), so the value is 0.
- `HAVING count(*) = 0` returns no rows. `count(*)` is 1 in each of the six groups:
  one row from the join in groups 1, 2, 3 and one added row in groups 4, 5, 6. A
  group made by `GROUP BY` holds at least one row, so `count(*)` is never 0.
- This is the aggregate form of `LEFT OUTER JOIN` + `IS NULL` from topic 4
  (rules_04, section 10), with the same condition: the counted column must not be
  NULL in a real row.
---
 
## 7. Practice
 
- Fifteen tasks so far. Two queries written by the student, tasks 4 and 5, both
  correct on the first send.
- Predictions checked from the other side: tasks 2, 3, 4, 5, 6, 8, 9, 10, 11,
  12, 14, 15.
- Not done: PGExercises, sections Joins and Aggregates.
---
 
## 8. Open questions
 
1. **Five migrations with transposed dates** (1.2). End of this topic.
2. **`schema-design.md`, four drifts** (1.4). End of this topic.
3. **No migration history in the remote project** (1.3). Decide how the remote is
   updated from now on, before the first `db push`.
4. **Which revision is in force** (1.5). Task in this topic.
5. **Carried from topic 4, unchanged.** `seed.sql` hard-codes surrogate ids; no
   `CHECK` on date consistency in `sites`; delivery line 7 dated before its site's
   `start_date`; no constraint for `from_unit_id <> materials.unit_id` in
   `material_unit_conversions`.
6. **Functional dependence in `GROUP BY`.** Section 7.2.3 allows an ungrouped
   column in the select list when it is functionally dependent on the grouped
   ones, for example when grouping by a primary key. Not tested: tasks 7 and 12
   group by explicit columns.
7. **Plan against catalogue price.** Comparing `estimate_items.unit_price` with
   `supplier_materials.price` needs the unit conversion tables: topic 4 planted a
   line estimated in kg and catalogued in t. Task for a later step.
---
 
## 9. How the tutoring should run (for the next chat)
 
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
- No wording that can be read two ways. "Before" and "after" always name both
  points: "after `ON`, before `WHERE`". "Join" says whether it means the whole
  `LEFT OUTER JOIN` or one pair of rows. No "it" or "this" for a table, a column or
  a step. A question the student calls ambiguous is rewritten, not defended.
- An item asks for what the task text says, nothing added afterwards.
