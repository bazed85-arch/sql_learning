# Rules — GROUP BY, HAVING, aggregate functions
 
**Block 1 · Topic 5 — aggregation**
 
Reference sheet. Read before writing any query with an aggregate function or a
`GROUP BY`.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion.
 
Target: PostgreSQL 17 / Supabase.
 
Sources for most of this sheet:
[9.21 Aggregate Functions](https://www.postgresql.org/docs/17/functions-aggregate.html),
[4.2.7 Aggregate Expressions](https://www.postgresql.org/docs/17/sql-expressions.html#SYNTAX-AGGREGATES),
[7.2.3 GROUP BY and HAVING](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-GROUP),
[7.2.1.1 Joined Tables](https://www.postgresql.org/docs/17/queries-table-expressions.html#QUERIES-JOIN).
 
---
 
## 1. Aggregates and NULL
 
**1.1 `count(*)` counts rows. `count(expression)` counts the rows where the
expression is not NULL. `count(DISTINCT expression)` counts the different non-NULL
values.** On a `NOT NULL` column `count(column)` and `count(*)` are equal; on a
column that is NULL in every row `count(column)` is 0 and `count(*)` is still the
number of rows.
 
**1.2 `sum`, `avg`, `min` and `max` skip NULL inputs.** NULL is not treated as 0:
`avg` over 3, 3 and NULL is 3, not 2.
 
**1.3 With no non-NULL input, `count` returns 0 and every other aggregate returns
NULL.** The input is empty when there are no rows or when every value is NULL.
 
- `sum` over a group whose only row has NULL gives NULL, not 0.
- `max(revision) + 1` over no rows is `NULL + 1`, which is NULL, not 1.
- A query with an aggregate and no `GROUP BY` still returns one row when no row
  passes `WHERE`.
**1.4 `avg` of an `integer` column is `numeric`:** 2.42, not 2. Do not write the
value as an integer.
 
**1.5 Label every aggregate with `AS`.** Two unlabelled aggregates are both named
`count`. In the Supabase SQL Editor only one of the two columns was visible.
 
---
 
## 2. GROUP BY
 
**2.1 Without `GROUP BY`, a query with an aggregate in the select list is one group:
the whole result of `FROM` and `WHERE`.** With `GROUP BY`, one group per different
combination of the grouping values.
 
**2.2 A group is formed only from rows that exist.** A site with no estimate has no
row in `estimates`, so `GROUP BY site_id` over `estimates` has no group for it.
To get a group for it, take the sites from `sites` and `LEFT OUTER JOIN` the
estimates to them.
 
**2.3 A column in the select list is either in `GROUP BY` or inside an aggregate.**
Otherwise the error is `column "sites.id" must appear in the GROUP BY clause or be
used in an aggregate function` (42803). A group holds several rows, so a column
outside `GROUP BY` has several possible values and the group has no single one to
show. The query is rejected by its text, even if the data would give one value.
 
**2.4 `GROUP BY` on two columns:** one group per different pair of values. The
pairs (1, A) and (1, B) are two groups.
 
**2.5 Not tested in this project:** section 7.2.3 allows a column that is
functionally dependent on the grouped columns, for example when grouping by a
primary key. All the queries of this topic grouped by explicit columns.
 
**2.6 Without `ORDER BY` the order of groups is undefined.** Add `ORDER BY` on the
grouping column.
 
---
 
## 3. WHERE and HAVING
 
**3.1 `WHERE` filters rows before grouping. `HAVING` filters groups after the
aggregates are computed.**
 
**3.2 An aggregate in `WHERE` is an error** (`aggregate functions are not allowed
in WHERE`). When `WHERE` runs, the groups do not exist yet. A condition on an
aggregate goes in `HAVING`.
 
**3.3 A condition on a single row belongs in `WHERE`, even if `HAVING` would accept
it.** The two return different things:
 
- `WHERE ei.total > 1000` removes the rows first, so the sums are taken over the
  remaining rows only, and a group that loses all its rows disappears.
- `HAVING sum(ei.total) > 10000` keeps every row in the sum and then removes whole
  groups.
**3.4 A number or a key whose only rows fail `WHERE` is missing from the result;**
it does not appear with 0. `WHERE status = 'approved'` leaves no group for an
estimate number that has no approved row.
 
**3.5 A label from the select list can be used in `GROUP BY` and `ORDER BY`, not in
`WHERE` or `HAVING`.** `HAVING estimate_total > 10000` fails with `column
"estimate_total" does not exist`. Write the expression out:
`HAVING sum(ei.total) > 10000`. Behaviour checked on the live database; the text of
the `output_name` parameter on the version 17 page of `SELECT` was not confirmed.
 
---
 
## 4. Aggregates after an outer join
 
**4.1 A left row without a match becomes one row with NULL in every right column.**
`count(*)` counts that row: 1. `count(right.id)` does not: 0. To count matches, count
a right column that cannot be NULL inside its own table, normally its `id`.
 
**4.2 A condition on a column of the right table in `WHERE` removes the added rows
and the outer join collapses into an inner join** (rules_04, 7.3). Put the condition
in `ON` if the left rows without a match are wanted:
 
```sql
LEFT OUTER JOIN estimates AS e ON e.site_id = s.id AND e.status = 'approved'
```
 
Sites with no approved estimate stay, with `count(e.id)` = 0.
 
**4.3 Left rows without a match, found with an aggregate:**
`GROUP BY s.id HAVING count(e.id) = 0`. The group exists because the outer join added
its row.
 
**4.4 In a chain of two `LEFT OUTER JOIN`s the second joins to the result of the
first.** A row of the first result with NULL in `e.id` meets no row in the second
join (`ei.estimate_id = NULL` is not true), so it stays once, with NULL in the
columns of the third table.
 
---
 
## 5. Rows repeated by a join
 
**5.1 The rule of 7.2.1.1: for each row R1 of T1 there is a row in the result for
every row of T2 that satisfies the join condition with R1.** A row of T1 with three
matches stands in three rows of the result.
 
**5.2 An aggregate works on the repeated rows.** `count(*)` counts every
repetition, and `sum` over a column of the repeated table adds the same value once
per repetition. The query runs without error and the sum looks like a sum.
 
**5.3 Two independent branches from one table repeat each other.** Estimate lines
and delivery lines both hang on `sites`. In
 
```sql
FROM sites AS s
LEFT OUTER JOIN estimates AS e ON e.site_id = s.id AND e.status = 'approved'
LEFT OUTER JOIN estimate_items AS ei ON ei.estimate_id = e.id
LEFT OUTER JOIN delivery_items AS di ON di.site_id = s.id
```
 
the fourth condition names neither `e` nor `ei`. Each of the 5 rows of site 1 after
the first three parts meets all 6 delivery lines: 5 × 6 = 30 rows. The rows
multiply, they do not add (5 + 6 = 11 is wrong). `sum(ei.total)` comes out 6 times
too large, `sum(di.total)` 5 times. Count each branch in its own query, grouped by
`sites.id`.
 
**5.4 The sign of repetition: for a key column `x` of the repeated table,
`count(x)` is not equal to `count(DISTINCT x)`.** Equal values mean every row stands
once. `DISTINCT` sits inside the aggregate; it changes what the aggregate counts,
not how many rows the join makes.
 
**5.5 `count(DISTINCT x)` counts each different value once; it does not choose
among rows.** For the values 1, 1, 1, 1, 7 it gives 2, and `count(x)` gives 5.
 
---
 
## 6. Checks from the other side
 
**6.1 Predict the number of rows before `GROUP BY` from one side, then check it
from the other.** Never estimate by eye (rules_04, checklist 4).
 
**6.2 Sum of the numbers of rows over the groups = the number of rows before
`GROUP BY`.** For example 6 + 2 + 3 + 1 + 1 + 1 = 14 for the join of `sites` to
`delivery_items`: 11 pairs plus one added row each for three sites.
 
**6.3 Sum of `count(right.id)` over the groups = the number of rows of the right
table that found a partner, when each right row has at most one partner.** If it is
smaller than the number of rows of the right table, find the condition that kept the
rest out: 9 of 12 estimate lines, the other 3 belong to estimates that fail
`status = 'approved'` in the `ON` of the first join.
 
**6.4 Sum of `sum(x)` over the groups = the sum of `x` over the rows that entered
the groups.** A sum that is a multiple of the correct one (6 times, 5 times) means
repeated rows (5.3).
 
---
 
## 7. Latest row per key: `max` over a group
 
**7.1 `SELECT number, max(revision) ... GROUP BY number`** gives the highest
revision of each number, whatever its status.
 
**7.2 Adding `WHERE status = 'approved'` gives the highest approved revision.**
`WHERE` runs before `GROUP BY`, so a revision that is a draft does not enter the
maximum, and a number with no approved revision has no group (3.4). For a number
with revision 2 approved and revision 3 a draft, 7.1 gives 3 and 7.2 gives 2.
 
**7.3 The schema does not say which revision is in force;** the two queries answer
two different questions. The choice is a decision, not a query.
 
**7.4 `max(revision) + 1` for a number with no row is NULL (1.3).** The application
has to handle a new number.
 
---
 
## Checklist before running an aggregate query
 
1. What is one row of the result? That is the grouping column.
2. Does every column of the select list stand in `GROUP BY` or inside an aggregate?
3. A condition on a row goes in `WHERE`, a condition on an aggregate goes in
   `HAVING`. Is any label of the select list used in either?
4. After a join: does any row on either side have more than one match? If so, the
   rows repeat and every sum over them is wrong.
5. After an outer join: is it `count(*)` or `count(right.id)`? Is a condition on the
   right table in `ON` or in `WHERE`?
6. What do an empty group and a group of NULLs return? `count` 0, everything else
   NULL.
7. Predict the number of rows before `GROUP BY` and the number of groups from one
   side, then check them from the other.
8. Does every aggregate have an `AS` label?
