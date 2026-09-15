# Mistakes Log — Block 1 · Topic 3
 
Errors made while learning to query the construction supply schema.
Format: **what I answered or wrote → why it is wrong → the rule → source**.
 
Repeats from earlier topics carry the original code, e.g. "repeat of C5, Topic 2".
 
---
 
## A. Clause evaluation order
 
### A1. `WHERE` placed last in the evaluation order
 
Asked why `SELECT quantity * unit_price AS line_total FROM estimate_items
WHERE line_total > 100` fails while the same query with `ORDER BY line_total` works.
 
**Answered:** it fails because `WHERE` is evaluated last.
 
**Wrong, and inverted.** `WHERE` is evaluated **second**, right after `FROM`, long
before the select list. The query fails because `WHERE` runs too *early*: at that
moment the expression has not been computed and the label does not exist.
 
The conclusion ("it fails") was right, the mechanism was the opposite of the truth —
which means it would not transfer to `GROUP BY`, `HAVING` or `ORDER BY`.
 
**Rule:** `rules.md` 1.1, 1.2.
**Source:** [SELECT — Description](https://www.postgresql.org/docs/17/sql-select.html).
 
Second half of the question — why `ORDER BY` works — was not answered at all.
See F1 below.
 
---
 
### A2. A column label read as a column holding data
 
Same question. **Answered:** "if nothing is filled in in `line_total`, the condition
cannot be satisfied".
 
**Wrong.** There is nothing to fill in. `line_total` is a column label — a name
attached to the result of an expression while the output row is being built. It has no
storage, no rows, no NULLs, and exists only inside that one query's result.
 
**Class:** a construct taken for something it is not. The Topic 2 summary counted
three cases of it (`CHECK` vs NULL, `NOT NULL` vs empty string, `DEFAULT` vs `CHECK`);
this is the fourth — **repeat of C5, Topic 2**.
 
**Rule:** `rules.md` 2.2.
 
---
 
### A3. `GROUP BY` — conclusion right, reasoning proving the opposite
 
Asked whether a select-list label works in `GROUP BY` and in `HAVING`, to be derived
from the evaluation order.
 
**Answered:** "works, because it comes before the select list".
 
**The conclusion is right for `GROUP BY` and the reasoning contradicts it.** If
`GROUP BY` is evaluated before the select list, the label does not exist yet — by
exactly the argument that explains why `WHERE` fails. The reasoning given proves
"does not work"; the answer stated "works".
 
The real situation: `GROUP BY` accepting an output column name is a **documented
exception**, granted explicitly, not derivable from the order. `HAVING` has no such
exception. The second half of the question (`HAVING`) was not answered.
 
**Class:** a check whose result does not affect the conclusion is not a check —
**repeat of recurring pattern 11, Topic 2**, where it appeared three times on
cardinality (A2, A3, A4).
 
**Rule:** `rules.md` 1.3.
**Source:** [GROUP BY Clause](https://www.postgresql.org/docs/17/sql-select.html#SQL-GROUPBY).
 
---
 
## B. NULL semantics
 
### B1. The `UNIQUE` rule about NULLs applied to `DISTINCT`
 
Given `suppliers` with 8 rows, 3 of them with `tax_id IS NULL` and 5 with distinct
values, asked how many rows `SELECT DISTINCT tax_id FROM suppliers` returns.
 
**Answered:** 8 — "NULL is treated as not equal".
 
**Wrong. The answer is 6:** five values plus one row for all three NULLs.
 
The rule quoted is real but belongs to a different construct. `UNIQUE` uses ordinary
equality, where `NULL = NULL` yields NULL and no conflict arises. `DISTINCT`,
`GROUP BY` and `UNION` use the "not distinct" comparison, in which two NULLs **are**
equal.
 
**Class:** a rule memorised without its scope, firing in the wrong place —
**repeat of A5, Topic 2** (the `CHECK` "sees one row" rule applied where it did not
belong). On NULL specifically this is the fourth occurrence across topics: the Topic 2
summary recorded three, all with the same shape — the rule is reproduced after a
reminder, not before it.
 
**Rule:** `rules.md` 3.2.
**Source:** [7.3.3 DISTINCT](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-DISTINCT).
 
### B2. Rows with NULL counted as passing a `<>` comparison
 
`materials`, 12 rows, 3 with `category = 'cement'`, 2 with `category IS NULL`.
Asked how many rows `SELECT name FROM materials WHERE category <> 'cement'` returns.
 
**Answered:** 9 — 12 minus the three cements.
 
**Wrong. 7.** For the two rows with no category the comparison is `NULL <> 'cement'`,
which is NULL, and `WHERE` keeps a row only when the condition is `true`.
 
Worth recording precisely because 9 is the right answer to a different query, which
was run to confirm it: `WHERE category <> 'cement' OR category IS NULL` → 9. The
understanding of the *data* was correct — nine materials are not cement. What was
missing is that the operator does not answer that question.
 
**Rule:** `rules.md` 5.1, 5.3.
 
---
 
### B3. Truth table values swapped
 
Asked for the value of three expressions.
 
| Expression | Answered | Actual |
|---|---|---|
| `null AND false` | false | false ✓ |
| `null OR true` | null | **true** |
| `null AND true` | true | **NULL** |
 
The last two were inverted with respect to each other — not a slip, an absent rule.
The mechanism: a known value that decides the outcome on its own decides it regardless
of the unknown (`false` in `AND`, `true` in `OR`); otherwise the result is unknown.
 
**Rule:** `rules.md` 5.2.
**Source:** [9.1 Logical Operators](https://www.postgresql.org/docs/17/functions-logical.html).
 
---
 
### B4. `NOT (...)` read as inverting a selected set
 
Asked how many rows `WHERE NOT (category = 'cement' AND is_active = true)` returns.
 
**Answered:** 0 — "the `AND` gives 2 rows, `NOT true` is false, so nothing is
returned".
 
**Wrong. 8.** The reasoning treats `WHERE` as two steps: select the rows matching the
inner condition, then discard them. There is no intermediate set. `WHERE` evaluates
the whole expression, `NOT` included, once per row, and keeps the row when the result
is `true`. A drywall row gives `false AND true` → `false` → `NOT false` → `true`, so
it is returned: it is definitely not an active cement, which is what the condition
says.
 
The two rows with `category IS NULL` give `NULL AND true` → NULL → `NOT NULL` → NULL
and are dropped — the same mechanism as B2, fourth occurrence in one session.
 
**Why this one matters most of the four:** the faulty model gives the right answer
whenever there are no NULLs and the condition holds a single comparison, so it
survives a long time before failing. Here it predicted 0 against an actual 8.
 
**Rule:** `rules.md` 4.2.
 
---
 
### B5. Second half of a NULL question left unanswered, wrong number given
 
Asked how many rows `WHERE category <> 'cement' OR is_active = false` returns, with
an explicit instruction to explain what happens to the two rows where
`category IS NULL`.
 
**Answered:** 3, no explanation.
 
**Wrong. 8.** The rows with no category give `NULL OR false` → NULL: `false` decides
nothing in an `OR`, so the unknown stays unknown. Had those rows been inactive, the
condition would have been `NULL OR true` → `true` and they would have been returned —
NULL in one operand does not poison the whole expression, it only stops deciding it.
 
The unanswered half was the part carrying the mechanism. See F1.
 
**Rule:** `rules.md` 5.2.
 
### B6. `NOT IN` with a NULL in the list — expansion written, truth table not applied
 
Asked how many rows `WHERE category NOT IN ('cement', NULL)` returns, with the
instruction to expand it and apply the truth table.
 
**Answered:** 7, with the expansion written correctly as
`category <> 'cement' AND category <> NULL`.
 
**Wrong. Zero — and zero for any data whatsoever.** `category <> NULL` is NULL in
every row, and `AND` with NULL yields `false` or NULL, never `true`. The expansion was
right; it was simply not carried through to the table.
 
**Why this one is the worst trap in the topic:** the result looks like "no matching
data", which sends you to inspect the table instead of the query. And the NULL usually
arrives through a subquery, not by hand.
 
**Rule:** `rules.md` 6.2.
**Source:** [9.24.2 NOT IN](https://www.postgresql.org/docs/17/functions-comparisons.html).
 
---
 
### B7. The previous answer carried over by analogy
 
Asked, immediately after B6, how many rows
`WHERE article_no NOT IN ('CEM-II-425', 'REBAR-12')` returns — clean list, two NULLs
in the column.
 
**Answered:** "0 or 10 — going by the example in question 3, I think 0".
 
**Wrong. 8.** The choice was made by analogy with the case just discussed rather than
by working this one out. Both offered numbers were wrong in opposite directions: 0
treats every row as poisoned, 10 ignores the NULLs entirely. The answer is 12 minus 2
matches minus 2 unknown.
 
A NULL **in the list** kills every row. A NULL **in the column** removes only its own
row. Two different failures with different fixes.
 
**Rule:** `rules.md` 6.3.
 
---
 
### B8. `NOT BETWEEN` treated as keeping the bounds
 
Asked for the row count of `WHERE char_length(name) NOT BETWEEN 17 AND 23`.
 
**Answered:** 10, on the reasoning that 17 and 23 are included, ">= and <=".
 
**Wrong. 6.** Inclusion of the bounds belongs to `BETWEEN`; `NOT BETWEEN` negates the
whole thing, which flips both comparisons and turns the `AND` into an `OR`:
`len < 17 OR len > 23`. The bounds that were inside are therefore outside.
 
`name` is `NOT NULL`, so the two queries are exact complements — and the previous
question in the same block had already established 6 rows inside. 12 − 6 = 6, checkable
in a second without recounting anything.
 
**Rule:** `rules.md` 6.5.
 
## C. DISTINCT mechanics
 
### C1. `DISTINCT` described as de-duplicating each column separately
 
Asked whether `SELECT DISTINCT category, is_active` can return fewer rows than
`SELECT DISTINCT category`.
 
**Answered:** no — "duplicates are discarded per column separately".
 
**Conclusion right, mechanism wrong.** `DISTINCT` never works per column. It compares
the whole row: a duplicate matches in every column of the select list. `(NULL, true)`
and `(NULL, false)` are two rows.
 
Correct reasoning for the same conclusion: every distinct pair maps onto exactly one
`category`, and one `category` can produce several pairs — a many-to-one mapping, so
the number of pairs cannot be smaller.
 
**Rule:** `rules.md` 3.1.
 
---
 
## D. Answer completeness
 
### D1. Error code and constraint name not given
 
Asked: if both article-less materials carried `''` instead of `NULL`, which error and
which constraint. The question asked for the error code and the constraint name.
 
**Answered:** "the rows are not unique".
 
**Incomplete, and imprecise.** Full answer, constraint name read from `pg_constraint`
in the live database:
 
```
ERROR: 23505: duplicate key value violates unique constraint "materials_article_no_uq"
```
 
Three corrections:
 
- not the *rows* are non-unique but the *values in one column* — the rows differ in
  `name` and `unit_id`; a `UNIQUE` on a single column only looks at that column;
- the first `''` violates nothing; the second one does — but since all twelve rows are
  inserted by one `INSERT` command, none of them is inserted;
- the name is `materials_article_no_uq`, not the `table_column_key` form PostgreSQL
  generates on its own — the Topic 2 migration named it explicitly. Worth checking in
  the catalog rather than assuming the generated shape; the generated name would have
  been `materials_article_no_key`.
**Why the question existed:** `NULL` passes twice in that column, `''` would not.
Same column, same constraint, different behaviour — because `''` is a value and
`NULL` is the absence of one.
 
---
 
## E. Execution slips
 
The rule was known and the reasoning was right; what reached the query was something
else. This is the block the Topic 2 scorecard flagged as the only metric that got
worse, and it carried over.
 
### E1. Typo in a column name
 
```sql
SELECT arcticle_no AS article, ...   -- ERROR: 42703 column "arcticle_no" does not exist
```
 
Extra `c`. The condition and the row-count prediction in the same query were both
correct. **Repeat of the two constraint-name typos in Topic 2**, same mechanism: the
identifier was written once and never re-read.
 
### E2. Two correct numbers attached to the wrong queries
 
Asked for the row counts of `WHERE NOT (category = 'cement')` and
`WHERE NOT (is_active = false)`. **Answered:** 11 and 7. **Actual:** 7 and 11.
 
Both numbers were right; the pairing was not. Neither had been checked against the
query — the second one needs no arithmetic at all, since it drops exactly one row out
of twelve. **Repeat of recurring pattern 11, Topic 2.**
 
### E3. `NOT` dropped while reading a predicate
 
Asked to predict the row count of
`WHERE category <> 'aggregate' AND article_no IS NOT NULL`. **Answered:** 1.
**Actual:** 7. One is the right answer for the same query with `IS NULL`.
 
Reading the condition aloud as words — "category is not aggregate AND the article
number **exists**" — exposes it immediately.
 
### E4. Wrong column and wrong operator in one line
 
Task: return every material except cement, including those with no category
(9 rows expected, stated in the task).
 
**Written:**
 
```sql
SELECT name FROM materials WHERE name <> 'cement' AND name IS NULL;   -- 0 rows
```
 
Two separate faults: `name` instead of `category` — there is no material *named*
"cement" — and `AND` instead of `OR`, which demands that the category be both
not-cement and absent at once. The explanation given alongside it, that `WHERE` only
passes `true` and a comparison with NULL yields NULL, was correct. The code did not
follow from it.
 
**Correct for E4:** `WHERE category <> 'cement' OR category IS NULL`.
 
### E5. Correct expansion, wrong count in the same sentence
 
Asked for the row count of `WHERE category NOT IN ('cement', 'rebar')`.
 
**Answered:** "6 rows — the NULL rows give NULL, neither true nor false".
 
**Wrong. 5.** The explanation is exactly right and the arithmetic is not:
12 − 3 cement − 2 rebar − 2 NULL = 5. The mechanism was stated and then not used on
the numbers.
 
### E6. Typo in a table name
 
```sql
SELECT name FROM material WHERE ...   -- ERROR: 42P01 relation "material" does not exist
```
 
The table is `materials`. Second typo of the topic, same mechanism as E1.
 
### E7. Escape character chosen to be the wildcard itself
 
Task: find rows whose description contains a literal `%`.
 
**Written:** `LIKE '%%%' ESCAPE '%'`. **Result:** false on a string that does contain a
percent sign.
 
The construct was the right one to reach for — `ESCAPE` is exactly what the
documentation offers here. But declaring `%` as the escape character strips it of its
wildcard role everywhere in the pattern, leaving "one literal percent, then a dangling
escape", which matches nothing.
 
**Correct:** `LIKE '%\%%'` or `LIKE '%!%%' ESCAPE '!'`. Both verified true on the
percent string and false without it.
 
**Rule:** `rules.md` 7.5.
 
### E8. Typo inside a string literal
 
Writing the `CASE` classification on PGExercises: `THEN 'expansive'` instead of
`'expensive'`.
 
Worse than E1 and E6 because **the database cannot catch it**. A misspelled identifier
raises 42703 or 42P01; a misspelled string literal is simply a different string, and
the query runs and returns wrong labels. Only re-reading, or an automated check like
the one on the exercise site, finds it.
 
### E9. `=` used where the pattern operator was needed
 
```sql
WHERE name = '%Tennis%'   -- zero rows
```
 
`=` compares the whole string literally; `%` is just a character to it. The intended
operator was `LIKE`, covered an hour earlier on this project's own data.
 
**Rule:** `rules.md` 7.1.
 
---
 
## F. Process
 
### F1. Part of what was asked answered, the rest skipped — eight times
 
| Question | Asked | Answered |
|---|---|---|
| A1 | why the first query fails **and** why the second works | why the first fails |
| A3 | label in `GROUP BY` **and** in `HAVING` | `GROUP BY` only |
| B5 | row count **and** what happens to the NULL-category rows | a row count |
| `NOT` question | two row counts **and** why `NOT` misbehaves in one of them | two numbers, "behaves as it should" |
| ten predictions | ten numbers **and** a note on the NULL rows wherever a nullable column appears | ten numbers |
| `ORDER BY` first block | the order of all six codes **and** the position of the NULL row | the position of the NULL row |
 
In the first four and the sixth the unanswered half was the part holding the
mechanism: `ORDER BY`
working is what shows the evaluation order matters; `HAVING` failing is what shows
`GROUP BY` is an exception rather than a consequence; the NULL rows are the whole
point of a NULL question.
 
The fifth is different and worth separating: the numbers were 9 out of 10 correct, so
the mechanism *was* applied — it just did not reach the answer. That is the Topic 2
diagnosis exactly, one level up: the rule is known, the conclusion is right, and what
gets written down is not it.
 
**Repeat of F1, Topic 2** and of E6, Topic 1. Carried across a topic boundary for the
first time. Note on the count: the Topic 2 log heads F1 with "four times" while its
own table lists five occasions, and the Topic 2 summary says five — the heading was
not updated after the fifth. Five is the right number.
 
### F2. Predictions estimated instead of computed
 
Asked for the row count of `WHERE char_length(name) > 25`. **Answered:** 3.
**Actual:** 4 — `XPS insulation board 50 mm` is 26 characters, and the next value
below it is 23, so the missed row sits alone in a gap that eyeballing skips over.
 
The query itself was right. The prediction was formed from an impression of the data
rather than from the data. When a threshold falls near real values, either compute or
say the number cannot be given precisely.
 
Corrected later in the same session: the same style of question inside the ten
predictions was answered correctly.
 
---
 
## G. Sorting
 
### G1. Three faults in one `ORDER BY` query
 
Task: return sites in order of completion date, with unfinished ones first.
 
**Written:**
 
```sql
SELECT sites, planned_end_date ORDER BY planned_end_date DESC;
```
 
- no `FROM` — `sites` would be read as a column name;
- wrong column — "completion date" is `actual_end_date`; `planned_end_date` is filled
  in for unfinished sites too, so it cannot express "unfinished first";
- `DESC` solves half the task by accident: it does put NULLs on top, by default, but
  it also reverses the dates, and the task asked for ascending order.
**Correct:** `SELECT code, actual_end_date FROM sites ORDER BY actual_end_date NULLS FIRST;`
 
**Rule:** `rules.md` 8.4 — placement of NULLs and sort direction are separate
options; using one to achieve the other changes two things where one was wanted.
 
### G2. `NULLS LAST` attached to the wrong expression
 
**Written:** `ORDER BY category, name NULLS LAST` for "by category, then by name,
uncategorised last".
 
The option applies to `name`, which is `NOT NULL` — so it does nothing. The result
matched the task anyway, because `ASC` on `category` defaults to `NULLS LAST`.
 
**Correct:** `ORDER BY category NULLS LAST, name`.
 
Worth logging even though the output was right: the same slip on a column where the
default runs the other way would have produced a wrong order with no error.
 
**Rule:** `rules.md` 8.2.
 
---
 
## H. Requirements dropped from the task
 
### H1. One of two stated conditions implemented
 
PGExercises: facilities that charge a member fee **and** whose fee is less than 1/50 of
the monthly maintenance cost, returning four named columns.
 
**Written:** the 1/50 comparison only, and three columns instead of four. A facility
with `membercost = 0` satisfies `0 < maintenance/50` and would have been returned,
which is what the first condition exists to prevent.
 
Corrected on the second attempt without further prompting.
 
**Class:** the same shape as F1 — part of what was asked is carried out — but here it
lands in the query rather than in the reply, so the result is wrong rather than
incomplete. **Repeat of F1, Topic 2**, where five of five cases were of this kind.
 
---
 
## Recurring patterns to watch
 
1. **`WHERE` keeps a row only when the condition is `true`.** `false` and NULL both
   mean "not returned", and they are not the same thing.
2. **Any comparison with NULL is NULL.** `=`, `<>`, `>`, `LIKE` — all of them. Only
   `IS NULL` and `IS NOT NULL` return a definite answer.
3. **`NOT` does not recover unknown rows.** Negation is not complement while a
   nullable column is in play.
4. **`false` absorbs `AND`, `true` absorbs `OR`.** Everything else with NULL is NULL.
   This one sentence explains why `IN` survives a NULL in the list and `NOT IN` does
   not.
5. **`NOT IN` with a NULL in the list returns nothing, silently.** Check the list
   before using it.
6. **The condition is computed per row, in full.** There is no "select then invert".
7. **Ask whether the column is nullable before writing the condition**, not after the
   number looks odd. The answer is in the schema, not in the query.
8. **A rule memorised without its scope fires in the wrong place.** NULLs are distinct
   under `UNIQUE` and equal under `DISTINCT`; bounds are included by `BETWEEN` and
   excluded by `NOT BETWEEN`.
9. **Do not carry the previous answer over by analogy.** Expand the shorthand and walk
   the rows; the two adjacent cases usually differ in where the NULL sits.
10. **Verify the answer from the other side.** Complement, or total minus excluded.
    Costs seconds and catches the arithmetic slips.
11. **A prohibition follows from the evaluation order; a permission does not.**
    `GROUP BY` and `ORDER BY` accept output labels because the documentation says so.
12. **Options in `ORDER BY` attach to one expression**, never to the whole list.
13. **Read back every identifier and every operator before running.** Six of this
    topic's errors were typos, a swapped pairing, a dropped `NOT`, a wrong column.
14. **Predict from the data, not from an impression of it.**
15. **Finish everything that was asked**, not the numeric part of it. Carried from
    Topic 2 and Topic 1 unchanged.
---
 
## Scorecard — Topic 3
 
| | Count |
|---|---|
| Clause evaluation order | 3 |
| NULL semantics and three-valued logic | 8 |
| DISTINCT mechanics | 1 |
| Answer completeness | 1 |
| Execution slips | 9 |
| Sorting | 2 |
| Requirements dropped | 1 |
| Process | 2 |
| **Total** | **27** |
 
Repeats carried over: C5 (Topic 2) as A2; A5 (Topic 2) as B1 and B8; recurring
pattern 11 (Topic 2) as A3 and E2; constraint-name typos (Topic 2) as E1 and E6;
F1 (Topic 2, ×5) as F1.
 
**Applied correctly without prompting.** Projection and row count; both halves of the
column-label question; `DISTINCT` with NULL on the second pass; four practice queries
with four correct predictions; operator precedence answered for both readings of the
same query — 4 with parentheses and 5 without; the group-by-group procedure filled in
correctly across all seven groups; nine of ten predictions on a set built from every
trap missed earlier.
 
Then, on the second day: all four `LIKE` questions correct including the `_` versus
`%` distinction and the NULL case stated properly for the first time; the `IN` versus
`NOT IN` asymmetry explained rather than memorised; three of three on the `ORDER BY`
reinforcement block, including `ORDER BY is_active = false, name` — sorting by a
computed expression to obtain a grouping the bare column does not give.
 
Then the closing stretch: five of five `LIMIT`/`OFFSET` tasks correct, including the
one where "not finished" had to be read as `actual_end_date IS NULL` rather than as a
list of statuses; `COALESCE` priority order and the `COALESCE(NULLIF(col, ''), ...)`
pair both predicted correctly; and all three `IS DISTINCT FROM` counts right —
including `category <> 'cement'` returning 7, the question that opened the topic with
an answer of 9.
 
On PGExercises, the Basic section finished: eight tasks, three corrections, the rest
right first time.
 
Outside the SQL: spotting that practice queries did not belong in a file; that a
`README` describing files that do not exist is the same drift as a `seed.sql`
describing data that does not exist; and that a `DROP` before inserting into empty
tables was unnecessary ceremony.
 
**Shape of the topic.** Three stages so far. The first repeated the Topic 2 pattern
one level earlier — conclusion right, mechanism wrong. The second, after the truth
tables were written out, went 9 of 10 on the same traps. The third, on `IN` / `LIKE` /
`ORDER BY`, showed the mechanisms holding: the misses are no longer about NULL being
misunderstood but about carrying a previous answer over by analogy (B7), negating a
range wrongly (B8), and attaching an option to the wrong expression (G1).
 
Block E still does not improve: seven slips, all the same shape — sound reasoning, text
not re-read. Two of them produced the right output from a wrong query, which is the
variety that survives review.
