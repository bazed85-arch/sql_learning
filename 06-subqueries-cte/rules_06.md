# Rules — subqueries, CTEs, INSERT ... SELECT
 
**Block 1 · Topic 6 — subqueries and common table expressions**
 
Reference sheet. Read before writing any query with a subquery, a `WITH`, or an
`INSERT ... SELECT`.
 
Rules only — no history of who got what wrong. Each rule states the **mechanism**,
not just the conclusion.
 
Target: PostgreSQL 17 / Supabase.
 
Sources: the PostgreSQL documentation, version 17: Scalar Subqueries (4.2.11),
Subquery Expressions (9.24), Subqueries in `FROM` (7.2.1.3), WITH Queries (7.8),
`INSERT`. **Checked:** the page addresses, section numbers and titles above appear in
search results for the version 17 pages (`sql-expressions.html`,
`functions-subquery.html`, `queries-table-expressions.html`, `queries-with.html`,
`sql-insert.html`). **Not checked:** the anchors inside the pages (`#...`), and the full
text of the pages: the fetch tool refused them, so only the excerpts in the search
results were read. Every rule below was run on the live database
(`construction-supply`) unless it says otherwise.
 
---
 
## 1. Scalar subquery
 
**1.1 A scalar subquery is a `SELECT` in parentheses that returns one row and one
column; it is used where a single value is expected,** for example on the right of
`=` or `>` in `WHERE`.
 
**1.2 More than one row is an error:** `more than one row returned by a subquery used
as an expression` (21000). The error comes from the data, not from the text of the
query: the same query works while the subquery returns one row.
 
**1.3 Zero rows give NULL, not an error.** A comparison with that NULL is NULL, and
`WHERE` keeps only true (rules_04, 7.2), so the outer query returns 0 rows.
 
**1.4 An aggregate in the subquery with no `GROUP BY` is one group, so one row, even
over no rows.** `avg` over no rows is NULL (rules_05, 1.3), `count` is 0.
 
**1.5 A `WHERE` inside a subquery filters the rows of the subquery only.** The outer
query still reads all its own rows. `delivery_items AS di2` inside the subquery and
`delivery_items AS di` outside are two readings of one table; the alias says which
one a condition belongs to.
 
**1.6 A subquery that names a column of the outer query is correlated** (3.1). One
that does not is evaluated on its own, and gives the same value for every outer row.
Deleting the correlating condition turns the first kind into the second: with
`WHERE e2.number = e.number` removed, `max(e2.revision)` is the maximum of the whole
table for every row.
 
---
 
## 2. IN and NOT IN with a subquery
 
**2.1 `x IN (subquery)` is `x = ANY (subquery)`; `x NOT IN (subquery)` is `x <> ALL
(subquery)`.** They compare `x` with every value of the subquery.
 
**2.2 `IN` gives:**
 
- true if some value equals `x`;
- NULL if no value equals `x` and some comparison is NULL (a NULL in the subquery, or
  `x` itself is NULL and the subquery is not empty);
- false if no value equals `x` and there is no NULL, or the subquery is empty.
 
**2.3 `NOT IN` is `NOT` of that:**
 
- false if some value equals `x`, **even when NULLs are present**;
- NULL if no value equals `x` and a NULL is present, or `x` is NULL and the subquery
  is not empty;
- true if no value equals `x` and there is no NULL, or the subquery is empty.
 
**2.4 `WHERE` keeps only true.** So when the subquery returns one NULL, `NOT IN`
returns 0 rows for every `x` that has no equal value: each such row gets NULL, not
true. This is the NULL trap.
 
**2.5 Before `NOT IN`, count the NULLs of the subquery column.** If there can be one,
write `NOT EXISTS` (3.4) or add `WHERE column IS NOT NULL` inside the subquery. The
negation of `IS NULL` is `IS NOT NULL`.
 
**2.6 A condition that limits the subquery to some rows of its own table is not a
condition on the outer rows.** `WHERE s2.id IN (1, 3)` inside the subquery reads a
list of two values; 2 is not in it.
 
---
 
## 3. EXISTS and NOT EXISTS
 
**3.1 A correlated subquery refers to a column of the outer query** (`d.supplier_id =
s.id`). For each row of the outer query it is evaluated with that row's value.
 
