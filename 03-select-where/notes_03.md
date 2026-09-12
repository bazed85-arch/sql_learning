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
 
## Seed extended
 
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
 
## Repository changes
 
- `seed.sql` — `units` extended to eight rows, `materials` to twelve. Comments kept
  in the existing style: each block states what the data is for.
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
3. **Nine tables still have no seed data.** `sites`, `suppliers`,
   `supplier_materials`, `estimates`, `estimate_items`, `deliveries`,
   `delivery_items`, `unit_conversions`, `material_unit_conversions`. Dates, numeric
   money columns and nullable dates all live there, so `BETWEEN`, `ORDER BY` on dates
   and most realistic `WHERE` practice needs them. Blocked on nothing — just not
   written yet.
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
