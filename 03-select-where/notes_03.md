# Notes — Block 1 · Topic 3
 
Working notes for SELECT, WHERE, ORDER BY and NULL handling.
Queries written while learning, experiment results, open questions.
Rules extracted from these findings live in `rules.md`; errors in `mistakes.md`.
 
Database: Supabase project `construction-supply`, eu-central-1, PostgreSQL 17.6.1.
 
---
 
## Starting state of the database
 
Checked against the database itself at the start of the topic, not against the
repository. Result, before any change:
 
| Table | Rows |
|---|---|
| `units` | 3 |
| `materials` | 2 |
| the other nine | 0 |
 
The repository was not lying: `seed.sql` contained exactly those five rows, and nine
tables had no seed blocks at all. What was wrong was my own description of the state
at the start of Topic 3 — "schema implemented and filled with test data". Five rows
across two tables is not test data for querying. The Topic 2 summary itself does not
claim otherwise; it says the schema reproduces, which it does.
 
**Finding worth keeping:** "the schema reproduces from the repository" and "the
database contains data to work with" are two different claims. The first was verified
in Topic 2. The second was never checked and was carried forward as if it had been.
 
---
 
## Seed extended — units and materials
 
`seed.sql` — the `units` and `materials` blocks replaced. State after the rebuild
(drop → seven migrations → seed), verified by query:
 
| Check | Value |
|---|---|
| `units` | 8 |
| `materials` | 12 |
| `units` with `sort_order IS NULL` | 1 |
| `materials` with `article_no IS NULL` | 2 |
| `materials` with `category IS NULL` | 2 |
| `materials` with `is_active = false` | 1 |
| `units.id` range | 1–8, in insertion order |
 
Category distribution, needed for every row-count prediction in this topic:
 
| `category` | `is_active` | Rows |
|---|---|---|
| `cement` | true | 2 |
| `cement` | false | 1 |
| `drywall` | true | 2 |
| `rebar` | true | 2 |
| `aggregate` | true | 2 |
| `insulation` | true | 1 |
| `NULL` | true | 2 |
 
Five distinct non-null categories, six distinct values counting NULL as one.
 
### What is in the data on purpose
 
Test data for a querying topic has to contain the cases the topic is about, or the
constructs are unobservable:
 
| Planted | Makes observable |
|---|---|
| `sort_order IS NULL` on `l` | `ORDER BY ... NULLS FIRST/LAST` — the only nullable sortable column in the database |
| two `article_no IS NULL` | `IS NULL`, `COALESCE`, `NOT IN` with NULL |
| two `category IS NULL` | `DISTINCT` collapsing NULLs into one row |
| one `is_active = false` | a boolean column as a whole condition |
| `PHONIQUE` upper case next to `Plasterboard` | `LIKE` vs `ILIKE` on real rows |
| two near-identical cement names | `LIKE '%42,5N%'` matching more than intended |
 
No empty strings anywhere: the Topic 2 `CHECK (length(trim(col)) > 0)` constraints
block them, which is the correct behaviour. `''` is examined through expressions in
queries instead of through junk in the tables.
 
---
 
## Experiment 1 — DISTINCT and NULL
 
```sql
SELECT DISTINCT x FROM (VALUES ('A'::text), ('B'), (null), (null), (null)) v(x);
```
 
Three rows: `A`, `B`, `NULL`. Three NULLs collapse into one.
 
The same three NULLs under a `UNIQUE` constraint would all be accepted as separate
rows — verified in Topic 2, experiment 2. Two constructs, two comparison rules, one
data set. Written up as `rules.md` 3.2.
 
**Prediction before running: 8 rows on the 8-supplier version of the question.
Actual: 6.** The failure is logged as B1.
 
---
 
## Experiment 2 — labels and reserved words
 
```sql
SELECT name from FROM units;                  -- ERROR: 42601 syntax error at "from"
SELECT name AS from FROM units;               -- works, result column named "from"
SELECT code unique, name collate FROM units;  -- works — and both are reserved words
```
 
Predicted correctly before running for the first two. The third was run afterwards to
check the explanation behind them, and it turned up a discrepancy **inside the
documentation**:
 
| Section | Says |
|---|---|
| 7.3.2 Column Labels | Appendix C shows *which* key words require `AS` — only some do |
| SELECT → Compatibility | `AS` is required if the label matches *any* key word |
 
