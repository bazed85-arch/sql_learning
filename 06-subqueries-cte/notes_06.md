# Notes — Topic 6, subqueries and common table expressions
 
Working notes: what was found in the repository, what was checked against a live
database, what is still open.
 
Data for every task is read directly from the Supabase project
`construction-supply` (id `vqwzldlsasunjmltsgpj`). Numbers are for the state at the
start of the topic: `estimates` has 8 rows, no changes to the live database were made
in this topic so far.
 
---
 
## 1. Repository and database state at the start of the topic
 
**1.1 Migrations.** The listing of `supabase/migrations` was sent by the student as a
screenshot of the folder on GitHub, 2026-11-02. It shows exactly the 11 files of
`context_06.md`, section 7.1, in the same order, each with one `.sql` extension. The
five renamed files carry the commit message "Rename …", dated last week. The
screenshot is the repository on GitHub; the student's local folder was not seen.
 
**1.2 `seed.sql`.** The student attached the file as the version from his repository.
It contains the second `INSERT INTO estimates` with `revision` listed
(`estimates.id` 7 and 8) and the comments "Eight estimates". So the repository holds
the version with the two rows (by the student's statement; not compared with GitHub
by the tutor). The open question 9 of `notes_05.md` is closed.
 
**1.3 The live database has no migration history.** `list_migrations` on the project
returns an empty list (2026-11-02). Same fact as `notes_05.md`, 1.3. Assessment, not
fact: `supabase db push` into this project would try to apply every migration from
the start and fail on the first `CREATE TABLE`.
 
**1.4 Row counts in the live database, 2026-11-02.**
 
| table | rows |
|---|---|
| `units` | 8 |
| `suppliers` | 8 |
| `sites` | 6 |
| `materials` | 12 |
| `supplier_materials` | 13 |
| `estimates` | 8 |
| `estimate_items` | 12 |
| `deliveries` | 9 |
| `delivery_items` | 11 |
| `unit_conversions` | 2 |
| `material_unit_conversions` | 4 |
 
All eleven counts equal the counts in `seed.sql`. The sum of `delivery_items.total` is
18390.00, as at the end of topic 5.
 
**1.5 `schema-design.md`, one markup defect found while reading the attached file.**
In the "Deferred to Block 2" list the item "Estimate versioning, remainder" starts
with a doubled marker (`- - **Estimate versioning, remainder**`), and the paragraph
"Implemented and removed from this list" is indented by two spaces. `notes_05.md`,
1.4, says a doubled marker was fixed in the same list. Not corrected; the student
decides.
 
---
 
## 2. Plan of the topic
 
The student had no list of items for topic 6. The tutor proposed the list below from
the PostgreSQL documentation; the student accepted it on 2026-11-02, with the number
of tasks.
 
| # | Item | Tasks |
|---|---|---|
| 1 | Scalar subquery | 2 |
| 2 | `IN` and `NOT IN` with a subquery, the NULL trap | 2 |
| 3 | `EXISTS` and `NOT EXISTS`, a subquery that refers to the outer query | 2 |
| 4 | `ANY` and `ALL` | 1 |
| 5 | Subquery in `FROM`; plan and fact for a site in one result | 3 |
| 6 | `WITH`, several CTEs in a row | 2 |
| 7 | Highest revision for each `estimates.number`, subquery against CTE | 2 |
| 8 | `INSERT ... SELECT` with a subquery by the natural key | 2 |
 
Sixteen tasks. This is the tutor's estimate, based on about two tasks a step in
topic 5. Not in the plan: `WITH RECURSIVE` (the schema has no hierarchy), `LATERAL`,
window functions (topic 7).
 
**Section numbers of the documentation, not checked.** The pages of version 17 could
not be fetched in this session: the fetch tool refused the URLs. Numbers come from
search results.
 
- 7.8, WITH Queries (Common Table Expressions): seen in results for other versions.
  Subsections 7.8.1 and 7.8.2 are seen; 7.8.3 and 7.8.4 are from memory.
