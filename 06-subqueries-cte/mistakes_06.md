# Mistakes — Topic 6, subqueries and common table expressions
 
Kept in two parts, because the two move independently:
 
- **E — execution.** The mechanism was known; something else reached the answer.
  Includes incomplete answers: a question with several parts answered in part.
- **U — understanding.** The mechanism itself was wrong.
A third part, **T**, records the tutor's own errors.
 
Records are kept during the session and written at the end of each major step.
This file covers step 1, the first two tasks (11 items).
 
---
 
## E — execution (2)
 
| # | What happened | Note |
|---|---|---|
| E1 | Task 1, item 2 — why the subquery returns one row and not 11 — the premise was given back: «подзапрос выводит только одну строку и один столбец» | Closed with two narrowing questions: how many values `avg` gives from the 11 values of `delivery_items.total` (1), how many groups the rows form with no `GROUP BY` (1). Same shape as E20 of topic 5 |
| E2 | Task 1, item 5 — the number of rows of the changed subquery asked; the value given («по идее null») | Closed with one repeat of the question: 1. A quantity other than the one asked, as E5, E7 and E11 of topic 5 |
 
**Pattern.** Both entries are the failures already in topic 5: the reason restated as
the premise, and the value given instead of the number of rows. In both the next
question was answered correctly. Items 1, 3, 4, 6, 7 and 8 of task 1 and all three
items of task 2 were right on the first send; in task 2 the prediction named the
reason too («ожидается 1 строка, а их 3»).
 
---
 
## U — understanding (0)
 
No entries so far.
 
---
 
## T — tutor (3)
 
| # | What was wrong |
|---|---|
| T1 | Section numbers of the documentation stated without a check against version 17: 4.2.11, 7.2.1.3, 7.2.1.5, 7.8.3, 7.8.4 from memory; 9.24 inferred from versions 15, 16 and 18. The pages of version 17 could not be fetched. Disclosed in the plan and in the text of task 1 and task 2; the anchor of the link in task 1 (`SQL-SCALAR-SUBQUERIES`) was not confirmed, a quotation seen in a mailing-list message gives `SQL-SYNTAX-SCALAR-SUBQUERIES` |
| T2 | First message of the chat: question 3, whether the `seed.sql` in the repository has the two rows of `estimates`, was asked, although `context_06.md`, section 1, says the student attaches the file from the repository and the attached file had the rows. After «посмотри по скриншоту» the tutor asked for another screenshot; the student had to say that the file sent was the repository one. Three messages |
| T3 | `notes_06.md`, section 6, first version: the rules of `notes_05.md`, section 13, were cut down to a shorter list instead of carried over whole. Left out: the `AS` label on every aggregate, the student answers in his own words, the data repeated on request, an item asks only what the task text says, seed formatting is the tutor's job, tasks name the file, table and line. The student asked whether the files match the structure of topic 5; the section was then rewritten in full |
 
**Pattern.** T1 is the kind already recorded as T17 and T19 of topic 5: a source
named with more certainty than was checked, here disclosed in the text. T2 is a
question not checked against a file already at hand (T2 and T4 of topic 5). T3 is
the same shape as T2: a source file at hand, `notes_05.md`, not followed to the end;
the student found it, not the tutor.
 
---
 
## Metric
 
To be given at the end of the topic, as in topic 5: execution discipline, complete
answers, understanding, recording discipline, out of 10 each.
