# Mistakes — Topic 6, subqueries and common table expressions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors.
 
Records were kept during the session and written at the end of each major step.
This file covers steps 1 to 3, the first eight tasks (37 items).
 
---
 
## E — execution (8)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 2 — why the subquery returns one row and not 11 — the premise was given back: «подзапрос выводит только одну строку и один столбец» | Closed with two narrowing questions: how many values `avg` gives from the 11 values of `delivery_items.total` (1), how many groups the rows form with no `GROUP BY` (1). Same shape as E20 of topic 5 |
| E2 | Task 1, item 5 — the number of rows of the changed subquery asked; the value given («по идее null») | Closed with one repeat of the question: 1. A quantity other than the one asked, as E5, E7 and E11 of topic 5 |
| E3 | Task 4, item 2 — the subquery written with the table name `supplier_materials` after the alias `sm` was set | The rule is in rules_04, 9.3. The student named `sm` when asked, and then closed the item |
| E4 | Task 4, item 2 — the test for NOT NULL written as `NOT NULL`, then as `NOT IS NULL` | «не помню». The form `IS NULL` is in rules_04, section 10; the inverse is not written there (T6). Closed after one question: where to put `NOT` inside `IS NULL` → `IS NOT NULL` |
| E5 | Task 4, item 4 — the ids left out of the result sent as «1,34,7» | A typing slip. Sent again as 1, 3, 4, 7 after the tutor pointed out that 34 is not a `materials.id` |
| E6 | Task 5, item 1 — the number of rows of the subquery for `suppliers.id` = 1 given as 1 (two: `deliveries.id` 1 and 5) | The ids asked for as a narrowing step came as «2», then 1, 5. A quantity other than the one asked, as E2 |
| E7 | Task 6, item 5 — why `NOT IN` gives 0 rows and `NOT EXISTS` gives 10 — «из-за NULL и разнице как вычисляется подзапрос» | General words, no values. Closed with the two values for `materials.id` = 5 (NULL and true), and then with a check of the claim «any NULL gives NULL» on row 1 (U6) |
| E8 | Task 7, item 3 — a reason asked for; the clause «WHERE s.id NOT IN» sent | Closed with one question: the number of NULL among the 11 values of `delivery_items.site_id` (0). The last answer «екгу» is «true» typed in the Russian layout, accepted |
 
**Pattern.** E1, E2, E6 and E7 are the failures already in topic 5: the reason
restated as the premise (E1), a value or a list given instead of the quantity asked
(E2, E6), a result without the value and the reason (E7). E3 and E4 are in the one
subquery the student wrote; the first is a known rule, the second a form of syntax
he did not remember. All other items of tasks 3 to 8 were answered correctly on the
first send, among them the checks from the other side of tasks 5, 6 and 8 and the
number of rows of tasks 5 (7), 6 (10) and 8 (0 and 5).
 
---
 
## U — understanding (8)
 
| # | What was wrong | How it was closed |
|---|---|---|
| U1 | Task 4, item 1: `NOT IN` over a subquery with NULL — the number of rows given as 9 (right: 0); then false for `materials.id` = 2, then 3 rows, then `materials.id` 5, 8, 10 counted | After a long chain of narrowing questions the student asked to have the rule explained again. The tutor stated the three results of `NOT IN` (equal found, no equal and NULL present, no equal and no NULL); then 0 was answered. Here the tutor stated the rule (T4) |
| U2 | Task 4: «id 5» given when asked what `materials.article_no` of material 5 is compared with — only with the rows of `supplier_materials` where `supplier_materials.material_id` = 5. «true!!! b500s-12 у нее id 5» | The query has no condition between `m.id` and `sm.material_id`. Closed with the number of rows of the subquery (13), of NULL among them (7), and the table of the 13 values written by the tutor (T10). The student: «это какой-то бред» (T7) |
| U3 | Task 4: the case «found only unequal rows» named for `materials.id` 5 and for 8, with 7 NULL values among the 13 | Closed with: how many of the 13 are unequal to GRAV-1220 (6), and the 7 others are NULL → the case «no equal, NULL present». The student had said «нет» to «all 13 are unequal» just before |
| U4 | Task 5, item 3: the number of rows of `EXISTS` given as 9 and then «2 раза» for supplier 3 — the number of rows of `deliveries`, not one result row per row of `suppliers`. Later the student read the 2 rows of the subquery for supplier 1 as a contradiction with the 7 of the result | The tutor quoted the documentation (version 8): at most one output row for each row of the outer table. Then 7 was answered, and the check, supplier 8 left out |
| U5 | Task 6, item 2: `NOT EXISTS` for `materials.id` = 3 given as NULL | `EXISTS` over no rows is false, one question; `NOT` of false is true. The documentation says every form in that section gives true or false |
| U6 | Task 6, after item 5: «если хоть одно NULL, то сразу NULL» — then, for `materials.id` = 1 under `NOT IN`, the answer NULL and the case «no equal, NULL present» | An equal value, CEM-II-425, is among the 13: the result is false. NULL decides only when no equal value is found. Closed with three questions, the last one the three results written again by the tutor |
| U7 | Task 8, item 2: `NOT IN` for `suppliers.id` = 2 given as false (right: NULL) | The tutor said false needs an equal value; the student: none among B38123456 and NULL; so NULL. Same family as U1 and U6: NULL in the subquery |
| U8 | Task 8, item 1: `s2.id IN (1, 3)` read as «промежуток ID» | A list of two values, 1 and 3; 2 is not in it. The student then answered item 1 correctly. The rule of no ranges in rules and notes concerned the data given by the tutor, not the student's reading of SQL |
 