- Subquery Expressions: 9.23 in versions 15 and 16, 9.24 in version 18. Version 17 not
  seen; the number 9.24 in `context_06.md` is consistent with that, not confirmed.
- 4.2.11 Scalar Subqueries, 7.2.1.3 Subqueries, 7.2.1.5 LATERAL: from memory. The
  anchor `SQL-SCALAR-SUBQUERIES` of 4.2.11 was not confirmed; a mailing-list message
  quoting the current documentation gives the anchor as `SQL-SYNTAX-SCALAR-SUBQUERIES`.
---
 
## 3. Step 1: scalar subquery
 
Tasks 1 and 2.
 
**3.1 What it is.** A scalar subquery is an ordinary `SELECT` in parentheses that
returns exactly one row with one column (section 4.2.11; the wording was seen in a
quotation of the current documentation, the page of version 17 was not opened). It is
used where a single value is expected, here on the right side of a comparison.
 
**3.2 A subquery with an aggregate and no `GROUP BY` (task 1).**
 
```sql
SELECT di.id AS id, di.total AS total
FROM delivery_items AS di
WHERE di.total > (SELECT avg(di2.total) FROM delivery_items AS di2)
ORDER BY di.id;
```
 
Run on the live database. The subquery has no reference to `di`; it reads the same
table under the alias `di2`.
 
- The subquery returns one row with one column. Without `GROUP BY` the eleven rows
  of `delivery_items AS di2` form one group (rules_05, 2.1), and `avg` gives one value
  for a group. The value is 1671.8181818181818182: 18390.00 over 11 rows.
- The result is 5 rows: `delivery_items.id` 1, 3, 4, 6, 7 with `total` 2584.00,
  6396.00, 2282.50, 2580.00, 2840.00. All five are above the average.
- Check from the other side: the rows that did not enter the result are
  `delivery_items.id` 2, 5, 8, 9, 10, 11 (178.00, 384.00, 408.00, 256.00, 184.50,
  297.00). 5 + 6 = 11 = rows of `delivery_items`.
**3.3 A subquery over no rows (task 1, items 5 to 8).** The subquery is changed to
`(SELECT avg(di2.total) FROM delivery_items AS di2 WHERE di2.total > 100000)`. No row
of `delivery_items` has `total` above 100000 (the largest is 6396.00).
 
- The subquery still returns one row, with NULL: an aggregate without `GROUP BY` is one
  group even when the group is empty, and `avg` over no values is NULL (rules_05, 1.3).
- `di.total > NULL` is NULL for every row. `WHERE` keeps a row only when the
  condition is true, so the outer query returns 0 rows (rules_04, 7.2).
- Assessment, not fact: this changed query was not run on the live database. The
  answers follow from the rules above and from the student's own reasoning.
**3.4 `GROUP BY` inside a scalar subquery (task 2).** The student asked whether
`GROUP BY` is allowed in a subquery. A scalar subquery is an ordinary `SELECT`, so the
clause is allowed; what it does to the number of rows was checked in task 2.
 
```sql
SELECT di.id AS id
FROM delivery_items AS di
WHERE di.total > (SELECT avg(di2.total)
                  FROM delivery_items AS di2
                  GROUP BY di2.site_id)
ORDER BY di.id;
```
 
| `delivery_items.site_id` | rows | sum of `total` | `avg(total)` |
|---|---|---|---|
| 1 | 6 | 14404.50 | 2400.75 |
| 2 | 2 | 481.50 | 240.75 |
| 3 | 3 | 3504.00 | 1168.00 |
 
- The subquery returns 3 rows, one per different `delivery_items.site_id`. Check:
  6 + 2 + 3 = 11 = rows of `delivery_items`; 14404.50 + 481.50 + 3504.00 = 18390.00.
