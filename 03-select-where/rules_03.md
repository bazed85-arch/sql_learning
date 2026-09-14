# Rules — SELECT, WHERE, ORDER BY
 
**Block 1 · Topic 3 — querying a single table**
 
Reference sheet. Read before writing any query.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion, because a conclusion without its mechanism does not transfer
to a new problem.
 
Target: PostgreSQL 17 / Supabase.
 
Status: partial. Covers clause evaluation order, the select list, `DISTINCT`, `WHERE`,
three-valued logic, `IN` / `BETWEEN`, `LIKE` / `ILIKE` and `ORDER BY`. `LIMIT` /
`OFFSET`, `COALESCE`, `NULLIF` and `IS DISTINCT FROM` are added as the topic
progresses — an empty section is honest, an invented rule is not.
 
---
 
## 1. Clause evaluation order
 
**1.1 A query is written in one order and evaluated in another.**
 
```
WITH → FROM → WHERE → GROUP BY + HAVING → select list
     → DISTINCT → UNION/INTERSECT/EXCEPT → ORDER BY → LIMIT/OFFSET
```
 
Source: [SELECT — Description](https://www.postgresql.org/docs/17/sql-select.html),
the numbered list of ten steps at the top of the section. `GROUP BY` and `HAVING` are
one step there, step 4; the tenth step is the locking clause, irrelevant here.
Window function processing is not in that list — it sits between grouping and the
select list, [7.2.5](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-WINDOW).
 
Almost every "why does this not work" in a single-table query follows from this
sequence. It is worth holding as a sequence, not re-deriving each time.
 
**1.2 The select list is evaluated late, so its column labels do not exist in
`WHERE` or `HAVING`.**
 
```sql
SELECT quantity * unit_price AS line_total
FROM   estimate_items
WHERE  line_total > 100;          -- ERROR: 42703 column "line_total" does not exist
```
 
The failure is not "the condition cannot be evaluated". The name does not exist yet:
`WHERE` runs second, the select list much later. The error is a name-resolution
error, not a logic error.
 
Workaround: repeat the expression — `WHERE quantity * unit_price > 100` — or wrap the
query in a subquery / CTE (Topic 6).
 
**1.3 A prohibition follows from the order; permissions are granted case by case.**
 
| Clause | Column label from the select list | Source |
|---|---|---|
| `WHERE` | no | follows from 1.1 |
| `HAVING` | no | follows from 1.1 |
| `GROUP BY` | **yes** | [GROUP BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-GROUPBY) |
| `ORDER BY` | **yes** | [ORDER BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-ORDERBY) |
 
`GROUP BY` and `ORDER BY` accept an output column name or its ordinal number as an
explicit, documented exception to the order — not as something derivable from it.
Confirmed in two places: step 4 of the Description ("although query output columns are
nominally computed in the next step, they can also be referenced in the `GROUP BY`
clause") and the SELECT List section ("an output column's name can be used ... in
`ORDER BY` and `GROUP BY` clauses, but not in the `WHERE` or `HAVING` clauses").
 
**1.4 When a name matches both an output label and an input column, the two clauses
resolve it in opposite directions.**
 
| Clause | Ambiguous name resolves to |
|---|---|
| `GROUP BY` | the **input column** |
| `ORDER BY` | the **output label** |
 
Not a symmetric rule to be guessed at: the documentation states the inconsistency
exists for SQL-standard compatibility.
[GROUP BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-GROUPBY) ·
[ORDER BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-ORDERBY).
 
Practical consequence: a label that shadows a real column name makes a query mean two
different things in two clauses. Do not reuse column names as labels.
*(My assessment, not from the documentation.)*
 
Verified:
 
```sql
SELECT upper(code) AS ucode, count(*) FROM units GROUP BY ucode;          -- works
SELECT upper(code) AS ucode, count(*) FROM units
  GROUP BY upper(code) HAVING ucode LIKE 'K%';   -- ERROR: 42703, HINT: units.code
```
 
---
 
## 2. The select list
 
**2.1 The select list is projection: it decides *columns*, never *rows*.**
 
Row count is set by `FROM` (with its joins) and reduced by `WHERE`, `GROUP BY`,
`DISTINCT` and `LIMIT`. `SELECT id, name FROM materials` on 12 rows returns 12 rows.
 
Single exception, far ahead: set-returning functions in the select list.
 
**2.2 A column label is a name attached to a result column. It is not a column.**
 
`AS line_total` does not create storage, cannot be NULL or "not filled in", and does
not exist anywhere except in the result of that one query. Treating a label as a
column is the same class of error as treating `DEFAULT` as a constraint
(`mistakes.md`, Topic 2, C5): a construct taken for something it is not.
 
**2.3 Write `AS` for column labels. Always.**
 
`AS` is optional ([7.3.2 Column Labels](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-COLUMN-LABELS)),
but omitting it makes a missing comma invisible:
 
```sql
SELECT id, name material_name FROM materials;   -- two columns, not three, no error
```
 
Two places in the documentation state the rule at different strengths, and the
difference matters:
 
- [7.3.2 Column Labels](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-COLUMN-LABELS):
  **Appendix C shows which key words require `AS`** — so only some do, `FROM` being
  the example given.
- [SELECT → Compatibility → Omitting the `AS` Key Word](https://www.postgresql.org/docs/17/sql-select.html):
  `AS` is required if the label matches **any** keyword at all, reserved or not.
Behaviour in PostgreSQL 17 matches 7.3.2, not the Compatibility paragraph. Verified:
 
```sql
SELECT code unique, name collate FROM units;  -- works: both are reserved keywords
SELECT name from FROM units;                  -- ERROR: 42601 syntax error at "from"
SELECT name AS from FROM units;               -- works, result column named "from"
```
 
So a bare label takes most keywords and fails on the ones that would make the
statement ambiguous in that position; after `AS`, everything is accepted. Both
sections recommend the same thing anyway — write `AS` or double-quote — and the reason
given is future keyword additions, which no experiment today can rule out.
 
Key word table, with the column showing which ones need `AS`:
[Appendix C. SQL Key Words](https://www.postgresql.org/docs/17/sql-keywords-appendix.html).
 
**2.4 Labels fold to lower case unless double-quoted**, exactly like table and column
names ([4.1.1 Identifiers and Key Words](https://www.postgresql.org/docs/17/sql-syntax-lexical.html)).
`AS unitName` produces `unitname`. Quoting preserves the case but then the quotes are
needed everywhere the label is referenced.
 
---
 
## 3. DISTINCT
 
**3.1 `DISTINCT` compares the whole result row, not individual columns.**
 
A duplicate is a row matching another row in **every** column of the select list.
`(NULL, true)` and `(NULL, false)` are two distinct rows even though the first column
is the same.
 
Consequence: adding a column to `SELECT DISTINCT` can only keep the row count the
same or increase it, never reduce it. Each combination maps onto exactly one value of
the narrower list — a many-to-one mapping.
 
**3.2 Under `DISTINCT`, NULLs are equal to each other. Under `UNIQUE`, they are not.**
 
[7.3.3 DISTINCT](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-DISTINCT):
two rows are distinct if they differ in at least one column, and null values **are
considered equal** in that comparison.
 
```sql
SELECT DISTINCT x FROM (VALUES ('A'::text), ('B'), (null), (null), (null)) v(x);
-- A, B, NULL → 3 rows
```
 
Same column, same data, opposite behaviour in two constructs:
 
| Construct | Comparison used | Three NULLs give |
|---|---|---|
| `UNIQUE` constraint | ordinary equality, `NULL = NULL` → NULL, no conflict | three accepted rows |
| `DISTINCT`, `GROUP BY`, `UNION` | "not distinct" comparison, two NULLs are equal | one result row |
 
The second comparison is the one spelled `IS NOT DISTINCT FROM`. It is already in use
here, before the operator itself is covered.
 
**The rule this replaces:** "NULLs are distinct" is true, but only inside `UNIQUE`.
A rule memorised without its scope fires in the wrong place
(`mistakes.md`, Topic 2, A5 — `CHECK` "sees one row").
 
**3.3 `DISTINCT` costs a sort or a hash.** It is not free filtering: the server has to
compare every row against every other. Applied to a whole table it is a red flag —
usually the query is missing a `WHERE` or the data model is wrong.
*(My assessment, not from the documentation.)*
 
---
 
## 4. The WHERE clause
 
**4.1 A row is kept only when the condition evaluates to `true`.**
 
[WHERE Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-WHERE): a row
satisfies the condition if it returns true. Not "if it is not false" — `true`.
 
With three possible results instead of two, this single sentence produces every NULL
surprise in a query. `false` and `NULL` both mean "not returned", but they are not the
same value and do not behave the same under `NOT`.
 
**4.2 The condition is evaluated per row, in full.**
 
There is no intermediate set. `WHERE` walks every row of the table expression,
computes the whole expression — `NOT` and all — and keeps the row if the result is
`true`. `NOT (...)` is not an operation applied to a previously selected set of rows;
it is part of the expression computed for one row at a time.
 
Getting this backwards turns `WHERE NOT (a AND b)` into "find the rows matching
`a AND b`, then remove them", which predicts zero rows where the real answer can be
most of the table.
 
**4.3 A boolean column is a complete condition.**
 
`WHERE is_active` and `WHERE is_active = true` are equivalent when the column is
`NOT NULL`. The comparison adds nothing: comparing a boolean to a boolean returns the
same boolean. `WHERE NOT is_active` is the negation.
 
**4.4 Column labels are not available here.** See 1.2. Repeat the expression.
 
---
 
## 5. Three-valued logic
 
**5.1 Any comparison involving NULL yields NULL**, not `true` and not `false`.
`NULL = 'x'`, `NULL <> 'x'`, `NULL > 5` — all NULL. The value is unknown, so the
answer to a question about it is unknown.
 
**5.2 Truth tables.** [9.1 Logical Operators](https://www.postgresql.org/docs/17/functions-logical.html)
 
`AND`:
 
| | true | false | NULL |
|---|---|---|---|
| **true** | true | false | NULL |
| **false** | false | false | **false** |
| **NULL** | NULL | **false** | NULL |
 
`OR`:
 
| | true | false | NULL |
|---|---|---|---|
| **true** | true | true | **true** |
| **false** | true | false | NULL |
| **NULL** | **true** | NULL | NULL |
 
`NOT`:
 
| operand | result |
|---|---|
| true | false |
| false | true |
| **NULL** | **NULL** |
 
Short form worth memorising: **`false` absorbs `AND`, `true` absorbs `OR`.** A known
value that settles the outcome on its own settles it even when the other operand is
unknown. In every other combination involving NULL the result is NULL.
 
Verified: `SELECT null AND false` → false, `SELECT null OR true` → true,
`SELECT null AND true` → NULL, `SELECT not null` → NULL.
 
**5.3 `NOT` does not turn "unknown" into "known".**
 
`WHERE NOT (condition)` does not return "all the other rows". It returns the rows for
which the condition is **definitely false**. Rows where the condition is unknown
appear in neither `WHERE condition` nor `WHERE NOT (condition)`.
 
Consequence, the one that costs real query results: **negation is not complement while
a nullable column is involved.** On 12 materials, 3 with `category = 'cement'` and 2
with `category IS NULL`:
 
```sql
SELECT count(*) FROM materials WHERE category = 'cement';        -- 3
SELECT count(*) FROM materials WHERE category <> 'cement';       -- 7, not 9
SELECT count(*) FROM materials WHERE NOT (category = 'cement');  -- 7
```
 
3 + 7 = 10, not 12. The two unknown rows are in neither result.
 
To include them, say so explicitly:
 
```sql
WHERE category <> 'cement' OR category IS NULL;                  -- 9
```
 
**5.4 `IS NULL` and `IS NOT NULL` always return `true` or `false`, never NULL.**
That is what makes them usable in `WHERE`, and why no amount of `=`, `<>` or `NOT`
can replace them. [9.2 Comparison Functions and Operators](https://www.postgresql.org/docs/17/functions-comparison.html)
 
**5.5 Ask whether the column is nullable before writing the condition, not after
getting a strange number.** The answer is in the schema. For `materials`: `name`,
`unit_id`, `is_active` are `NOT NULL`; `article_no`, `description`, `category` are
nullable.
 
Where every column in the condition is `NOT NULL`, two-valued intuition is safe and
`NOT` behaves like the word "not" — `WHERE is_active` and `WHERE NOT is_active` split
12 rows into 11 and 1 with nothing lost. That safety is created by the constraints
written in Topic 2, not by the query.
 
**5.6 Procedure, until this is automatic.** For any condition touching a nullable
column, do not compute in your head — write the groups out:
 
1. list the row groups by the columns appearing in the condition;
2. for each group evaluate each operand separately: `true`, `false` or `NULL`;
3. combine with the truth table above;
4. only groups yielding `true` are returned;
5. sum the counts.
**5.7 Operator precedence: `NOT` binds tighter than `AND`, `AND` tighter than `OR`.**
[4.1.6 Operator Precedence](https://www.postgresql.org/docs/17/sql-syntax-lexical.html#SQL-PRECEDENCE)
 
```sql
WHERE category = 'cement' OR category = 'rebar' AND is_active = true
-- parsed as:
WHERE category = 'cement' OR (category = 'rebar' AND is_active = true)   -- 5 rows
-- probably meant:
WHERE (category = 'cement' OR category = 'rebar') AND is_active = true   -- 4 rows
```
 
Write the parentheses even where precedence already gives the intended reading. The
cost is two characters; the failure mode is a query that returns plausible wrong
numbers and no error. *(My assessment, not from the documentation.)*
 
**5.8 `NOT (a AND b)` is hard to read and gets harder with nullable columns.**
Prefer stating what should remain. *(My assessment.)*
 
---
 
## 6. IN, NOT IN, BETWEEN
 
**6.1 Both are shorthand for things already known.**
[9.24.2 IN / NOT IN](https://www.postgresql.org/docs/17/functions-comparisons.html),
[9.2 Comparison Operators](https://www.postgresql.org/docs/17/functions-comparison.html)
 
```sql
x IN (a, b)        →  x = a OR x = b
x NOT IN (a, b)    →  x <> a AND x <> b
x BETWEEN a AND b  →  x >= a AND x <= b
```
 
Their NULL behaviour is not new semantics — it follows from the truth tables in
section 5. Expand the shorthand, then apply the table.
 
**6.2 `NOT IN` with a NULL anywhere in the list returns zero rows. Always.**
 
`x <> NULL` is NULL for every row, and `AND` with NULL never yields `true` — it
yields `false` or NULL. No row is ever kept, whatever the data.
 
```sql
SELECT count(*) FROM materials WHERE category NOT IN ('cement', NULL);   -- 0
```
 
No error, no warning, no rows. The failure reads as "there is no such data", so it
sends you to check the table rather than the query. In real work the NULL arrives
through a subquery — `WHERE id NOT IN (SELECT some_nullable_column FROM ...)` — where
nobody typed it.
 
**`IN` does not have this problem**: `category IN ('cement', NULL)` returns the three
cements, because `true` absorbs `OR`. The asymmetry is exactly the asymmetry of the
two truth tables.
 
Rule: if NULL is possible in the list, do not use `NOT IN`. Use `NOT EXISTS`
(Topic 6), or filter NULLs out of the list.
 
**6.3 Two different failures, do not confuse them.**
 
| Where the NULL is | Effect | Fix |
|---|---|---|
| in the **list** | zero rows, always | do not use `NOT IN` |
| in the **column**, list clean | the rows where the column is NULL drop out | add `OR col IS NULL` if those rows are wanted |
 
```sql
-- 12 materials, 2 with article_no NULL, 2 matching the list
SELECT count(*) FROM materials
WHERE article_no NOT IN ('CEM-II-425', 'REBAR-12');       -- 8, not 10 and not 0
```
 
**6.4 `BETWEEN` includes both bounds, and the order of bounds matters.**
`BETWEEN 23 AND 17` is `>= 23 AND <= 17` — impossible, zero rows. It does not sort the
bounds.
 
**6.5 `NOT BETWEEN` flips both comparisons and the connective.**
 
```sql
x NOT BETWEEN a AND b  →  NOT (x >= a AND x <= b)  →  x < a OR x > b
```
 
Strict, not inclusive: the bounds belong to `BETWEEN` and are therefore excluded from
`NOT BETWEEN`. On a `NOT NULL` column the two are exact complements — 6 rows in the
range, 6 outside, 12 in the table. That is a free check on the answer.
 
---
 
## 7. LIKE and ILIKE
 
[9.7.1 LIKE](https://www.postgresql.org/docs/17/functions-matching.html)
 
**7.1 `%` matches any number of characters, including none. `_` matches exactly one.**
Everything else is literal.
 
`code LIKE 'm_'` matches `m2` and `m3` but not `m` — `_` demands a character.
`code LIKE 'm%'` matches all three.
 
**7.2 The pattern must cover the whole string.** `name LIKE 'Cement'` is an equality
test. "Starts with" needs a trailing `%`.
 
**7.3 `ILIKE` is case-insensitive `LIKE`.** A PostgreSQL extension, not in the SQL
standard; the portable form is `lower(col) LIKE lower(pattern)`.
 
```sql
name LIKE  '%plasterboard%'   -- 1 row  (PHONIQUE plasterboard)
name ILIKE '%plasterboard%'   -- 2 rows (adds Plasterboard standard)
```
 
**7.4 NULL behaves as everywhere else.** `NULL LIKE anything` is NULL, so a row with a
NULL column passes neither `LIKE` nor `NOT LIKE`.
 
**7.5 To match `%` or `_` literally, escape them.** The default escape character is
backslash; `ESCAPE` names a different one.
 
```sql
description LIKE '%\%%'              -- contains a percent sign
description LIKE '%!%%' ESCAPE '!'   -- same thing, clearer
```
 
**The escape character cannot also be a wildcard.** `LIKE '%%%' ESCAPE '%'` does not
work: declaring `%` as the escape character strips it of its wildcard role, leaving a
pattern that matches a single literal `%` and ends in a dangling escape. Pick a
character that appears in neither the pattern nor the data.
 
---
 
## 8. ORDER BY
 
[ORDER BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-ORDERBY) ·
[7.5 Sorting Rows](https://www.postgresql.org/docs/17/queries-order.html)
 
**8.1 Sort by an output label, an ordinal number, or any expression** — including a
column absent from the select list. `SELECT name FROM sites ORDER BY start_date` is
valid.
 
**8.2 Options are per expression, not per clause.** This holds for `ASC`/`DESC` and
for `NULLS FIRST`/`NULLS LAST` alike.
 
```sql
ORDER BY a, b DESC              -- a ascending, b descending
ORDER BY category, name NULLS LAST   -- NULLS LAST applies to name, not category
ORDER BY category NULLS LAST, name   -- what was probably meant
```
 
**8.3 Default null placement: `NULLS LAST` with `ASC`, `NULLS FIRST` with `DESC`** —
the default behaves as though NULL were larger than every value.
 
This is a *sorting convention*, not a property of NULL. Nothing is larger or smaller
than NULL; comparison with it yields NULL. The sort has to put the row somewhere and
this is the choice PostgreSQL made.
 
**8.4 `NULLS FIRST/LAST` and `ASC/DESC` are independent.** Using `DESC` to move NULLs
to the top also reverses the values — two changes where one was wanted. State both
explicitly whenever null placement matters to the result:
 
```sql
ORDER BY actual_end_date NULLS FIRST        -- unfinished sites first, dates ascending
ORDER BY start_date DESC NULLS LAST         -- newest first, not-yet-started last
```
 
**8.5 Rows equal on every sort expression come back in an implementation-dependent
order.** Add a tie-breaking key — a unique column — whenever the order has to be
stable:
 
```sql
ORDER BY payment_terms_days, name
```
 
Two suppliers on 30-day terms are otherwise ordered arbitrarily, and the arbitrary
choice can change between runs.
 
**8.6 Sorting by an expression sets the grouping you want.**
`ORDER BY is_active = false, name` puts active rows first, because the expression is
`false` for them and `false` sorts before `true`. `ORDER BY is_active DESC, name` does
the same thing more briefly. Either is fine; what has to be known is that **`false`
sorts before `true`**.
 
**8.7 Text sorts character by character** under the column's collation, and a space
sorts before a letter — `Cement CEM I 52,5R` precedes `Cement CEM II/B-L 42,5N`.
 
---
 
## 9. String length
 
`length(text)` and `char_length(text)` are the same function for `text` —
`char_length` is the SQL-standard spelling.
[9.4 String Functions](https://www.postgresql.org/docs/17/functions-string.html).
 
`length(trim(col)) > 0` in the Topic 2 `CHECK` constraints is the same `length`.
 
---
 
## Checklist before running a query
 
- [ ] Every identifier read back character by character against the schema
- [ ] The column in the condition is the one the question is about
- [ ] Condition read aloud as words — "and" or "or", "is" or "is not"
- [ ] Every nullable column in the condition accounted for: are unknown rows meant to
      be in the result or not?
- [ ] `NOT (...)` checked for the rows it silently drops
- [ ] Parentheses written around every `OR` inside an `AND`
- [ ] Row count predicted from the data before running, not after seeing the result
- [ ] Actual count compared against the prediction, and a mismatch investigated rather
      than accepted
- [ ] Answer checked a second way — the complement counted, or the total reconciled
- [ ] `NOT IN`: can anything in the list be NULL? If yes, rewrite it
- [ ] `BETWEEN`: low bound written first
- [ ] `ORDER BY`: every option attached to the expression it belongs to
- [ ] `ORDER BY`: a tie-breaking key added wherever the sort key is not unique
- [ ] Answer verified from the other side — the complement, or the total minus the
      excluded rows
- [ ] `NOT IN`: is a NULL possible in the list? If yes, the query returns nothing
- [ ] `ORDER BY`: is `NULLS FIRST/LAST` attached to the expression it belongs to?
- [ ] `ORDER BY`: can two rows be equal on every key? If yes, add a tie-breaker
