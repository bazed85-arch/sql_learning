# Mistakes — Topic 5, GROUP BY, HAVING, aggregate functions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors.
 
Records were kept during the session and written at the end of each major step.
This file covers steps 1 to 6, the first sixteen tasks.
 
---
 
## E — execution (21)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 4 — the rule from 4.2.7 behind each number — not sent | Sent after the task was returned |
| E2 | Task 2, item 2 — pairs `estimate_id` — `count(*)` asked for, only the `estimate_id` list sent | Sent after return |
| E3 | Task 2, item 3 — result given ("нет"), mechanism not | Sent after return |
| E4 | Task 3, item 1 — "5-0(NULL)" written for estimate 5, while the total 13 counts it as 1 row | Notation contradicts own sum |
| E5 | Task 3, item 5 — number of rows (6) given instead of the sum of values (13 and 12) | Closed with one question |
| E6 | Task 4, item 5 — "совпадают" without either number | Sent after return: 41443 and 41443 |
| E7 | Task 6, item 5 — "совпасть не должны", while own numbers were 40580 and 40580 | Closed with one question |
| E8 | Task 5, item 4 — "не входит в группу" for a group that exists and is excluded from the result | Wording only, the mechanism was right. Minor; the tutor's correction of it was a nitpick of the T15 kind |
| E9 | Task 7, item 4 — number of rows in group `estimate_id` = 4 asked for, not given | Sent after return: 1 |
| E10 | Task 9, item 2 — `avg_days` written as "2", while item 3 gave 2,42 | Closed with one question; the student named the cause himself: `avg` of `integer` is `numeric` |
| E11 | Task 11, item 1 — number of `supplier_materials` rows per `estimate_items.id` asked for, the `supplier_id` values listed instead | Closed with one repeat of the question: 2, 2, 1, 2 |
| E12 | Task 11, item 5 — second half, the comparison of two values from the result that shows the rows were multiplied, not sent | Sent after return: `count(*)` ≠ `count(DISTINCT ei.id)` (T9) |
| E13 | Task 14, item 3, query A — the step at which the rejected estimate stops taking part was not named ("ему присваивается значение NULL") | Closed after two narrowing questions: the pair fails the `ON` condition, so no pair is formed (T10, T11) |
| E14 | Task 15, item 3 — reason given in terms of the subject area ("нет смет утверждённых"), not the mechanism: `e.id` is NULL, `count` skips NULL | Sent after return |
| E15 | Task 15, item 4 — result given ("ни одной"), reason given for groups 4, 5, 6 only; the value of `count(*)` in each of the six groups not named | Closed with two questions: a group cannot hold 0 rows; `count(*)` = 1 in each |
| E16 | Task 16, item 1 — rows after both `LEFT OUTER JOIN`s asked for; the student answered for the first join only (10) and said so | Right as a step, not the quantity asked. Closed after a check of the 10 and the second join: 13 |
| E17 | Task 16, item 2 — number of result rows and the check asked for; a full table of results sent instead | Number and check sent after return: 8, groups by `suppliers.id` |
| E18 | Task 16, item 3 — table of eight groups: `d_rows` and `deliveries` wrong in groups 1, 3 and 4 (2 and 1, 2 and 1, 1 and 1 instead of 3 and 2, 3 and 2, 2 and 1); `item_rows` 2 and `delivered_total` 2762 in group 1 instead of 3 and 3170.00; `delivered_total` of groups 3 and 4 written as expressions, not numbers | Closed group by group; each group answered correctly when asked alone (U5) |
| E19 | Task 16, groups 2 and 8 — `count` given as NULL instead of 0 (`item_rows` of group 2; `d_rows`, `deliveries`, `item_rows` of group 8) | The value 0 for an all-NULL group had been given in task 3, estimate 5. Mechanism known, lost in a larger table |
| E20 | Task 16, item 4 — "это одна поставка" given as the reason why delivery 1 stands in two rows | Restates the premise. Closed with a narrowing question (U6) |
| E21 | Task 16, item 4 — asked what `count(d.id)` and `count(DISTINCT d.id)` count in the group of supplier 1; the answer was the general principle of `DISTINCT`, nothing about `count(d.id)` | Closed with two single-function questions: both answered correctly |
 
