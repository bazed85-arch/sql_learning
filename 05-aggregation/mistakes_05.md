# Mistakes — Topic 5, GROUP BY, HAVING, aggregate functions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors.
 
Records were kept during the session and written at the end of each major step.
This file covers steps 1 to 9, the first twenty tasks.
 
---
 
## E — execution (30)
 
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
| E22 | Task 17, item 1 — asked for the word and the clause; the word (`estimate_total`) given, the clause not named | The student called the question ambiguous (T18). Closed after the rewritten question: `HAVING` |
| E23 | Task 19, item 1 — rows after both joins and "из каких частей складывается число" — the number 13 sent, the parts not | The student asked what "частей" means (T22). Closed after the rewritten question: 4, 1, 2, 3, 1, 1, 1 |
| E24 | Task 19, item 2 — the number of result rows and the source of the number asked for; a table of group sizes (5, 2, 3, 1, 1, 1) sent instead, right but not what was asked | The number 6 came on the repeat, the table `sites` after one question. The follow-up "why can `LEFT OUTER JOIN` not lower it" (T24) was answered: "присваивает ей значение null" |
| E25 | Task 19, item 3 — groups 4, 5, 6: `e_rows`, `approved_estimates` and `item_rows` written as 1, 1, 1 instead of 0, 0, 0 | Closed with one question on group 4. The same distinction as in task 15 (E15): `count(*)` counts the added row, `count(column)` does not |
| E26 | Task 19, item 3 — group 1: `e_rows` 2 and `approved_estimates` 1 instead of 5 and 2; groups 2 and 3: `e_rows` 1 and 1 instead of 2 and 3 | One narrowing question on group 1: the student answered 4, the count for `estimate_items.id`, another column, then 0 NULLs among the five `estimates.id`. After that groups 1, 2 and 3 were right |
| E27 | Task 19, item 3 — `planned_total` of groups 4, 5, 6 written as 0 instead of NULL | Closed at once with a pointer to estimate 5 of task 4. Third time on the rule that an aggregate over no non-NULL values is NULL (U1, U7) |
| E28 | Task 20, item 2 — "по какому правилу из раздела 7.2.1.1" — the rule never named by the student | The tutor quoted the rule at a narrowing step, and the item was closed with the number 30 alone (T26) |
| E29 | Task 20, item 3 — two factors asked for (`sum(ei.total)` and `sum(di.total)`); only the first, 6, sent | The second factor, 5, after one narrowing question (T26) |
| E30 | Task 20, item 4 — the values 30 and 6 sent; the second half, what the comparison shows, not sent | The student: "не понимаю вопроса" (T27). After the rewrite: "не равны", and he asked the tutor to formulate what that says. The formulation is the tutor's |
 
**Pattern.** E1, E2, E3, E6, E9, E12, E13 and E22 are the same failure as topics 3
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
 
E23, E24, E28 and E30 are the same failure again: the half of an item that is
prose is dropped. In E23 and E30 the wording of the question was at fault as well
(T22, T27). E25 and E27 are regressions in one table, the six rows of task 19: the
added row counted by `count(column)` (the distinction of task 15) and `sum` over
NULL given as 0 (the rule of task 4). Each closed with one question. In E26 the
count of group 1 was first given for another column, a quantity other than the one
asked, as in E5, E7 and E11.
 
---
 