- The student predicted an error because one row is expected and there are three. Run
  in the SQL Editor by the student, and by the tutor through the Supabase tool:
  `ERROR: 21000: more than one row returned by a subquery used as an expression`.
- The line "A limit of 100 was applied to your query" under the error is a note of the
  SQL Editor, not part of the error.
- The error is raised at execution, not by the text of the query: the query is valid
  and fails because of the data. Assessment, not fact: with one site in
  `delivery_items` the same text would run.
---
 
## 4. Step 2: IN and NOT IN with a subquery
 
Tasks 3, 4, 7 and 8. Sources: Subquery Expressions (9.23 in versions 15 and 16, 9.24
in version 18; version 17 not seen), subsections IN and NOT IN. The text of the rule
was seen in versions 16, 15 and 8; the page of version 17 was not opened.
 
**4.1 `IN` and repeated values in the subquery (task 3).**
 
```sql
SELECT m.id AS id
FROM materials AS m
WHERE m.id IN (SELECT ei.material_id FROM estimate_items AS ei)
ORDER BY m.id;
```
 
Run on the live database: 10 rows, `materials.id` 1, 2, 3, 4, 5, 6, 8, 9, 10, 11.
Materials 7 and 12 are not in `estimate_items`.
 
- The subquery returns 12 values with repeats: `estimate_items.material_id` 4 in
  lines 4 and 5, 11 in lines 6 and 12. `IN` gives one true or false for each row of
  `materials`, so no row of `materials` is repeated.
- The same selection with `FROM materials AS m INNER JOIN estimate_items AS ei ON
  ei.material_id = m.id` gives 12 rows, `m.id` 4 and 11 twice each (run on the live
  database). By the rule of 7.2.1.1 each row of `materials` stands once for every
  matching row of `estimate_items` (rules_05, 5.1).
- Check: 10 rows of `IN` + 2 repeated rows (`m.id` 4 and 11) = 12 rows of the join.
**4.2 The rule of `NOT IN` (tasks 4, 7, 8).** `x NOT IN (subquery)`: the subquery
returns one column, `x` is compared with each value. A subquery row is equal to `x`
when both values are not NULL and match. Result:
 
| What is found among the values of the subquery | Result of `NOT IN` |
|---|---|
| a value equal to `x` | false, even if the subquery also has NULL |
| no equal value, at least one NULL | NULL |
| no equal value and no NULL, including an empty subquery | true |
 
- `WHERE` keeps a row only when the result is true (rules_04, 7.2). False and NULL
  both remove the row.
- If `x` itself is NULL and the subquery is not empty, no value can be equal, every
  comparison is NULL, the result is NULL.
- The wording given in task 4 for the third row of the table, «равных нет, но есть
  строка с NULL», covered only NULL inside the subquery. It missed the case of NULL
  on the left, which the student found (T8 in mistakes_06). The documentation, as seen
  in version 8, says the result is NULL when every per-row result is unequal or null
  and at least one is null; that covers both.
**4.3 `NOT IN` over a column with NULL (task 4).**
 
```sql
SELECT m.id AS id
FROM materials AS m
WHERE m.article_no NOT IN (SELECT sm.supplier_article_no
                           FROM supplier_materials AS sm)
ORDER BY m.id;
```
 
`supplier_materials.supplier_article_no` has 13 values: 6 not NULL (CEC-42-25,
GRAVA-1220, PLB-STD-13, B500S-12, CEM-II-425, PA-BL-15) and 7 NULL.
`materials.article_no` is NULL for materials 3 and 7. Run on the live database:
**0 rows.**
 
