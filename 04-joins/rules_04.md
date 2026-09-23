# Rules — JOIN
 
**Block 1 · Topic 4 — querying several tables**
 
Reference sheet. Read before writing any query that names more than one table.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion.
 
Target: PostgreSQL 17 / Supabase.
 
Source for most of this sheet:
[7.2.1.1 Joined Tables](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-JOIN).
 
---
 
## 1. A join combines exactly two tables
 
**1.1 One `JOIN` joins two tables, never more.**
 
```
T1 join_type T2 [ join_condition ]
```
 
Three tables need two `JOIN`s, four tables need three, each with its own `ON`.
 
**1.2 Joins chain and nest; without parentheses they nest left to right.**
 
```sql
FROM a
JOIN b ON ...      -- (a JOIN b)
JOIN c ON ...      -- ((a JOIN b) JOIN c)
```
 
The second `JOIN` joins `c` to the *result* of the first, not to `a`. Its `ON` may
therefore reference columns of both `a` and `b`.
 
Source: the paragraph under the syntax block, «Joins of all types can be chained
together, or nested».
 
---
 
## 2. Terms
 
| Term | Meaning | Source |
|---|---|---|
| referencing table | the table where the foreign key is declared | [5.5.5](https://www.postgresql.org/docs/17/ddl-constraints.html#DDL-CONSTRAINTS-FK) |
| referenced table | the table the foreign key points to | same |
| T1 / T2 | left and right operand of a join | 7.2.1.1 |
| join condition | the `ON` expression | 7.2.1.1 |
 
"Parent / child", "fan-out", "anti-join" are not terms of the PostgreSQL
documentation. Do not use them in notes as if they were.
 
---
 
## 3. INNER JOIN
 
**3.1 Every row of T1 is checked against every row of T2; a pair whose join
condition is true is emitted.**
 
**3.2 A row with no matching row on the other side disappears from the result.**
Both directions: T1 rows without a match and T2 rows without a match.
 
**3.3 A row with several matches is emitted once per match.**
This is where a query silently changes meaning: joining estimate lines to
`supplier_materials` repeats each line once per supplier, and summing
`estimate_items.total` over the result no longer gives the estimate total.
 
**3.4 Joining on a foreign key that is `NOT NULL` cannot change the row count of
the referencing side.** The foreign key guarantees at least one matching row,
`NOT NULL` forbids the NULL escape, and the referenced `PRIMARY KEY` forbids two.
That is the "check from the other side" for row-count predictions.
 
---
 
## 4. LEFT / RIGHT OUTER JOIN
 
**4.1 `LEFT OUTER JOIN`: first an inner join is performed; then, for each row of
T1 that satisfies the join condition with no row of T2, a row is added with NULL
in the columns of T2.**
 
**4.2 The left row keeps its own values.** Only T2 columns are NULL.
 
**4.3 `RIGHT OUTER JOIN` is the mirror image:** T2 rows are preserved, NULLs go in
T1 columns. `a LEFT JOIN b` and `b RIGHT JOIN a` return the same rows.
 
**4.4 The order of operands inside `ON` is irrelevant.** `a.id = b.a_id` and
`b.a_id = a.id` are the same condition. What matters is which table is on which
side of the `JOIN` keyword.
 
**4.5 If every left row has a match, `LEFT OUTER JOIN` and `INNER JOIN` return the
same rows.** Test data without unmatched rows cannot show the difference.
 
---
 
## 5. FULL OUTER JOIN
 
**5.1 Three groups of rows:** the inner join; plus one row per unmatched T1 row,
NULL on the right; plus one row per unmatched T2 row, NULL on the left.
 
**5.2 A row that fails the join condition appears twice — once from each side.**
With `ON s.id = e.site_id AND e.status = 'approved'`, a site whose only estimate is
rejected produces one row with NULLs on the right, and that estimate produces
another row with NULLs on the left. They are not merged.
 
---
 
## 6. CROSS JOIN
 
**6.1 Every row of T1 with every row of T2, no condition.** Row count is the
product: 6 sites × 8 units = 48.
 
**6.2 `CROSS JOIN` equals `INNER JOIN ... ON true`** and equals comma-separated
tables in `FROM`.
 
---
 
## 7. ON versus WHERE
 
**7.1 A restriction in `ON` is processed before the join; a restriction in `WHERE`
after it. It does not matter for inner joins, it matters a lot for outer joins.**
Source: the paragraph starting «This is because a restriction placed in the ON
clause».
 
**7.2 `WHERE` keeps a row only if the condition is true;** false *or NULL* discards
it. Source: [7.2.2](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-WHERE).
 
**7.3 Consequence for a condition on a column of the right table.** In a row added
by the outer join that column is NULL; `NULL = 'approved'` is NULL; `WHERE`
discards the row. The outer join collapses into an inner join. Put such a
condition in `ON` if the unmatched rows are wanted.
 
**7.4 A condition on a column of the left table behaves normally in `WHERE`,**
because that column holds a real value in every row, matched or not.
 
**7.5 Both forms run without error and both return plausible results.** This is not
a syntax question; the wrong one is only visible in the rows that are missing.
 
---
 
## 8. ON, USING, NATURAL
 
**8.1 `USING (a, b)` is shorthand for `ON t1.a = t2.a AND t1.b = t2.b`,** and
requires identical column names on both sides. It also merges each pair into one
output column.
 
**8.2 `NATURAL` builds the `USING` list automatically from all column names common
to both tables.**
 
**8.3 `NATURAL` is a risk, and the documentation says so in a Note.** Any column
that happens to share a name joins too. `estimate_items NATURAL JOIN
supplier_materials` joins on `material_id` *and* `created_at`; with different
insert times that is zero rows, with one transaction it would be a different
result again. A schema-wide habit of `created_at`, `id`, `notes` makes `NATURAL`
unusable in this project.
 
---
 
## 9. Self-join and aliases
 
**9.1 A table can be joined to itself under two aliases.** Source:
[7.2.1.2 Table and Column Aliases](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-TABLE-ALIASES).
 
**9.2 An alias renames the table, never its columns.** `d1.delivery_note_number` —
`d1` is the alias, `delivery_note_number` is the real column name from the DDL.
 
**9.3 Once an alias is given, the original table name cannot be used in that
query.**
 
**9.4 A symmetric self-join condition returns each pair twice.** `d1.id <> d2.id`
keeps both (3, 6) and (6, 3); `d1.id < d2.id` keeps one. `<>` plus `>=` together
mean `>` — write the single operator.
 
---
 
## 10. Finding rows with no match
 
**10.1 `LEFT OUTER JOIN` + `IS NULL` on a right-hand column returns the left rows
without a match.**
 
**10.2 The `IS NULL` column must be one that cannot be NULL inside the right
table itself** — a join column declared `NOT NULL`, or a `PRIMARY KEY` column.
Otherwise the result mixes two different things.
 
```sql
WHERE di.material_id IS NULL        -- NOT NULL in the table: only unmatched rows
WHERE sm.supplier_article_no IS NULL -- nullable: unmatched rows AND rows with no code
```
 
In this schema the second form returned 9 rows where the first returned 2.
 
---
 
## 11. The select list with several tables
 
**11.1 Qualify every column when more than one table is in `FROM`.** Otherwise
`column reference "id" is ambiguous`.
 
**11.2 A table prefix does not become part of the output column name.**
`SELECT s.name, m.name` yields two columns both labelled `name`; a client that maps
rows to keys keeps only one. Label them: `s.name AS supplier, m.name AS material`.
Source: [7.3.2 Column Labels](https://www.postgresql.org/docs/17/queries-select-lists.html#QUERIES-COLUMN-LABELS).
 
---
 
## 12. ORDER BY over a join
 
**12.1 Without `ORDER BY` the row order is undefined.** Rows that "came out last"
this time carry no guarantee.
 
**12.2 Sort by a column that identifies the row, not by one that merely describes
it.** `ORDER BY d.delivery_note_number, di.line_no` interleaves the lines of two
notes numbered `0457`, because only `(supplier_id, delivery_note_number, year_no)`
is unique. `ORDER BY d.id, di.line_no` does not.
 
---
 
## Checklist before running a join
 
1. Which table must keep all its rows? That one goes on the left, with
   `LEFT OUTER JOIN`.
2. Each condition: does it restrict the left table (`WHERE`) or the right one
   (`ON`)?
3. Does any row on either side have more than one match? If so, the row count
   grows and sums over the result are wrong.
4. Predict the row count from one side, then check it from the other. Never
   estimate by eye.
5. Is any `IS NULL` test on a column that is nullable inside its own table?
6. Are two output columns labelled the same?
7. Does `ORDER BY` name a column that actually identifies the row?