## U — understanding (9)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 4, estimate 5: `sum` gives NULL "если строки нет" — while task 3 had just shown the group has one row; then `ei.total` in that row given as 0 | "If `ei.total` were 0, what would `sum` give?" → 0. "The result is NULL, so what is the value?" → NULL. Chain assembled: `LEFT OUTER JOIN` adds a NULL row → `sum` skips NULL → no inputs → NULL |
| U2 | Task 7, group `estimate_id` = 1: the value of `ei.material_id` in the group row given as 4, with no reason | Narrowing question on the four values 1, 5, 8, 4; the term "group row" had to be defined (T7). After the student said "any", the tutor stated the documentation's reason: more than one possible value |
| U3 | Task 8, item 5: `count(expression)` said to count "all rows" when asked why it gives 12 on a `NOT NULL` column | Compared with task 1, same twelve rows, `count(description)` = 0. The student then gave the rule: rows where the expression is not NULL |
| U4 | Task 11, item 5: the sum differs from 15080.00 because "all calculations are done after the join"; then "for each `estimate_items` row there is its own `supplier_materials` row" | Neither explains 7 rows instead of 4, and "its own row" contradicts the student's own item 1 (2, 2, 1, 2). Closed after narrowing questions, when the student quoted the rule from 7.2.1.1: a row for each matching row of T2 |
| U5 | Task 16: `count` described as "складывает количество строк по признаку suppliers.id у которых оно равно" — the work of `GROUP BY` given to `count` | The student could not recall the rule. The tutor quoted 4.2.7: the aggregate is called for rows where the expression is not NULL. Then per group: in how many rows of the group is `deliveries.id` not NULL → 3 |
| U6 | Task 16, item 4: delivery 1 stands in two rows "потому что она соединяется по заданному условию и нет ограничения distinct" — `DISTINCT` named as the reason for the join's row count | `DISTINCT` works inside `count(DISTINCT …)`, not in the join. Closed with: how many rows of `delivery_items` meet the condition for delivery 1 → 2; the rule of 7.2.1.1 then applied |
| U7 | Task 18, item 7: `max(revision) + 1` for a number with no rows in `estimates` given as 1. The student: "правило не помню. предположу что 1" | The same rule as `sum` of an empty group in task 4 (U1): an aggregate over no rows is NULL. Closed with the estimate 5 example from task 4: `sum` → NULL. Then `max` of no rows → NULL, and `NULL + 1` → NULL. The row count (1) was right |
| U8 | Task 19, item 4: `e_rows` 5 against `approved_estimates` 2 explained by "у нее несколько ревизий, и distinct убирая совпадения оставляет только одну необходимую ревизию" | Estimates 1 and 7 are different numbers (`EST-2025-001`, `EST-2025-014`); the tutor said so, and that `DISTINCT` keeps every different value (T25). Then four questions on the values 1, 1, 1, 1, 7: rows with `estimates.id` = 1 → 4; `count(e.id)` counts the rows where it is not NULL, repeats included → 5; `count(DISTINCT e.id)` counts the different values → "1 и 7" → 2 |
| U9 | Task 20, item 2: rows with `s.id` = 1 after the fourth part given as "6 строк и одна будет null"; then 5 for the number of `delivery_items` rows that meet the condition for one row of T1 (6 expected); then 11 = 5 + 6 as the total | The rule of 7.2.1.1 applied as an addition. The tutor wrote out one row of T1, which gave 6; then stated that each of the five rows meets the same six (T28); the total was still 11. Closed with: rows 1 to 4 give 6 each → 30. The rule itself was quoted by the tutor from the student's answer in task 11 |
 
**Pattern.** U4 and U6 are the same mechanism, rows multiplied by a join,
explained wrongly twice, in task 11 and in task 16. Both times the numbers were
right when asked directly (2, 2, 1, 2 in task 11; 2 rows of `delivery_items` for
delivery 1 in task 16). U5 is a separate gap: `count` and `GROUP BY` confused.
U1 and U7 are the same rule, an aggregate over no rows is NULL: explained in task
4, not recalled in task 18 for `max`.
 
U9 is the third time the rule of 7.2.1.1 about multiplied rows is explained wrongly
(U4, U6, U9). Each time the single numbers were right when asked one row at a time
(5 and 6 in task 20). U8 is a reason given in terms of the subject area instead of
the mechanism, as in E14 and E15, together with a wrong description of `DISTINCT`
that task 16 (E21) had already closed.
 
---
 
