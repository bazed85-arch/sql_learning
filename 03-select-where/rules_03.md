# Rules — SELECT, WHERE, ORDER BY
 
**Block 1 · Topic 3 — querying a single table**
 
Reference sheet. Read before writing any query.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion, because a conclusion without its mechanism does not transfer
to a new problem.
 
Target: PostgreSQL 17 / Supabase.
 
Status: partial. Covers clause evaluation order, the select list, column labels and
`DISTINCT`. `WHERE`, the logical operators, `IN` / `BETWEEN` / `LIKE`, `ORDER BY`,
`LIMIT` and NULL handling are added as the topic progresses — an empty section is
honest, an invented rule is not.
 
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
 
## 4. String length
 
`length(text)` and `char_length(text)` are the same function for `text` —
`char_length` is the SQL-standard spelling.
[9.4 String Functions](https://www.postgresql.org/docs/17/functions-string.html).
 
`length(trim(col)) > 0` in the Topic 2 `CHECK` constraints is the same `length`.