**3.2 `EXISTS (subquery)` is true if the subquery returns at least one row, false if
it returns none. It never gives NULL.** The select list of the subquery is not used:
`SELECT 1` and `SELECT *` mean the same, and `1` is only a constant.
 
**3.3 `EXISTS` gives one result per outer row.** Unlike a join to the same table, it
does not repeat the outer row for each match: a supplier with two deliveries stands
in the result once.
 
**3.4 `NOT EXISTS` is `NOT` of true or false, so true or false, never NULL.** A NULL in
the compared column makes the comparison inside the subquery NULL, no row is found,
and the outer row is kept. For the same data `NOT IN` returned 0 rows and `NOT EXISTS`
returned 10 (the NULL trap of 2.4).
 
| Subquery, for an outer value with no equal value in it | `NOT IN` | `NOT EXISTS` |
|---|---|---|
| no NULL among the values | true | true |
| a NULL among the values | NULL, row dropped | true, row kept |
| no rows | true | true |
 
**3.5 `x = NULL` is never true, in any clause.** To test for NULL, write `x IS NULL`.
 
---
 
## 4. ANY and ALL
 
**4.1 `x op ANY (subquery)` is true if the comparison is true for at least one value;
false if it is false for all and there is no NULL (or the subquery is empty); NULL
if none is true and a NULL is present.**
 
**4.2 `x op ALL (subquery)` is true if the comparison is true for every value (or the
subquery is empty); false if it is false for at least one; NULL if none is false and a
NULL is present.**
 
**4.3 Constant check, run:** `5 > ANY (VALUES (9), (NULL))` is NULL; `5 > ALL
(VALUES (9), (NULL))` is false. Not run on a table.
 
**4.4 With no NULL among the values, `> ALL (subquery)` keeps the rows larger than the
largest value and `> ANY (subquery)` keeps the rows larger than the smallest.** The comparison is of the
outer row with the values of the subquery, not of the outer rows with each other.
 
---
 
## 5. Subquery in FROM
 
**5.1 A subquery in `FROM` is a derived table; the outer query reads its columns as
`alias.column`.** The page of version 17 says it may be given an alias; the page of
version 15 says it must. Version 16 was not seen. Write the alias: it works in every
version and is needed to name the table in the outer query.
 
**5.2 A name declared in the subquery (`AS site_id`) is a real column for the outer
query,** so the outer `WHERE` can use it. A label in the select list of one `SELECT`
cannot be used in its own `WHERE` or `HAVING` (rules_05, 3.5).
 
**5.3 `GROUP BY` inside the derived table gives one row per key.** Joining two such
tables on the key gives 1 × 1 rows per key instead of the product of the two
branches (rules_05, 5.3: 5 × 6 = 30). Plan and fact for a site in one result:
 
```sql
FROM sites AS s
LEFT OUTER JOIN (... GROUP BY e.site_id) AS p ON p.site_id = s.id
LEFT OUTER JOIN (... GROUP BY di.site_id) AS f ON f.site_id = s.id
```
 
**5.4 `LEFT OUTER JOIN` to a derived table adds a row with NULL when no row of the
derived table meets `ON`.** A site with no approved estimate has NULL in
`planned_total`. `INNER JOIN` inside the derived table drops what has no partner: an
approved estimate with no lines adds nothing to the sum.
 
**5.5 `ORDER BY` accepts a label of the select list and a column of `GROUP BY`**
(rules_05, 3.5).
 
---
 
## 6. WITH (common table expressions)
 
**6.1 `WITH name AS (SELECT ...)` names a query for the length of one statement; the
main query reads it as a table.** It is the same as a derived table (5.1), written
before the main `SELECT`.
 
**6.2 Several CTEs go in one `WITH`, separated by commas.** A CTE may read CTEs written
above it in the same `WITH`, and **not the ones below it:** the order matters, a
reference to a later CTE is an error (stated from the documentation; the error text
was not run). Two CTEs that do not read each other can be written in either order.
 
**6.3 A CTE returns what its own query returns, whatever the main query does with
it.** Check each CTE alone, then the main query: 4 rows in `approved`, 9 in `lines`, 3
in the whole query (task 14).
 
**6.4 Join and filter rules do not change in a CTE.** `INNER JOIN` to a CTE drops the
rows without a partner; `LEFT OUTER JOIN` keeps them with NULL (5.4). `LEFT OUTER JOIN`
inside the CTE adds one row with NULL for each left row with no partner.
 