**Pattern.** E1, E2, E3, E6, E9, E12 and E13 are the same failure as topics 3
and 4: the part of the task that is prose rather than a number or code gets
dropped. Fifth topic running. E14 and E15 are close to it: the result is right,
the "why" is given at the level of the subject area or for part of the cases.
E5, E7 and E11 are a different failure: the question asked for one quantity and
the answer gave another — a count of rows instead of a sum of values, ids instead
of a count, a comparison with the wrong total. In every case the student's own
numbers were right.
 
E18 and E19 are errors in filling a table of eight groups, not in the single
group checked alone: every one of the eight groups was answered correctly when
asked separately. E19 is a regression: the same value, 0, was given correctly in
task 3.
 
---
 
## U — understanding (6)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 4, estimate 5: `sum` gives NULL "если строки нет" — while task 3 had just shown the group has one row; then `ei.total` in that row given as 0 | "If `ei.total` were 0, what would `sum` give?" → 0. "The result is NULL, so what is the value?" → NULL. Chain assembled: `LEFT OUTER JOIN` adds a NULL row → `sum` skips NULL → no inputs → NULL |
| U2 | Task 7, group `estimate_id` = 1: the value of `ei.material_id` in the group row given as 4, with no reason | Narrowing question on the four values 1, 5, 8, 4; the term "group row" had to be defined (T7). After the student said "any", the tutor stated the documentation's reason: more than one possible value |
| U3 | Task 8, item 5: `count(expression)` said to count "all rows" when asked why it gives 12 on a `NOT NULL` column | Compared with task 1, same twelve rows, `count(description)` = 0. The student then gave the rule: rows where the expression is not NULL |
| U4 | Task 11, item 5: the sum differs from 15080.00 because "all calculations are done after the join"; then "for each `estimate_items` row there is its own `supplier_materials` row" | Neither explains 7 rows instead of 4, and "its own row" contradicts the student's own item 1 (2, 2, 1, 2). Closed after narrowing questions, when the student quoted the rule from 7.2.1.1: a row for each matching row of T2 |
| U5 | Task 16: `count` described as "складывает количество строк по признаку suppliers.id у которых оно равно" — the work of `GROUP BY` given to `count` | The student could not recall the rule. The tutor quoted 4.2.7: the aggregate is called for rows where the expression is not NULL. Then per group: in how many rows of the group is `deliveries.id` not NULL → 3 |
| U6 | Task 16, item 4: delivery 1 stands in two rows "потому что она соединяется по заданному условию и нет ограничения distinct" — `DISTINCT` named as the reason for the join's row count | `DISTINCT` works inside `count(DISTINCT …)`, not in the join. Closed with: how many rows of `delivery_items` meet the condition for delivery 1 → 2; the rule of 7.2.1.1 then applied |
 
**Pattern.** U4 and U6 are the same mechanism, rows multiplied by a join,
explained wrongly twice, in task 11 and in task 16. Both times the numbers were
right when asked directly (2, 2, 1, 2 in task 11; 2 rows of `delivery_items` for
delivery 1 in task 16). U5 is a separate gap: `count` and `GROUP BY` confused.
 
---
 
## T — tutor (17)
 
