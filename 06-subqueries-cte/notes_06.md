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
 
## 4. Practice
 
- Two tasks so far, 11 items. No query was written by the student: in both tasks the
  query was given and the student predicted what it returns.
- Predictions checked from the other side: task 1, item 4 (5 rows in the result plus
  6 rows left out = 11 rows of `delivery_items`); task 2 by running the query. The
  changed subquery of 3.3 was not run.
- PGExercises: no change since topic 5 (`context_06.md`, 7.4). To return to after
  topic 6.
---
 
## 5. Open questions
 
1. **No migration history in the remote project** (1.3). Decide how the remote is
   updated before the first `supabase db push`. Carried from topic 5.
2. **Which revision is in force.** Both queries exist (`notes_05.md`, 9.1 and 9.2);
   step 7 of this topic rewrites them with a subquery and a CTE. The choice is the
   student's.
3. **Plan against catalogue price** needs the unit conversion tables. Carried.
4. **Plan and fact for a site in one result, without multiplying rows.** Step 5.
5. **`seed.sql` hard-codes surrogate ids.** Step 8. In `INSERT ... SELECT` the natural
   key breaks where it is NULL: `materials.article_no` of materials 3 and 7,
   `suppliers.tax_id` of suppliers 3 and 6.
6. **Functional dependence in `GROUP BY`** (7.2.3) is not tested. Carried.
7. **Debts from topic 4, untouched:** no `CHECK` on the dates of `sites`; delivery
   line 7 is dated before the start of its site; no `from_unit_id <>
   materials.unit_id` rule in `material_unit_conversions`.
8. **Section numbers of the documentation** (2): check each against the page of
   version 17 before it is cited in a task.
9. **`schema-design.md`, doubled marker** (1.5).
10. **Window functions** are topic 7. `CASE` and `ROLLUP`: place in the course
    unknown. Exercises of PGExercises Aggregates 11 to 22 are for after topic 6, those
    with window functions after topic 7.
---
 
## 6. How the tutoring should run
 
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