| `materials.id` | `materials.article_no` | `NOT IN` | reason |
|---|---|---|---|
| 1 | CEM-II-425 | false | an equal value is among the 13 |
| 2 | CEM-I-525 | NULL | no equal value, NULL present |
| 3 | NULL | NULL | NULL on the left |
| 4 | PLB-STD-13 | false | an equal value is among the 13 |
| 5 | REBAR-12 | NULL | no equal value, NULL present |
| 6 | REBAR-20 | NULL | same |
| 7 | NULL | NULL | NULL on the left |
| 8 | GRAV-1220 | NULL | GRAVA-1220 is not equal; NULL present |
| 9 | INS-XPS-50 | NULL | no equal value, NULL present |
| 10 | PAINT-W-15 | NULL | PA-BL-15 is not equal; NULL present |
| 11 | SILIC-CLR | NULL | same |
| 12 | CEM-II-425-OLD | NULL | CEM-II-425 is not equal; NULL present |
 
No true, so `WHERE` removes all 12 rows. The same subquery under `IN` gives 2 rows,
`materials.id` 1 and 4 (run on the live database).
 
With `WHERE sm.supplier_article_no IS NOT NULL` inside the subquery the result is 8
rows: `materials.id` 2, 5, 6, 8, 9, 10, 11, 12 (run on the live database). Rows 1 and 4
stay false. Rows 3 and 7 stay NULL, because NULL is on the left; they are removed
too. Check: 8 rows + 4 rows left out (1, 3, 4, 7) = 12 rows of `materials`.
 
Written by the student after two corrections: `SELECT sm.supplier_article_no FROM
supplier_materials AS sm WHERE sm.supplier_article_no IS NOT NULL`. His first version
used the table name `supplier_materials` after the alias `sm` was set (rules_04, 9.3)
and `NOT NULL` instead of `IS NOT NULL`.
 
**4.4 Other examples, run by the tutor on the live database.**
 
| Query | Result | Reason |
|---|---|---|
| `m.id NOT IN (SELECT sm.material_id FROM supplier_materials AS sm)` | 2 rows, `materials.id` 9 and 12 | `supplier_materials.material_id` is part of the primary key, no NULL in the subquery |
| `m.name NOT IN (SELECT ei.description FROM estimate_items AS ei)` | 0 rows | all 12 values of `estimate_items.description` are NULL |
| `s.tax_id NOT IN (SELECT s2.tax_id FROM suppliers AS s2 WHERE s2.id IN (1, 3))` | 0 rows | the subquery gives B38123456 and NULL (supplier 3 has no tax id) |
 
A small example on made-up values, run on the database: left `l.v` A, B, NULL; right
`r.v` A, C, NULL. `NOT IN`: false, NULL, NULL. `NOT EXISTS`: false, true, true.
 
**4.5 Simple `NOT IN` without NULL (task 7).**
 
```sql
SELECT s.id AS id
FROM sites AS s
WHERE s.id NOT IN (SELECT di.site_id FROM delivery_items AS di)
ORDER BY s.id;
```
 
3 rows: `sites.id` 4, 5, 6 (run on the live database). `delivery_items.site_id` is
`NOT NULL`, the 11 values (1 six times, 3 three times, 2 twice) hold no NULL and not 4.
No equal value and no NULL: true.
 
**4.6 `NOT IN`, one NULL in a short subquery (task 8).**
 
```sql
SELECT s.id AS id
FROM suppliers AS s
WHERE s.tax_id NOT IN (SELECT s2.tax_id
                       FROM suppliers AS s2
                       WHERE s2.id IN (1, 3))
ORDER BY s.id;
```
 
The subquery returns B38123456 (supplier 1) and NULL (supplier 3). `IN (1, 3)` is a
list of two values, not a range. Result, run on the live database: **0 rows.** Supplier
1 gives false, every other row gives NULL.
 
With `AND s2.tax_id IS NOT NULL` added to the subquery: 5 rows, `suppliers.id` 2, 4, 5,
7, 8 (run on the live database). Suppliers 3 and 6 have NULL on the left and stay out,
supplier 1 is false. Check: 5 + 3 left out (1, 3, 6) = 8 rows of `suppliers`.
 
---
 
## 5. Step 3: EXISTS and NOT EXISTS
 
