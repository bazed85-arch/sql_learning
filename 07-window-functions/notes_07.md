# Notes - Topic 7, window functions
 
Working notes: what was found in the repository, what was checked against a live
database, what is still open.
 
Data for every task is read directly from the Supabase project
`construction-supply` (id `vqwzldlsasunjmltsgpj`). Numbers are for the state at the
start of the topic. No changes to the live database were made in this topic so far.
 
---
 
## 1. Repository and database state at the start of the topic
 
**1.1 Migrations and `seed.sql`.** The student attached `schema-design.md` and
`seed.sql` from the repository and said that every change is written in the
repository files, so nothing changed since 2026-11-11 outside the attached files. The
tutor did not compare them with GitHub.
 
**1.2 Row counts in the live database, 2026-11-11.**
 
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
18390.00, as in topics 5 and 6.
 
**1.3 Data used for window functions (live database, 2026-11-11).** The date of a
delivery is `deliveries.delivery_date`; `deliveries` has no `site_id`;
`delivery_items.site_id` is `NOT NULL`.
 
| `delivery_items.id` | `delivery_id` | `site_id` | `material_id` | `total` | `deliveries.delivery_date` |
|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 2584.00 | 2025-03-18 |
| 2 | 1 | 1 | 2 | 178.00 | 2025-03-18 |
| 3 | 2 | 1 | 5 | 6396.00 | 2025-04-02 |
| 4 | 3 | 1 | 8 | 2282.50 | 2025-04-05 |
| 5 | 3 | 1 | 7 | 384.00 | 2025-04-05 |
| 6 | 4 | 1 | 4 | 2580.00 | 2025-05-12 |
| 7 | 4 | 3 | 3 | 2840.00 | 2025-05-12 |
| 8 | 5 | 3 | 1 | 408.00 | 2026-01-20 |
| 9 | 6 | 3 | 7 | 256.00 | 2026-02-11 |
| 10 | 8 | 2 | 10 | 184.50 | 2024-10-03 |
| 11 | 9 | 2 | 11 | 297.00 | 2024-09-20 |
 
- Equal `delivery_date` values: rows 1 and 2, rows 4 and 5, rows 6 and 7 (rows 6 and 7
  belong to different sites). No two `delivery_items.total` are equal, so ranking
  uses `delivery_date`.
- Rows per `delivery_items.site_id`: site 1 has 6 (sum 14404.50), site 2 has 2 (sum
  481.50), site 3 has 3 (sum 3504.00). Sites 4, 5 and 6 have no rows.
**1.4 The live database has no migration history.** Carried from topic 6, 1.3.
Assessment, not fact: `supabase db push` into this project would try to apply every
migration from the start and fail on the first `CREATE TABLE`.
 
---
 
## 2. Plan of the topic
 
The student has no list of items for topic 7. The tutor proposed the list below from
the PostgreSQL documentation; the student did not object (accepted by silence, on
2026-11-11).
 
| # | Item | Tasks |
|---|---|---|
| 1 | `OVER ()`: an aggregate without collapsing rows | 2 |
| 2 | `PARTITION BY`; comparison with `GROUP BY`; named window `WINDOW` | 2 |
| 3 | `ORDER BY` inside `OVER`: default frame, running total, equal values (peers) | 3 |
| 4 | `row_number`, `rank`, `dense_rank` | 2 |
| 5 | `lag`, `lead` | 2 |
| 6 | `first_value`, `last_value`: the default frame trap | 2 |
| 7 | Explicit frame: `ROWS BETWEEN ... AND ...` | 2 |
| 8 | A window function in a subquery or a CTE: filter by the window result, latest estimate revision through `row_number`, first N in a group | 2 |
 
Seventeen tasks, the tutor's estimate. Not in the plan: frame `GROUPS`, `EXCLUDE`,
`percent_rank`, `cume_dist`, `ntile`, user-defined window functions, `FILTER` on window
aggregates, `WITH RECURSIVE`, `LATERAL`.
 
**Section numbers of the documentation, not checked.** Plan from: tutorial 3.5 Window
Functions (page `tutorial-window.html`), 4.2.8 Window Function Calls, 9.22 Window
Functions, 7.2.5 Window Function Processing. The pages of version 17 cannot be fetched
by the tutor (the address is not allowed), so section numbers and the summaries in the
tasks come from memory and are marked unchecked in every task. Anchors inside the
pages are not given.
 
---
 
## 3. Step 1: OVER () and the rows a window sees
 
Tasks 1 and 2. Documentation: PostgreSQL 17, 3.5 Window Functions,
https://www.postgresql.org/docs/17/tutorial-window.html (page not opened).
 
**3.1 A window function does not collapse rows (task 1).**
 