| # | What was wrong |
|---|---|
| T1 | Asked the student to create `mistakes_05.md` and `notes_05.md` and to write notes in his own words. Repository files are the tutor's job, on request |
| T2 | Compared `schema-design.md` with the revision migration against the "Deferred" section only; missed the comment in section 6 that already answered the question. The same pass missed the drift in `estimates.number`, still shown as `UNIQUE` |
| T3 | Range notation `1–4` in data tables — readable as "1 to 4" or "1 and 4" |
| T4 | Tasks 1 and 3 given with `count(*)` and `count(...)` unlabelled: both output columns named `count`, one lost in the SQL Editor. Topic 4 experiment 3.2 was already in the notes |
| T5 | Task 3, item 5: the origin of sums 13 and 12 pushed over three rounds, down to naming a table. One question would have done |
| T6 | The first message opened with repository issues and question 1 together, instead of asking which to handle first. Question 1 was then repeated in full four times |
| T7 | Task 7: "групповая строка" used with no definition. The student read it as `count(*)`, the same kind of failure as T3 after the rule against it had been agreed |
| T8 | Task 11 given without its purpose. The query is a deliberate trap, but the task read as "compute the estimate total through a join". The student had to ask what the join was for |
| T9 | Task 11, item 5 held two questions: the mechanism, and the comparison that shows it. The second was dropped (E12) |
| T10 | Task 14, item 3: after the first answer the tutor demanded that the student name the table whose columns hold NULL. The item did not ask for it; the student objected, correctly |
| T11 | Task 14, follow-up to E13: "перестаёт участвовать в соединении до его выполнения или после?" — "до" and "после" with no point named, "соединение" for either the whole `LEFT OUTER JOIN` or one pair of rows. The student answered the wrong reading and asked for an unambiguous question. Rule recorded in notes_05, section 10 |
| T12 | Task 15, item 5: "сумма исключённых и оставленных групп" — the student read it as two sums |
| T13 | Task 16, item 1: a row count over three tables and two joins, with no scaffold. The student asked whether he must count it in his head. The scaffold (steps by the first join, then the second) was added |
| T14 | Task 16, item 6: sums of six numbers asked for, and the sum written as an expression rejected. The student: "это уже арифметика, а не sql". Right. Rule recorded in notes_05, section 10 |
| T15 | Task 16, item 4: the wording "отбрасывает одинаковые строки" corrected to "значения". The student objected that his answer need not match the wording of the documentation. Right: the correction was a nitpick |
| T16 | Task 2 follow-up and notes_05, 2.2: the cause of the single visible column ("the SQL Editor turns each row into an object, the second key overwrites the first") stated as fact. It was an assessment: only the symptom was observed. Marked as an assessment in notes_05 now |
| T17 | Task 4, "Где читать": "таблица 9.62" named from memory. The page of version 17 could not be opened in this session, so the table number is unchecked and may differ. The paragraph itself and its wording are from 9.21 |
 
**Pattern.** T2 and T4 are "not checked against a source already at hand" — the
section 6 comment, and experiment 3.2 of topic 4. T3, T7, T11 and T12 are the
same failure: a notation, a term or a phrase that can be read two ways. T8 and T9
are task design: a task whose point the student could not see, and an item with
two questions in it. T10 added a requirement the item did not contain. T3, T5 and
T11 cost the most turns.
 
T13, T14 and T15 are about how much an item demands: more than the single step it
tests (T13, T14), or a wording beyond the point (T15). T16 and T17 are statements
made with more certainty than the evidence gave: a cause not checked, a table
number not checked.
 
---
 
## Metric
 
| Metric | Topic 2 | Topic 3 | Topic 4 | Topic 5, steps 1–6 |
|---|---|---|---|---|
| Execution discipline | 4/10 | 3/10 | 4/10 | scored at the end |
| Complete answers | — | weak | weak, no change | scored at the end |
| Understanding | — | — | 7/10 | scored at the end |
 
Execution: 21 entries over sixteen tasks. SQL itself had no errors — both written
queries, tasks 4 and 5, were accepted on the first send. As in topic 4, the
failures are in the prose part of the answers.
 
Understanding: six entries, all closed within one to four follow-up questions.
U2 and U5 needed the tutor to define a term or to quote the rule; U1, U3, U4 and
U6 closed without the answer being given. Tasks 10, 12 and 13 were answered
completely and correctly on the first send.