Tasks 5 and 6.
 
**5.1 `EXISTS` and a subquery that refers to the outer query (task 5).** Sources:
the subsection EXISTS, versions 16 and 18, and the example in version 8; the page of
version 17 was not opened. The subquery is evaluated to see whether it returns any
rows; it can refer to columns of the outer query, which act as constants during one
evaluation; the contents of its select list are normally unimportant. In
`SELECT 1` the value 1 is a constant: the subquery gives one row with 1 for each row
that passes its `WHERE`. The version 8 page says such a query is like an inner join but
gives at most one row for each row of the outer table.
 
```sql
SELECT s.id AS id
FROM suppliers AS s
WHERE EXISTS (SELECT 1 FROM deliveries AS d WHERE d.supplier_id = s.id)
ORDER BY s.id;
```
 
Run on the live database: 7 rows, `suppliers.id` 1, 2, 3, 4, 5, 6, 7. Supplier 8 has no
delivery. The join `suppliers INNER JOIN deliveries ON
d.supplier_id = s.id` gives 9 rows, `s.id` 1 and 3 twice each (run).
 
- For `suppliers.id` = 1 the subquery returns 2 rows (`deliveries.id` 1 and 5),
  `EXISTS` is true, supplier 1 stands in the result once.
- The student first answered 9 and then «2 раза» for supplier 3: the rows of
  `deliveries`, not one row per outer row (U4 in mistakes_06).
- Check: 7 rows + 1 left out (8) = 8 rows of `suppliers`.
**5.2 `NOT EXISTS` over the data of task 4 (task 6).**
 
```sql
SELECT m.id AS id
FROM materials AS m
WHERE NOT EXISTS (SELECT 1
                  FROM supplier_materials AS sm
                  WHERE sm.supplier_article_no = m.article_no)
ORDER BY m.id;
```
 
Run on the live database: **10 rows**, `materials.id` 2, 3, 5, 6, 7, 8, 9, 10, 11, 12.
 
- For `materials.id` = 3 (`article_no` NULL) the subquery returns 0 rows:
  `supplier_article_no = NULL` is NULL, never true. `EXISTS` is false, `NOT EXISTS`
  is true. `EXISTS` is true or false, never NULL.
- Rows 1 and 4 have an equal value in the subquery, `EXISTS` is true, `NOT EXISTS`
  is false. Check: 10 rows + 2 left out (1, 4) = 12 rows of `materials`.
- The same data under `NOT IN` gives 0 rows (4.3), under `NOT IN` with the NULL
  filter 8 rows. The two extra rows of `NOT EXISTS`, 3 and 7, are the materials with
  `article_no` NULL.
**5.3 `NOT IN` against `NOT EXISTS`.**
 
| | `NOT IN` | `NOT EXISTS` |
|---|---|---|
| What the subquery needs | one column | any select list, only the presence of rows matters |
| Possible results | true, false, NULL | true, false |
| Empty subquery | true | true |
| Equal value found | false | false |
| No equal, NULL in the subquery | NULL, the row is removed | true: `= NULL` is never true, no rows |
| NULL on the left, subquery not empty | NULL, the row is removed | true |
| Repeated values in the subquery | the outer rows are not repeated | the outer rows are not repeated |
| Reference to the outer table | not needed | needed, to tie the subquery to the row |
 
Assessment, not fact: before `NOT IN`, check whether the column of the subquery can
hold NULL, or use `NOT EXISTS`.
 
---
 
## 6. Practice
 
- Eight tasks so far, 37 items. Two tasks, 7 and 8, were added at the student's
  request after step 2, so steps 1 to 3 hold eight tasks against six planned.
- One piece of SQL written by the student: the subquery of 4.3, after two corrections.
  In the other tasks the query was given and the student predicted the result.