PostgreSQL 17 behaves as 7.3.2 describes: `unique` and `collate` pass as bare labels,
`from` does not. Both sections recommend writing `AS` regardless, for protection
against future key word additions.
 
Two lessons, the second more useful:
 
1. when two sections of the documentation disagree, the specific one (a table in an
   appendix) beats the general prose, and the experiment settles which is which;
2. a correct conclusion can rest on a wrong model of the grammar — worth running the
   extra case even when the first results match the prediction.
---
 
## Experiment 3 — where a label is visible
 
```sql
SELECT quantity * unit_price AS line_total FROM estimate_items
  WHERE line_total > 100;
-- ERROR: 42703 column "line_total" does not exist
 
SELECT upper(code) AS ucode, count(*) FROM units GROUP BY ucode;
-- works
 
SELECT upper(code) AS ucode, count(*) FROM units
  GROUP BY upper(code) HAVING ucode LIKE 'K%';
-- ERROR: 42703, HINT: Perhaps you meant to reference the column "units.code".
```
 
```sql
SELECT char_length(name) AS name_length FROM materials ORDER BY name_length DESC;
-- works
```
 
`WHERE` and `HAVING` reject the label, `GROUP BY` and `ORDER BY` accept it. The
rejection follows from the evaluation order; the acceptance is a documented exception
in each of the two clauses. The error text is a name-resolution error — the useful
signal that the label does not exist rather than that the condition is wrong.
 
**Asymmetry found while checking the documentation, not by experiment.** If a name
matches both an output label and an input column, `GROUP BY` reads it as the input
column and `ORDER BY` as the output label — opposite resolutions, stated in the docs as
an inconsistency kept for SQL-standard compatibility. Written up as `rules.md` 1.4. No
data in this database can show it yet; a query where it matters needs a label
deliberately shadowing a column name.
 
---
 
## Practice — projection, aliases, DISTINCT
 
Row counts predicted before running, verified after. 4 of 4 predictions correct.
 
```sql
-- 1. unit code and full name, result columns renamed. Predicted 8, actual 8.
SELECT code AS unit_code, name AS unit_name FROM units;
 
-- 2. categories present in the catalogue, no repeats. Predicted 6, actual 6.
--    Five real categories plus one row for the two NULLs.
SELECT DISTINCT category FROM materials;
 
-- 3. distinct combinations of category and active flag. Predicted 7, actual 7.
--    Six from the distinct categories at is_active = true, plus (cement, false).
SELECT DISTINCT category, is_active FROM materials;
 
-- 4. material name and its length in characters. Predicted 12, actual 12.
--    DISTINCT would be wrong here: projection does not change the row count.
SELECT name, char_length(name) AS name_length FROM materials;
```
 
---
 
## Experiment 4 — NOT and NULL
 
```sql
SELECT null AND false, null OR true, null AND true, not null;
-- false, true, NULL, NULL
```
 
`false` settles an `AND` and `true` settles an `OR` even when the other operand is
unknown. Everything else involving NULL comes back NULL — including `NOT NULL`, which
is the row that costs query results.
 
Consequences measured on the 12 materials (3 cement, 2 with no category):
 
```sql
SELECT count(*) FROM materials WHERE category = 'cement';         -- 3
SELECT count(*) FROM materials WHERE category <> 'cement';        -- 7
SELECT count(*) FROM materials WHERE NOT (category = 'cement');   -- 7
SELECT count(*) FROM materials WHERE category <> 'cement'
                                  OR category IS NULL;            -- 9
```
 
3 + 7 = 10 of 12. Negation is not complement here, and `NOT` does not recover the
missing rows — only `IS NULL` does. Written up as `rules.md` 5.3.
 
The contrast case, on a `NOT NULL` column:
 
```sql
SELECT count(*) FROM materials WHERE is_active;        -- 11
SELECT count(*) FROM materials WHERE NOT is_active;    -- 1
```
 
11 + 1 = 12, nothing lost. Two-valued intuition is safe there, and it is safe because
of a Topic 2 constraint, not because of anything in the query.
 
---
 
## Practice — WHERE, comparisons, AND/OR/NOT
 