## T — tutor (28)
 
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
| T11 | Task 14, follow-up to E13: "перестаёт участвовать в соединении до его выполнения или после?" — "до" and "после" with no point named, "соединение" for either the whole `LEFT OUTER JOIN` or one pair of rows. The student answered the wrong reading and asked for an unambiguous question. Rule recorded in notes_05, section 13 |
| T12 | Task 15, item 5: "сумма исключённых и оставленных групп" — the student read it as two sums |
| T13 | Task 16, item 1: a row count over three tables and two joins, with no scaffold. The student asked whether he must count it in his head. The scaffold (steps by the first join, then the second) was added |
| T14 | Task 16, item 6: sums of six numbers asked for, and the sum written as an expression rejected. The student: "это уже арифметика, а не sql". Right. Rule recorded in notes_05, section 13 |
| T15 | Task 16, item 4: the wording "отбрасывает одинаковые строки" corrected to "значения". The student objected that his answer need not match the wording of the documentation. Right: the correction was a nitpick |
| T16 | Task 2 follow-up and notes_05, 2.2: the cause of the single visible column ("the SQL Editor turns each row into an object, the second key overwrites the first") stated as fact. It was an assessment: only the symptom was observed. Marked as an assessment in notes_05 now |
| T17 | Task 4, "Где читать": "таблица 9.62" named from memory. The page of version 17 could not be opened in this session, so the table number is unchecked and may differ. The paragraph itself and its wording are from 9.21 |
| T18 | Task 17, item 1: "какое слово из запроса она называет несуществующим столбцом" — "несуществующий" read as a column absent from the table, or as a label declared in `SELECT` and not visible in `HAVING`. The student called the question ambiguous, correctly. Rewritten as a choice of two clauses |
| T19 | Task 17: the "Кратко" text and the link are for the `SELECT` page of version 17, which could not be opened. The wording came from search results for older versions. Disclosed in the task text, but the summary was not confirmed against the page it points to. Open question 8 in notes_05 |
| T20 | Task 18, item 7 held three questions: the number of rows, the value, and the rule behind the value. Same shape as T9. The student answered the first two and said he did not remember the third |
| T21 | Task 18, before the two rows were inserted: the student was not told that the new rows would change results of the earlier tasks (estimates per site, groups per estimate, status counts). Found while recording the step. Rule added in notes_05, section 13 |
| T22 | Task 19, item 1: "из каких частей складывается число" — the parts of what was not said. The student asked what the word means. The tutor then defined it as a breakdown of the 13 rows by the row of the first join |
| T23 | Task 20, item 1: the same phrase, "из каких частей складывается число", and "проверка с другой стороны" asked again with no definition, after T22. The student: "что значит из каких частей, задавай определения без двусмысленностей, запомни это". Rule added in notes_05, section 13 |
| T24 | Task 19, item 2 held three questions (the number of rows, the column, the source of the number), and a fourth was added in the follow-up: why `LEFT OUTER JOIN` cannot lower the number. The item text did not contain it. Same as T10 |
| T25 | Task 19, item 4: in reply to a wrong explanation the tutor stated what `DISTINCT` does ("оставляет все различные значения") instead of asking a narrowing question only. The correction of the data (estimates 1 and 7 are different numbers) was a fact about the data and stands; the statement about `DISTINCT` was the answer |
| T26 | Task 20, items 2, 3 and 4 each held two questions: rows and rule; two factors; values and comparison. The second part was dropped three times (E28, E29, E30). Same shape as T9 and T20. Rule added in notes_05, section 13 |
| T27 | Task 20, item 4: "какое сравнение этих двух значений показывает, что строки размножились? Запиши его выражением из двух значений" — "сравнение" and "выражение" do not say what to write. The student: "не понимаю вопроса". Rewritten as: are the two values equal |
| T28 | Task 20, item 2: after the right answer 6 the tutor wrote that each of the five rows of T1 meets the same six rows of `delivery_items`, which left only the multiplication to do. The next answer was still 11 (U9). A right answer gets one sentence; this one gave away the next step |
 
**Pattern.** T2 and T4 are "not checked against a source already at hand" — the
section 6 comment, and experiment 3.2 of topic 4. T3, T7, T11, T12 and T18 are
the same failure: a notation, a term or a phrase that can be read two ways. T8
and T9 are task design: a task whose point the student could not see, and an
item with two questions in it. T10 added a requirement the item did not contain.
T3, T5 and T11 cost the most turns.
 
T13, T14 and T15 are about how much an item demands: more than the single step it
tests (T13, T14), or a wording beyond the point (T15). T16 and T17 are statements
made with more certainty than the evidence gave: a cause not checked, a table
number not checked. T19 is the same kind, with the gap disclosed. T20 repeats
T9; T21 is a consequence of a data change that was not announced.
 
T22 and T23 are one failure: a phrase that names a kind of answer, used without a
definition, and used a second time after the student had asked what it meant. T24,
T26 and T27 are item design (T9, T10, T20): more than one question in an item, a
question added in a follow-up, a wording that does not say what to write. T25 and
T28 break the rule of notes_05, section 13: a wrong answer gets a narrowing
question only, a right answer gets one sentence.
 
---
 
## Metric
 
| Metric | Topic 2 | Topic 3 | Topic 4 | Topic 5 |
|---|---|---|---|---|
| Execution discipline | 4/10 | 3/10 | 4/10 | 4/10 |
| Complete answers | — | weak | weak, no change | 4/10, weak, no change |
| Understanding | — | — | 7/10 | 7/10 |
| Recording discipline | — | — | — | 7/10 |
 
The topic 5 scores are the tutor's assessment from this log, given after the last
task and accepted by the student.
 
Execution: 30 entries over twenty tasks. SQL itself had no errors — both
written queries, tasks 4 and 5, were accepted on the first send; in tasks 19 and 20
the queries were given. As in topic 4, the failures are in the prose part of the
answers, and in filling a table of several groups.
 
Understanding: nine entries, all closed within four follow-up questions or fewer.
U2 and U5 needed the tutor to define a term or to quote the rule; U9 needed the
tutor to quote the rule and to state that each row meets the same six rows. U1,
U3, U4, U6 and U7 closed without the answer being given; U8 closed after the tutor
had stated what `DISTINCT` does (T25). Tasks 10, 12 and 13 were answered
completely and correctly on the first send, and so were items 1 to 6 of task 18.
In task 19 the seven rows after the first join (item 1, first half) and the clause
in item 5 were right on the first send; in task 20 the number 14 was.
 
Recording discipline: all nine steps were recorded after the student's yes, and the
files were re-checked at his request. Three repository items were left to the end of
the topic by his decision: the rename of five migrations, the four drifts in
`schema-design.md`, and the two `estimates` rows missing from `seed.sql`.
