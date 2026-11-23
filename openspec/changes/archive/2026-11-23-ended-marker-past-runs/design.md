# Design

## Context

`App.Runs` builds one text per stored run with `runText`. The row already carries an `ended` flag, but the text does not show it.

## Goals / Non-Goals

**Goals:**
- An ended run reads differently from an unfinished run in the list.

**Non-Goals:**
- Naming the run by its marker in the 0.8 plan. Issue #48 covers the plan step.

## Decisions

1. **Two whole translated sentences.** One ends with `, ended`. The locale test allows no concatenation and no variable key. Alternative: append a translated word. Rejected: it breaks the whole-sentence rule.