```sql
-- 1. name and article of active materials sold in bags. Predicted 2, actual 2.
--    Query as first written had a typo: arcticle_no. See mistakes.md E1.
SELECT name AS material_name, article_no AS article
FROM   materials
WHERE  unit_id = 2 AND is_active = true;
 
-- 2. active materials in the cement and rebar categories. Predicted 4, actual 4.
--    Without the parentheses: 5 — AND binds tighter, so the inactive cement
--    joins the result through the left side of the OR.
SELECT name FROM materials
WHERE (category = 'cement' OR category = 'rebar') AND is_active = true;
 
-- 3. materials whose name is longer than 25 characters. Predicted 3, actual 4.
--    Missed XPS insulation board 50 mm (26). See mistakes.md F2.
SELECT name, char_length(name) AS name_length
FROM   materials
WHERE  char_length(name) > 25;
 
-- 4. every material except cement, including those with no category. Expected 9.
--    First attempt returned 0: wrong column and AND instead of OR. mistakes.md E4.
SELECT name FROM materials
WHERE  category <> 'cement' OR category IS NULL;
```
 
---
 
## Practice — ten row-count predictions
 
Written before running, all ten checked against the database afterwards. 9 correct.
 
| # | Condition | Predicted | Actual |
|---|---|---|---|
| 1 | `category IS NULL` | 2 | 2 |
| 2 | `category IS NOT NULL AND is_active` | 9 | 9 |
| 3 | `NOT (category = 'drywall')` | 8 | 8 |
| 4 | `article_no IS NULL OR is_active = false` | 3 | 3 |
| 5 | `unit_id <> 1 AND char_length(name) > 20` | 3 | 3 |
| 6 | `NOT (article_no IS NULL)` | 10 | 10 |
| 7 | `category = 'cement' AND NOT is_active` | 1 | 1 |
| 8 | `unit_id = 4 OR unit_id = 7` | 4 | 4 |
| 9 | `category <> 'aggregate' AND article_no IS NOT NULL` | **1** | **7** |
| 10 | `NOT (category = 'rebar' OR category = 'cement')` | 5 | 5 |
 
Number 3 is the one to notice: 8 rather than 10, because `NOT NULL` is NULL and the
two uncategorised rows drop out. Same in 10: twelve minus two rebars, three cements
and two unknowns.
 
Number 9 is a misreading, not a logic failure — 1 is the correct answer for the same
condition with `IS NULL`. See `mistakes.md` E3.
 
---
 
## Seed extended — suppliers and sites
 
Added because `materials` carries only text, numbers and a boolean: dates and money
had nowhere to come from, so `ORDER BY` on dates and `BETWEEN` on ranges were
untestable. Structure read from `information_schema` and `pg_constraint` before
writing a single row, not from memory of the Topic 2 migration.
 
Constraints the data had to satisfy:
 
- `sites.status` — `CHECK (status IN ('planned','active','suspended','completed'))`
- `sites.code`, `suppliers.tax_id` — `UNIQUE`, the second one nullable
- `suppliers.payment_terms_days` — `CHECK (>= 0)`
- `name` in both — `CHECK (length(trim(name)) > 0)`
State after the run, verified by query: 8 suppliers, 6 sites.
 
| Planted | Makes observable |
|---|---|
| `tax_id IS NULL` ×2, under `UNIQUE` | the Topic 2 experiment, now as data rather than a test |
| `payment_terms_days IS NULL` ×2, and `0` ×1 | "no terms agreed" against "pays on delivery" — NULL against zero |
| terms 0, 15, 30, 30, 45, 60 | `BETWEEN` on numbers; the duplicated 30 forces a tie-breaker in `ORDER BY` |
| `actual_end_date IS NULL` ×4 | the main material for `NULLS FIRST/LAST` |
| `start_date IS NULL` ×1, `planned_end_date IS NULL` ×1 | a NULL landing mid-range when sorted, and a second nullable date in one table |
| all four `status` values | `IN`, `NOT IN` |
| TF-002 finished late, TF-006 early | comparison of two columns in one row — what `CHECK` can do and Topic 2 assumed it could not |
 
Inserted without a rebuild: both tables were empty, so the two blocks were appended to
`seed.sql` and run as they were. A `DROP` would have been ceremony.
 
---
 
## Experiment 5 — IN and NOT IN against NULL
 