**6.5 Not covered:** `WITH RECURSIVE`, materialization (`MATERIALIZED`), data-changing
statements in `WITH`.
 
---
 
## 7. Latest revision for each estimate number
 
**7.1 Correlated subquery:**
 
```sql
WHERE e.revision = (SELECT max(e2.revision)
                    FROM estimates AS e2
                    WHERE e2.number = e.number)
```
 
For each row the subquery gives the highest revision of that row's number (rules_05, 7.1). The rows left out are the older revisions.
 
**7.2 CTE and `JOIN`:**
 
```sql
WITH latest AS (SELECT e2.number AS number, max(e2.revision) AS max_revision
                FROM estimates AS e2 GROUP BY e2.number)
... INNER JOIN latest AS l ON l.number = e.number AND l.max_revision = e.revision
```
 
Same rows as 7.1. `latest` has one row per number, so with `ON l.number = e.number`
alone nothing is dropped and nothing is repeated; the second condition of `ON`
removes the older revisions.
 
**7.3 Two rows with the same number and the same highest revision would both be
returned, by either query.** Follows from the conditions; not run, the data has no
tie.
 
**7.4 The schema does not say which revision is in force** (rules_05, 7.3). Both
queries take the highest revision, whatever its status. Restricting to approved ones
is a different question and goes in `WHERE` before the maximum.
 
---
 
## 8. INSERT ... SELECT
 
**8.1 `INSERT INTO t (columns) query` inserts every row the query returns, columns by
position.** A column left out of the list gets its `DEFAULT`, or NULL if it has none.
Zero rows from the query insert nothing and are not an error.
 
**8.2 A constraint violated by any one inserted row cancels the whole command**
(primary key, `NOT NULL`, foreign key, `CHECK`). Rows the query did not return are not
checked: `WHERE` removes a row before the `INSERT` sees it.
 
**8.3 A natural key found by a scalar subquery gives NULL when nothing matches** (1.3).
`(SELECT s.id FROM suppliers AS s WHERE s.tax_id = '...')` for a tax number that is
not in the table is NULL, and if the target column is `NOT NULL` the command fails
(`supplier_materials.supplier_id`). Check the subquery with a plain `SELECT` first.
 
**8.4 A NULL in `WHERE` drops the row** (2.4, 3.5): `s.tax_id = NULL` keeps none, and
the `INSERT` adds 0 rows with no error. A NULL in the select list goes to the column.
Two different effects of one value.
 
**8.5 `NOT EXISTS` on the target table keeps the command from inserting a pair that is
already there:** the pair (7, 10) is dropped, (7, 8) and (7, 11) are inserted.
 
**8.6 `CROSS JOIN` gives every pair of one row from each table:** the number of rows of
the first times the number of rows of the second, before `WHERE`.
 
**8.7 Natural keys can be NULL:** `materials.article_no` of materials 3 and 7 and
`suppliers.tax_id` of suppliers 3 and 6. A lookup by those keys finds nothing (8.3, 8.4).
Not tested on a source table with NULL natural keys.
 
---
 
## Checklist before running a query with a subquery
 
1. Which kind is the subquery: scalar (one row, one column), a list for `IN`/`ANY`/`ALL`,
   `EXISTS`, a derived table in `FROM`, or a CTE?
2. Scalar: can it return more than one row (21000) or none (NULL)?
3. `IN`, `NOT IN`, `ANY`, `ALL`: how many NULLs does the subquery column hold? If there
   can be one, what does each form give for a value with no equal one (2.3, 4.1, 4.2)?
4. Negation of "found in another table": use `NOT EXISTS`, not `NOT IN`, unless the
   column has no NULL.
5. Does the subquery name an outer column? Where does each `WHERE` belong: to the
   subquery or to the outer query?
6. Derived table or CTE: how many rows per key does it give? Does a join to it repeat
   rows? `GROUP BY` inside, one row per key.
7. Join to a derived table or CTE: inner or left? What stands in the row with no
   partner (NULL)?
8. CTE chain: is each CTE written below the ones it reads?
9. `INSERT ... SELECT`: run the `SELECT` alone first. How many rows? Does any column
   come out NULL where the target is `NOT NULL`? Does any row repeat a primary key?
10. Predict the number of rows from one side, then check it from the other: rows kept
    plus rows left out equal the rows of the table.