```sql
SELECT di.id AS id,
       di.total AS total,
       sum(di.total) OVER () AS all_total
FROM delivery_items AS di
ORDER BY di.id;
```
 
Items:
 
1. Rows of the whole query: 11, right on the first send.
2. `all_total` in the row `id` = 5: 18390.00, right. With `OVER ()` empty, the window is
   every row of the query, so the value is the same in each row.
3. The same query with `OVER ()` removed (`sum(di.total) AS all_total`): an error,
   right.
4. Which columns of the select list cause the error: `di.id` and `di.total`.
Run on the live database (the tutor), the query without `OVER ()` fails with
`42803: column "di.id" must appear in the GROUP BY clause or be used in an aggregate
function`. The message names `di.id` only; `di.total` stands outside the aggregate in
the same way (the message names the first column found, assessment).
 
- Without `OVER`, `sum` is an ordinary aggregate. A query with an aggregate in the
  select list and no `GROUP BY` is one group (rules_05, 2.1), one result row. `di.id`
  and `di.total` have 11 different values in the group and are not in `GROUP BY` and
  not inside an aggregate (rules_05, 2.3), so the query is rejected.
- With `OVER ()` the rows are not grouped: the sum is computed and written next to
  each of the 11 rows.
**3.2 `WHERE` runs before the window (task 2).**
 
```sql
SELECT di.id AS id,
       di.total AS total,
       sum(di.total) OVER () AS all_total,
       count(*) OVER () AS cnt
FROM delivery_items AS di
WHERE di.site_id = 2
ORDER BY di.id;
```
 
Run on the live database: 2 rows, `delivery_items.id` 10 and 11, `all_total` 481.50 and
`cnt` 2 in both.
 
Items, all three right on the first send:
 
1. Rows of the whole query: 2.
2. `cnt` in the row `id` = 10: 2.
3. `all_total` in the row `id` = 10: 481.50, not 18390.00.
- The rows a window function sees are the rows left after `WHERE` (from the
  documentation, by memory; the page was not opened). The nine rows of other sites do
  not enter `sum` or `count`.
---
 
## 4. Step 2: PARTITION BY and the named window
 
Tasks 3 and 4. The student wrote the query in both.
 
**4.1 `PARTITION BY` against `GROUP BY` (task 3).** Written by the student, right on the
first send, run on the live database:
 
```sql
SELECT di.id AS id,
       di.site_id AS site_id,
       di.total AS total,
       sum(di.total) OVER (PARTITION BY di.site_id) AS site_total
FROM delivery_items AS di
ORDER BY di.id;
```
 
Result: 11 rows; `site_total` 14404.50 for rows 1 to 6 (site 1), 3504.00 for rows 7 to 9
(site 3), 481.50 for rows 10 and 11 (site 2).
 
Items:
 
1. The query itself, right.
2. Rows of `SELECT di.site_id AS site_id, sum(di.total) AS site_total FROM
   delivery_items AS di GROUP BY di.site_id ORDER BY di.site_id;`: 3, right.
3. The word that keeps the rows from collapsing in the student's query: `OVER`, right.
The two queries give the same three sums. `GROUP BY` keeps one row for each different
`delivery_items.site_id` (3 rows). `OVER (PARTITION BY di.site_id)` computes the same sum
and writes it next to each of the 11 rows.
 
**4.2 A named window (task 4).** Written by the student, right on the first send, run on
the live database:
 
```sql
SELECT di.id AS id,
       di.site_id AS site_id,
       di.total AS total,
       sum(di.total) OVER w AS site_total,
       count(*) OVER w AS site_rows
FROM delivery_items AS di
WINDOW w AS (PARTITION BY di.site_id)
ORDER BY di.id;
```
 
Result: 11 rows; `site_rows` 6 for site 1, 3 for site 3, 2 for site 2.
 
Items:
 
1. The query itself, right.
2. With `WHERE di.total > 1000` added between `FROM` and `WINDOW`: `site_rows` in the row
   `id` = 7 is 1, right. Run on the live database: 5 rows (`id` 1, 3, 4, 6, 7);
   `site_rows` 4 for site 1 (`site_total` 13842.50) and 1 for site 3 (`site_total`
   2840.00). The rows 8 and 9 of site 3 (408.00 and 256.00) are removed by `WHERE`
   before the window.
- The window is described once in `WINDOW w AS (...)` and called as `OVER w` by both
  functions. The clause stands after `HAVING`, before `ORDER BY` (by memory of the
  documentation, page not opened).
---
 
## 5. Practice
 
- Four tasks, ten items, steps 1 and 2.
- The student wrote the query in tasks 3 and 4, right on the first send in both.
- Questions of the student in this topic: the purpose of window functions, and
  examples of where they are used, without code. Answered in the chat (tutor's own
  suggestions, not from the documentation).