```sql
SELECT count(*) FROM materials WHERE category IN ('cement', 'rebar');        -- 5
SELECT count(*) FROM materials WHERE category NOT IN ('cement', 'rebar');    -- 5
SELECT count(*) FROM materials WHERE category NOT IN ('cement', NULL);       -- 0
SELECT count(*) FROM materials WHERE article_no IN ('CEM-II-425','REBAR-12', NULL);  -- 2
SELECT count(*) FROM materials
  WHERE article_no NOT IN ('CEM-II-425','REBAR-12');                         -- 8
```
 
Line 3 is the one to remember: zero rows for any data, because `x <> NULL` is NULL in
every row and `AND` never reaches `true`. Line 4 shows why `IN` escapes the same fate —
`true` absorbs `OR`, so the NULL operand is irrelevant for rows that match.
 
Line 5 is a third case, distinct from both: the list is clean, the NULLs sit in the
column, and only those two rows drop out. 12 − 2 matched − 2 unknown = 8.
 
Checked against the schema afterwards: every foreign key column in this database is
`NOT NULL`, so a `NOT IN` over a subquery of foreign keys cannot hit the trap here.
That is a Topic 2 decision paying off in Topic 3 — the columns where a NULL would
silently empty a result set were closed before any query existed. The exposure is in
non-key nullable columns — `article_no`, `category`, `tax_id` — and in lists built
outside the database.
 
---
 
## Experiment 6 — LIKE, ILIKE and ESCAPE
 
```sql
name LIKE  'Cement%'                      -- 3
name LIKE  '%plasterboard%'               -- 1
name ILIKE '%plasterboard%'               -- 2   adds Plasterboard standard
article_no LIKE 'CEM%'                    -- 3   the two NULL article_no rows drop
code LIKE 'm_'                            -- 2   m2, m3 — not m
```
 
`_` demands exactly one character, which is what separates it from `%`: `'m%'` would
have returned all three unit codes.
 
Escaping a literal percent sign:
 
```sql
'Discount 10% for orders' LIKE '%\%%'             -- true   default escape
'Discount 10% for orders' LIKE '%!%%' ESCAPE '!'  -- true
'Discount 10% for orders' LIKE '%%%' ESCAPE '%'   -- false  does not work
'Bag 25 kg, palletised 1400 kg' LIKE '%\%%'       -- false
```
 
The failing line is the instructive one: naming `%` as the escape character strips it
of its wildcard role, leaving "one literal percent" plus a dangling escape. An escape
character cannot also be a wildcard.
 
---
 
## Experiment 7 — ORDER BY and nulls
 
```sql
SELECT code, start_date FROM sites ORDER BY start_date;
-- TF-006 → TF-002 → TF-001 → TF-004 → TF-003 → TF-005(NULL)
 
SELECT code, start_date FROM sites ORDER BY start_date DESC;
-- TF-005(NULL) → TF-003 → TF-004 → TF-001 → TF-002 → TF-006
```
 
Defaults confirmed: `NULLS LAST` under `ASC`, `NULLS FIRST` under `DESC` — as though
NULL were larger than everything. A convention of the sort, not a property of NULL.
 
```sql
ORDER BY planned_end_date ASC NULLS FIRST
-- TF-004(NULL) → TF-006 → TF-002 → TF-001 → TF-003 → TF-005
 
ORDER BY is_active = false, name
-- 11 active rows, then the inactive one
```
 
The second is worth keeping: sorting by a computed boolean sets the grouping, because
`false` sorts before `true`. `ORDER BY is_active DESC, name` is the shorter equivalent.
 
Also observed: `Cement CEM I 52,5R` precedes `Cement CEM II/B-L 42,5N` — text compares
character by character, and a space sorts before a letter.
 
---
 
## Practice — ORDER BY
 
```sql
-- suppliers by payment terms ascending, unagreed terms last
SELECT name, payment_terms_days FROM suppliers
ORDER BY payment_terms_days NULLS LAST;
 
-- unagreed terms first, the rest descending
-- first written as plain DESC, which relies on the default; this states it
SELECT name, payment_terms_days FROM suppliers
ORDER BY payment_terms_days DESC NULLS FIRST;
 
-- sites newest first, the not-yet-started one at the bottom
SELECT code, start_date FROM sites
ORDER BY start_date DESC NULLS LAST;
 
-- materials by category then name, uncategorised last
-- first written as "ORDER BY category, name NULLS LAST" — right output, wrong query:
-- the option attaches to name, which is NOT NULL. See mistakes.md G2.
SELECT category, name FROM materials
ORDER BY category NULLS LAST, name;
 
-- deterministic order where two suppliers share 30-day terms
SELECT name, payment_terms_days FROM suppliers
ORDER BY payment_terms_days, name;
 
-- sites in order of completion date, unfinished first
SELECT code, actual_end_date FROM sites
ORDER BY actual_end_date NULLS FIRST;
```
 