- Predictions checked from the other side: tasks 3, 4, 5, 6, 8 (the number of rows
  of the result plus the number of rows left out equals the rows of the table).
  Tasks 3 to 8 were checked by the tutor on the live database after the student's
  answers.
- The student asked for a table comparing `NOT IN` and `NOT EXISTS` (5.3), an example
  on a few rows (4.4), the rule as a whole without references to earlier wording, and
  two extra tasks, 7 and 8. He also asked that the tutor spend fewer messages: after
  two wrong answers in a row the rule is shown instead of a third narrowing question.
- PGExercises: no change since topic 5 (`context_06.md`, 7.4).
---
 
## 7. Open questions
 
1. **No migration history in the remote project** (1.3). Decide how the remote is
   updated before the first `supabase db push`. Carried from topic 5.
2. **Which revision is in force.** Both queries exist (`notes_05.md`, 9.1 and 9.2);
   step 7 of this topic rewrites them with a subquery and a CTE. The choice is the
   student's.
3. **Plan against catalogue price** needs the unit conversion tables. Carried.
4. **Plan and fact for a site in one result, without multiplying rows.** Step 5.
5. **`seed.sql` hard-codes surrogate ids.** Step 8. In `INSERT ... SELECT` the natural
   key breaks where it is NULL: `materials.article_no` of materials 3 and 7,
   `suppliers.tax_id` of suppliers 3 and 6. The same NULLs break `NOT IN` (4.3, 4.6).
6. **Functional dependence in `GROUP BY`** (7.2.3) is not tested. Carried.
7. **Debts from topic 4, untouched:** no `CHECK` on the dates of `sites`; delivery
   line 7 is dated before the start of its site; no `from_unit_id <>
   materials.unit_id` rule in `material_unit_conversions`.
8. **Section numbers of the documentation** (2): check each against the page of
   version 17 before it is cited in a task. Still open after tasks 1 to 8: every
   section number in tasks 1 to 8 is unchecked.
9. **`schema-design.md`, doubled marker** (1.5).
10. **Window functions** are topic 7. `CASE` and `ROLLUP`: place in the course
    unknown. Exercises of PGExercises Aggregates 11 to 22 are for after topic 6, those
    with window functions after topic 7.
11. **`ANY` and `ALL`** (step 4) are the general form: `NOT IN` is `<> ALL`, `IN` is
    `= ANY` in the documentation. Not tested yet; the NULL rule of `NOT IN` should be
    the same for `<> ALL`.
---
 
## 8. How the tutoring should run
 
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
- Seed formatting and comment wording are the tutor's job; the student supplies the
  content — why the data is what it is, in his own words.
- The mistakes log is kept silently and shown only in the topic summary.
Added in topic 5:
 
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
- One item of "what to send" at a time. A task is first shown with its first
  item only; the next item comes after a correct answer to the current one.
- The data needed for an item is repeated in the same message on request, so the
  student does not scroll the chat.
- The student answers in his own words. Matching the wording of the documentation
  is not required; the answer has to address the question asked.
- No item that tests only arithmetic. Sums of a few numbers are given by the
  tutor. A check from the other side is asked as "with the row count of which table
  must it match".
- A statement that comes from neither the documentation nor a query result is
  marked as an assessment. A table number or a section name taken from memory is
  checked against the page of the version in use, or marked as unchecked.
- A change to the data in the live database is announced before it is made,
  together with the earlier results it will change.
- Changes to a file the student edits by hand, and explanations of a list of
  changes, are given one point at a time: where to look, the text now, the text it
  becomes. The next point comes after the student writes that it is done.
- A phrase that names a kind of answer — "из каких частей складывается число",
  "проверка с другой стороны" — is defined in the same message: what is counted and
  into how many summands, or the row count of which table the number must match.
  Without it the student cannot tell what to write.
- One item holds one question. A number and a reason, two factors, or values and a
  comparison are separate items. Recorded from the log (T9, T20, T26 of topic 5),
  not from the student's words.
Added in this topic: nothing so far.