**Pattern.** U1, U2, U3, U6 and U7 are one gap: a NULL among the values of a
subquery under `NOT IN`. The student first took it as «false» or as «NULL decides at
once», the left value NULL as a plain value, and the comparison of the left value
with all rows as a comparison with the rows of one material. By task 8 the three
results were applied correctly, with one more wrong first answer (U7). U4 is the
topic-5 gap of rows repeated by a join (U4, U6, U9 there) in a new place: `EXISTS`
gives one result per outer row. U5 is a regression of the same family: `NOT` over a
result that is true or false only.
 
---
 
## T — tutor (10)
 
| # | What was wrong |
|---|---|
| T1 | Section numbers of the documentation stated without a check against version 17: 4.2.11, 7.2.1.3, 7.2.1.5, 7.8.3, 7.8.4 from memory; 9.24 inferred from versions 15, 16 and 18. The pages of version 17 could not be fetched. Disclosed in the plan and in the text of the tasks; the anchor of the link in task 1 (`SQL-SCALAR-SUBQUERIES`) was not confirmed, a quotation seen in a mailing-list message gives `SQL-SYNTAX-SCALAR-SUBQUERIES`. The same for the sections of tasks 3 to 8: version 16 numbers given, 17 not seen |
| T2 | First message of the chat: question 3, whether the `seed.sql` in the repository has the two rows of `estimates`, was asked, although `context_06.md`, section 1, says the student attaches the file from the repository and the attached file had the rows. After «посмотри по скриншоту» the tutor asked for another screenshot; the student had to say that the file sent was the repository one. Three messages |
| T3 | `notes_06.md`, first version of the section on how the tutoring should run (section 6 then, section 8 now): the rules of `notes_05.md`, section 13, were cut down to a shorter list instead of carried over whole. Left out: the `AS` label on every aggregate, the student answers in his own words, the data repeated on request, an item asks only what the task text says, seed formatting is the tutor's job, tasks name the file, table and line. The student asked whether the files match the structure of topic 5; the section was then rewritten in full |
| T4 | Task 4, «Кратко»: only the condition of true (only unequal rows found) was given, with no definition of «неравные строки» and without the results false and NULL. The student could not apply it («что значит неравные строки подзапроса???»); the three results were stated only after a long chain of narrowing questions and his request. Same failure as T22 and T23 of topic 5 |
| T5 | Task 4, item 2 and its follow-up held two questions: the name allowed in the subquery and a reason from rules_04. Only the first was answered. Same shape as T9, T20 and T26 of topic 5 |
| T6 | Task 4, wrong-answer questions: «с чем сравнивается `article_no` материала 5 — только со строками `material_id` = 5 или со всеми 13» was leading and gave the wrong half a place to be chosen; the question about the inverse of `IS NULL` «по аналогии» asked for a form that is not in rules_04 («вот все что написано») |
| T7 | Task 4 took about twenty questions for the item «how many rows»: the rule of narrowing questions only was applied three times after wrong answers on the same point. The student: «это какой-то бред», «ты меня путаешь», «каждое сообщение стоит токенов». The rule from his request: after two wrong answers in a row show the rule of the documentation instead of a third narrowing question |
| T8 | Task 4: the second result of `NOT IN` was worded «равных нет, но есть строка с NULL» (NULL in the subquery), and the answer «3» was accepted for `materials.id` = 3, where the subquery has 6 values without NULL and NULL stands on the left. The wording and the accepted answer disagreed; the student found it. The rule was rewritten in full without numbers of cases |
| T9 | Task 5: `SELECT 1` used without a definition; the student: «что значит SELECT 1» |
| T10 | Task 6, check of the claim «any NULL gives NULL» on `materials.id` = 1: the question gave no data, the student: «таблицы перед глазами нет». The rule that data is repeated on request was kept, but the data belonged in the question |
 
**Pattern.** T1 is the kind already recorded as T17 and T19 of topic 5: a source
named with more certainty than was checked, disclosed in the text. T2 is a question
not checked against a file at hand (T2 and T4 of topic 5); T3 is the same shape, the
student found it. T4, T9 and T10 are about wording and data the student could not see
or could not use: a rule without its definition and without the other two results
(T4), a term not defined (T9, as T22 and T23 of topic 5), data not in the question
(T10). T5 repeats T9, T20 and T26 of topic 5: two questions in an item. T6 and T7
are the cost of the narrowing rule: a leading question, and a chain too long on one
point. T8 is an inconsistency between the rule as worded and an answer the tutor
accepted.
 
---
 
## Metric
 
To be given at the end of the topic, as in topic 5: execution discipline, complete
answers, understanding, recording discipline, out of 10 each.
