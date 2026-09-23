# Mistakes — Topic 4, JOIN
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors, because several of them cost
more time in this topic than the student's.
 
No records were kept during the session; this file was reconstructed from the chat
at the end of the topic. Reconstruction is weaker evidence than a live log — some
entries are certainly missing.
 
---
 
## E — execution (12)
 
| # | What happened | Note |
|---|---|---|
| E1 | Four migration files stamped `202610…` / `202611…` instead of `202609…`: month and day transposed | Still unfixed, see notes_04 open question 1 |
| E2 | File named `…_create_suppliers_sites.sql.sql`, double extension | Still unfixed |
| E3 | Dependency list for the seven tables had eight entries: `deliveries` written twice, verbatim, in consecutive positions | Found and fixed by the student after being told the count was wrong |
| E4 | "`1` имеет идентификатор 8" — meant the unit `l` | Prose only, correct in the SQL |
| E5 | "суppliers.id = 9" counted in a table that has eight rows | |
| E6 | Row count asked for and not given | Recurred: INNER JOIN of `estimate_items`, three-table join, task 1 step 1, task 3, task 4 |
| E7 | Sort order required by the task and omitted from the query | Task 2 |
| E8 | Column required by the task and omitted from the select list | Task 1 step 2, `s.name` |
| E9 | Expected result list required by the task and not sent | Task 3, twice |
| E10 | "такое ощущение, что 0 строк" — a guess offered instead of checking three conditions against three rows | Self-join question |
| E11 | `NULLS FIRST` proposed as the fix for interleaved delivery notes, without checking that neither sort column contains NULL | |
| E12 | `d1.id <> d2.id AND d1.id >= d2.id` where `d1.id > d2.id` was asked for | Result correct, expression redundant |
 
**Pattern.** E6–E9 are the same failure as topic 3's "incomplete answers", now the
fourth topic running: the part of the task that is a sentence rather than a code
block gets dropped. Eight of twelve execution entries are of that kind.
 
---
 
## U — understanding (6)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | `estimate_id` said to be `NOT NULL` "because it is part of the composite key" | Student reclassified it as a badly worded inference, not a claim; the real cause, the explicit `NOT NULL`, was then stated correctly |
| U2 | `deliveries.supplier_id` read as a *count* of rows rather than a reference to `suppliers.id` | Caused by an ambiguous data table from the tutor (T5); rule now: every column header says whether it holds a value, a reference, or a count |
| U3 | Direction of an outer join described backwards: "left join присоединяет `materials` к `supplier_materials`" | Corrected on the follow-up question; the result had been right |
| U4 | `NOT NULL` on `materials.id` given as the reason a delivery line always finds its material | Real reason: the foreign key plus `NOT NULL` on `delivery_items.material_id`. Guarantees on the referenced side do not constrain the referencing side |
| U5 | `FULL OUTER JOIN` counted as 6 rows — groups 1 and 2 only, group 3 omitted | Closed after listing the three groups row by row |
| U6 | An alias assumed to rename columns as well (`di.d_id`) | Closed with the `people AS mother` example |
 
**Pattern.** U3, U4 and U5 are all "correct result, wrong mechanism" — the same
shape as topic 3's first third. In every case the answer was reached by analogy and
the mechanism only appeared when a single row was checked by hand.
 
---
 
## T — tutor (7)
 
| # | What was wrong |
|---|---|
| T1 | `MATCH SIMPLE` introduced as the content of section 5.5.5, where the term does not appear; it is on the `CREATE TABLE` page. Also irrelevant here — every foreign key in this schema is single-column |
| T2 | Seed specification gave four rows for `unit_conversions`, contradicting `schema-design.md`, which stores one direction per pair |
| T3 | Question 1 written in jargon ("сметы без строк", "позиции без привязки"), where "строка" meant both a row and an estimate line |
| T4 | Question 1b asked about `PRIMARY KEY` versus `UNIQUE` — topic 2 material, not topic 4. Withdrawn at the student's request |
| T5 | Data table mixed real columns with a count under one caption, which produced U2 |
| T6 | A two-table query introduced with a note about joining three tables |
| T7 | "Прайс" used for `supplier_materials`; the word appears nowhere in the schema |
 
**Pattern.** T1, T5, T6, T7 are the same failure: material that was not asked for,
or not checked against the source, added around the question. Roughly a third of
the session's messages went to clearing it up rather than to JOIN.
 
---
 
## Metric
 
| Metric | Topic 2 | Topic 3 | Topic 4 |
|---|---|---|---|
| Execution discipline | 4/10 | 3/10 | 4/10 |
| Complete answers | — | weak | weak, no change |
| Understanding | — | — | 7/10 |
 
Execution: 12 entries, but of a different kind than in topic 3. There were no
wrong identifiers, no wrong operators, no misread predicates in the SQL itself —
every `INSERT` of the seven tables was accepted on the first send, 59 rows with
hand-written foreign keys and no error. The failures moved into the prose part of
the answers. That is why the number moves up one point and not further.
 
Understanding: six entries, all closed within one or two follow-up questions, none
needing the answer to be given.
