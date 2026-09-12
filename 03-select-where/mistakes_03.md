# Mistakes Log — Block 1 · Topic 3
 
Errors made while learning to query the construction supply schema.
Format: **what I answered → why it is wrong → the rule → source**.
 
Repeats from earlier topics carry the original code, e.g. "repeat of C5, Topic 2".
 
Block letters are assigned per topic, but **F is reserved for Process** so the code F1
means the same thing as in Topic 2. There is no block E in this topic.
 
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
 
---
 
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
 
## F. Process
 
### F1. Half of a two-part question answered — twice
 
| Question | Asked | Answered |
|---|---|---|
| A1 | why the first query fails **and** why the second works | why the first fails |
| A3 | label in `GROUP BY` **and** in `HAVING` | `GROUP BY` only |
 
Both times the unanswered half was the part that would have exposed the faulty
mechanism: `ORDER BY` working is what shows the order matters, and `HAVING` failing is
what shows `GROUP BY` is an exception rather than a consequence.
 
**Repeat of F1, Topic 2** (five occurrences) and of E6, Topic 1. Carried over across
a topic boundary for the first time.
 
---
 
## Applied correctly, unprompted
 
Recorded because a log of failures alone distorts the picture.
 
- **Projection and row count** — `SELECT id, name` on 25 rows returns 25; `FROM` sets
  rows, the select list sets columns. Answered without prompting.
- **Column labels and reserved words** — both halves of the `SELECT name unit_name` /
  `SELECT name from FROM units` question answered correctly, including both fixes
  (quotes or `AS`). The wording used — "the label does not collide with a PostgreSQL
  keyword" — is closer to the documentation's own rule than the grammar-level
  explanation given in reply; see `rules.md` 2.3.
- **`DISTINCT` with NULL, on the second pass** — after the mechanism was given, the
  follow-up questions (2a: 6 and 7; 3a: 5) were answered correctly, including the
  NULL-collapses-to-one-row part that B1 got wrong.
- **Four practice queries, four row-count predictions, all four correct** —
  projection with labels, single-column `DISTINCT`, two-column `DISTINCT` including
  the `(NULL, true)` pair, and an expression with `char_length`. Predictions were
  written before running, which is the procedure the Topic 2 scorecard said was
  missing.
- **Repository discipline** — spotted that keeping practice queries in a file was
  pointless, and that a `README` describing files that do not exist is the same class
  of drift as a `seed.sql` describing data that does not exist.
---
 
## Scorecard — Topic 3 (in progress)
 
| | Count |
|---|---|
| Clause evaluation order | 3 |
| NULL semantics | 1 |
| DISTINCT mechanics | 1 |
| Answer completeness | 1 |
| Process | 2 |
| **Total so far** | **8** |
 
Repeats carried over: C5/A5 (Topic 2) as A2, A5 (Topic 2) as B1, recurring pattern 11
(Topic 2) as A3, F1 (Topic 2) as F1.
 
Pattern of the topic so far: **the conclusion is right and the mechanism behind it is
not** — A1, A3, C1. Three of eight. In Topic 2 the equivalent pattern was "the rule is
known, the wrong thing reaches the code"; here it is one step earlier, in the
reasoning itself.