- Tasks 1 to 4 were checked by the tutor on the live database.
- PGExercises: no change since topic 6 (`context_07.md`, 7.4).
---
 
## 6. Open questions
 
1. **No migration history in the remote project** (1.4). Carried from topic 5.
2. **Which revision is in force.** Item 8 of this topic adds a third query
   (`row_number() OVER (PARTITION BY number ORDER BY revision DESC)`). The choice is
   the student's. Carried.
3. **Plan against catalogue price** needs the unit conversion tables. Carried.
4. **`INSERT ... SELECT` with a NULL natural key in the source** is not tested.
   Carried.
5. **Functional dependence in `GROUP BY`** (7.2.3) is not tested. Carried.
6. **`ANY` and `ALL` with NULL on a table** is not tested. Carried.
7. **Debts from topic 4, untouched:** no `CHECK` on the dates of `sites`; delivery
   line 7 is dated before the start of its site; no `from_unit_id <>
   materials.unit_id` rule in `material_unit_conversions`.
8. **`schema-design.md`, doubled marker** in the "Deferred to Block 2" list
   (`- - **Estimate versioning, remainder**`), and the indented paragraph below it.
   Not corrected; the student decides.
9. **Section numbers and summaries of topic 7 are unchecked.** Pages of version 17 for
   3.5, 4.2.8, 9.22 and 7.2.5 were not opened; the summaries in the tasks are from
   memory.
10. **PGExercises** Aggregates 11 to 22: those with window functions (15 to 20 and part
    of 22) are for after this topic. The decision is the student's.
---
 
## 7. How the tutoring should run
 
Carried from topic 4:
 
- One question at a time. The question itself is one or two lines, and the data
  needed to answer it is in the same message.
- Every value in the data is named `table.column`. Each column header says what it
  holds: a value, a reference to another table's column, or a count.
- One documentation link plus two or three lines summarising it - no more. The
  summary repeats what the section says and contains no inferences; inferences are
  the student's job.
- Only terms that appear in the official documentation. Anything else is flagged as
  such.
- Tasks name the file, table and line explicitly. No "as above", "in the same
  style".
- Nothing outside the current topic, and nothing about constructions the query does
  not contain.
- Wrong answer: do not give the right one, do not explain - ask a narrowing
  question against the student's own data, until he answers or asks for the answer.
- Right answer: one word plus one sentence of why, then the next question.
- Seed formatting and comment wording are the tutor's job; the student supplies the
  content - why the data is what it is, in his own words.
- The mistakes log is kept silently and shown only in the topic summary.
Added in topic 5:
 
- Repository files are written by the tutor, only when asked. At the end of each
  major step the tutor asks whether to record it.
- No ranges or abbreviations in data: every value written out. Nothing that can be
  read two ways - `1-4` was read as either "1, 2, 3, 4" or "1 and 4".
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
- A phrase that names a kind of answer - "what the number is made up of",
  "check from the other side" - is defined in the same message: what is counted and
  into how many summands, or the row count of which table the number must match.
  Without it the student cannot tell what to write.
- One item holds one question. A number and a reason, two factors, or values and a
  comparison are separate items.
Added in topic 6 (from `context_07.md`):
 
- One tutor question, one student answer. Several questions are allowed only in the
  first message of a chat.
- As few messages as possible: no long openings, no repeated conditions, no
  "shall we continue" where the answer is clear. After a right answer, the next
  question at once.
- The data needed for an answer includes the constraints (`NOT NULL`, `PRIMARY KEY`,
  `CHECK`) when the answer depends on them.
- Every task has one documentation link with an address and two or three lines of
  summary. An anchor inside a page is not given until it is confirmed. A section
  number or a page the tutor did not open is marked unchecked.
- A term the student may not know is defined in the message where it first appears.
- An item must not state half of its own answer. If there are two variants, the
  question is "a number or the word error".
- If the student calls a question ambiguous, it is rewritten, and the case is
  recorded as a tutor error (T), not a student error (E, U).
- After two wrong answers in a row on the same question, show the rule from the
  documentation instead of a third narrowing question.
- Traps (NULL, equal values, the default frame) are put into tasks and not named in
  advance. If the student asks why a task was given, explain on other examples, not
  on the data of the task.
- A reference to a rule of an earlier sheet names every rule needed for the case, not
  only one of them.
Added in this topic: the student writes the window queries himself in items 2, 4 and
8 of the plan and predicts the result of a given query in the others.
 
Superseded: the line of `notes_06.md` that tutor errors are not written in the
repository files. Following `context_07.md`, section 5, the log in `mistakes_07.md`
has the parts E, U and T.