## Repository changes
 
- `seed.sql` — `units` extended to eight rows, `materials` to twelve. Comments kept
  in the existing style: each block states what the data is for.
- `seed.sql` — `suppliers` and `sites` blocks appended, 8 and 6 rows, with the
  nullable columns deliberately populated. Both tables were empty, so the blocks were
  run as written; no rebuild needed.
- `README.md` — the `## Notes` section described "solutions with the task description
  as a comment", which no topic folder actually contains. Replaced with a description
  of the three files that do exist. Same class of drift as the seed: the repository
  described something that was not there.
---
 
## Open questions
 
1. **`seed.sql` still hardcodes `unit_id`.** Open question 2 of Topic 2, unchanged.
   The values are correct only because the rebuild procedure starts from an empty
   database and the identity sequences begin at 1. A scalar subquery
   `(SELECT id FROM units WHERE code = 'bag')` fixes it. Subqueries are Topic 6
   (`06-subqueries-cte/`), which is what the Topic 2 note meant by "revisit after
   Topic 5"; this stays open until then and is not worked around in the meantime.
2. **`seed.sql` is not re-runnable on its own.** It assumes a clean database, so the
   second run fails on `UNIQUE (code)`. Acceptable because the rebuild procedure
   established in Topic 2 — drop, migrations, seed — always starts clean. Revisit only
   if that procedure becomes inconvenient.
3. **`sites` has no `CHECK` on date consistency.** Nothing stops
   `actual_end_date` from preceding `start_date`, or a planned end before a start.
   The seeded rows are consistent, but the constraint is missing. It would also be a
   worked example of a `CHECK` comparing two columns of one row — the thing Topic 2
   wrongly assumed `CHECK` could not do (`mistakes_02.md` A5). Worth adding as a
   migration once the query topics are done.
4. **Seven tables still have no seed data.** `supplier_materials`, `estimates`,
   `estimate_items`, `deliveries`, `delivery_items`, `unit_conversions`,
   `material_unit_conversions`. `units`, `materials`, `suppliers` and `sites` are
   seeded, which covers text, booleans, numbers and dates; the remaining seven carry
   the money columns and the line-item structure needed from Topic 4 onwards. Blocked
   on nothing — just not written yet.
---
 
## Side facts collected
 
- `DELETE` does not reset an identity sequence. After deleting the three original
  units, the next insert would have received `id = 4`, not `1`.
  [5.3 Identity Columns](https://www.postgresql.org/docs/17/ddl-identity-columns.html)
- The Supabase SQL Editor shows the result of the **last** statement in the window.
  Two `SELECT count(*)` statements run together show only the second one.
- `length(text)` and `char_length(text)` are the same function; `char_length` is the
  SQL-standard spelling.
  [9.4 String Functions](https://www.postgresql.org/docs/17/functions-string.html)
- The `UNIQUE` constraint on `materials.article_no` is named
  `materials_article_no_uq` — named explicitly in the Topic 2 migration, not generated.
  PostgreSQL's own generated form would be `materials_article_no_key`. Read from
  `pg_constraint`:
```sql
  SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
  WHERE conrelid = 'materials'::regclass AND contype IN ('u','p');
```
- `ORDER BY` defaults on nulls: `NULLS LAST` with `ASC`, `NULLS FIRST` with `DESC` —
  i.e. the default treats NULL as larger than any value. From the
  [ORDER BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-ORDERBY)
  section; not yet verified against the `units.sort_order` data.
- Nullability in `materials`, the list to check before writing any condition:
  `NOT NULL` — `id`, `name`, `unit_id`, `is_active`, `created_at`;
  nullable — `article_no`, `description`, `category`.
- The `WHERE` clause keeps a row when the condition returns `true`, stated in exactly
  those words in [WHERE Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-WHERE).
  `false` and NULL both mean "not returned" but are different values and behave
  differently under `NOT` — which is where the whole topic turns.
