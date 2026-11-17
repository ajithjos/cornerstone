/* Written arithmetic presentation only. All questions, scoring, and explanations come from the host. */
(function (root) {
  'use strict';
  const ROW_KINDS = new Set(['operand', 'annotation', 'answer', 'working', 'quotient', 'dividend', 'remainder']);

  function validatePayload(payload) {
    if (!payload || !['assisted', 'assessment'].includes(payload.mode)) throw new Error('Invalid activity mode.');
    const sheet = payload.worksheet;
    if (!sheet || !sheet.level || typeof sheet.level.title !== 'string'
      || typeof sheet.level.instructions !== 'string' || !Array.isArray(sheet.problems)
      || sheet.problems.length < 1 || sheet.problems.length > 24) throw new Error('Invalid worksheet.');
    const ids = new Set();
    const problemIds = new Set();
    let inputCount = 0;
    for (const problem of sheet.problems) {
      if (!problem || typeof problem.id !== 'string' || problemIds.has(problem.id)
        || typeof problem.prompt !== 'string' || !Number.isInteger(problem.columns)
        || problem.columns < 1 || problem.columns > 20 || !Array.isArray(problem.rows)
        || problem.rows.length < 1 || problem.rows.length > 80) throw new Error('Invalid exercise.');
      problemIds.add(problem.id);
      if (problem.column_labels != null && (!Array.isArray(problem.column_labels)
        || problem.column_labels.length !== problem.columns
        || problem.column_labels.some((label) => typeof label !== 'string'))) throw new Error('Invalid column labels.');
      for (const row of problem.rows) {
        if (!row || typeof row.label !== 'string' || typeof row.kind !== 'string'
          || !Array.isArray(row.cells) || row.cells.length !== problem.columns) throw new Error('Invalid written row.');
        if (row.trailing_sign != null && !['+', '−'].includes(row.trailing_sign)) throw new Error('Invalid operation sign.');
        for (const cell of row.cells) {
          if (!cell || typeof cell.text !== 'string' || !Number.isInteger(cell.max_digits)
            || cell.max_digits < 1 || cell.max_digits > 8) throw new Error('Invalid written cell.');
          if (cell.id !== null && cell.id !== undefined) {
            if (typeof cell.id !== 'string' || cell.id.length < 1 || cell.id.length > 240 || ids.has(cell.id)) {
              throw new Error('Invalid or duplicate cell identifier.');
            }
            ids.add(cell.id);
            inputCount += 1;
          }
        }
      }
    }
    if (inputCount < 1 || inputCount > 5000) throw new Error('Invalid worksheet size.');
    return payload;
  }

  function normalizeResult(result) {
    const value = result && typeof result === 'object' ? result : {};
    const check = value.check_result || value.presentation_feedback || value;
    const summary = value.activity_summary;
    let feedback = Array.isArray(check.feedback) ? check.feedback : [];
    if (!feedback.length && summary && Array.isArray(summary.corrections)) {
      feedback = summary.corrections.map((correction) => ({
        cell_id: correction.item_id,
        correct: false,
        expected: correction.expected_response,
        explanation: correction.correction_cue,
      }));
    }
    return {
      feedback: feedback.filter((item) => item && typeof item.cell_id === 'string' && typeof item.correct === 'boolean'),
      correctCount: Number.isInteger(check.correct_count) ? check.correct_count : null,
      totalCount: Number.isInteger(check.total_count) ? check.total_count : null,
      summary: typeof value.summary === 'string' ? value.summary
        : typeof value.run_outcome_label === 'string' ? value.run_outcome_label : '',
    };
  }

  const helpers = { validatePayload, normalizeResult };
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = helpers;
    return;
  }

  const document = root.document;
  const elements = Object.fromEntries([
    'activity', 'activity-title', 'mode-badge', 'instructions', 'mode-guidance', 'notice',
    'error', 'exercises', 'actions', 'complete', 'result', 'completion-title', 'completion-detail',
  ].map((id) => [id, document.getElementById(id)]));
  const state = {
    mode: null, busy: false, finished: false, startedAt: null,
    entries: new Map(), exercises: new Map(), feedback: new Map(), buttons: [],
  };

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }

  function setNotice(message) {
    elements.notice.textContent = message;
    elements.notice.hidden = !message;
  }

  function setError(message) {
    elements.error.textContent = message || '';
    elements.error.hidden = !message;
  }

  function updateEnabled() {
    elements.activity.setAttribute('aria-busy', String(state.busy));
    for (const entry of state.entries.values()) entry.input.disabled = state.busy || state.finished;
    for (const button of state.buttons) button.disabled = state.busy || state.finished;
    elements.complete.disabled = state.busy || state.finished;
  }

  function refreshFeedback(problemId) {
    const exercise = state.exercises.get(problemId);
    const wrong = [];
    const empty = [];
    let checked = 0;
    for (const entry of exercise.entries) {
      const feedback = state.feedback.get(entry.cellId);
      if (!entry.input.value) empty.push(entry);
      entry.input.classList.toggle('correct', feedback?.correct === true);
      entry.input.classList.toggle('incorrect', feedback?.correct === false);
      entry.input.setAttribute('aria-invalid', String(feedback?.correct === false));
      entry.marker.hidden = feedback?.correct !== false;
      entry.marker.classList.toggle('incorrect', feedback?.correct === false);
      entry.marker.textContent = feedback ? (feedback.correct ? '✓' : '!') : '';
      entry.input.setAttribute('aria-label', entry.label + (feedback ? (feedback.correct ? ', correct' : ', needs correction') : ''));
      entry.input.removeAttribute('aria-describedby');
      if (feedback) checked += 1;
      if (feedback?.correct === false) wrong.push({ entry, feedback });
    }
    exercise.feedback.replaceChildren();
    if (exercise.showMissing && empty.length) {
      const hint = node('p', 'missing-hint', empty.length === 1
        ? 'One box still needs a digit.' : `${empty.length} boxes still need digits.`);
      hint.id = `missing-${exercise.number}`;
      exercise.feedback.append(hint);
      for (const entry of empty) entry.input.setAttribute('aria-describedby', hint.id);
    }
    if (wrong.length) {
      const list = node('ul', 'feedback-list');
      for (const { entry, feedback } of wrong) {
        const item = node('li');
        item.id = `${entry.input.id}-feedback`;
        item.append(node('span', 'feedback-location', entry.location));
        const explanation = typeof feedback.explanation === 'string' && feedback.explanation.length
          ? feedback.explanation : 'Check this box and try again.';
        item.append(node('span', '', explanation));
        if (state.finished && typeof feedback.expected === 'string') {
          item.append(node('span', 'expected-answer', ` Write ${feedback.expected} in this box.`));
        }
        entry.input.setAttribute('aria-describedby', item.id);
        list.append(item);
      }
      exercise.feedback.append(list);
    } else if (checked === exercise.entries.length) {
      exercise.feedback.append(node('p', 'exercise-ok', '✓ This question is correct.'));
    }
  }

  function renderProblem(problem, index) {
    const card = node('section', 'exercise');
    const heading = node('div', 'exercise-header');
    heading.append(node('span', 'question-number', String(index + 1)));
    const title = node('h2', '', problem.prompt);
    title.id = `question-${index + 1}`;
    heading.append(title);
    card.setAttribute('aria-labelledby', title.id);
    card.append(heading);
    const scroll = node('div', 'grid-scroll');
    scroll.tabIndex = 0;
    scroll.setAttribute('role', 'region');
    scroll.setAttribute('aria-label', `Question ${index + 1} working grid. Scroll sideways if needed.`);
    const table = node('table', 'written-grid');
    table.append(node('caption', 'sr-only', `Written working for ${problem.prompt}`));
    if (problem.column_labels) {
      const thead = node('thead');
      const header = node('tr');
      header.append(node('td'));
      for (const name of problem.column_labels) {
        const columnHeading = node('th', 'place-name', name);
        columnHeading.scope = 'col';
        header.append(columnHeading);
      }
      thead.append(header);
      table.append(thead);
    }
    const tbody = node('tbody');
    const rowEntries = [];
    const entries = [];
    problem.rows.forEach((row, rowIndex) => {
      const tr = node('tr', ROW_KINDS.has(row.kind) ? row.kind : '');
      const label = node('th', '', row.label);
      label.scope = 'row';
      tr.append(label);
      rowEntries[rowIndex] = [];
      row.cells.forEach((cell, column) => {
        const td = node('td');
        const wrap = node('div', 'cell-content');
        if (cell.id === null || cell.id === undefined) {
          if (cell.text) wrap.append(node('span', 'fixed-value', cell.text));
        } else {
          const input = node('input', 'digit-input');
          input.type = 'text';
          input.inputMode = 'numeric';
          input.pattern = '[0-9]*';
          input.maxLength = cell.max_digits;
          input.size = cell.max_digits;
          input.required = true;
          input.autocomplete = 'off';
          input.spellcheck = false;
          input.id = `working-${index}-${rowIndex}-${column}`;
          const location = row.kind === 'remainder' ? row.label
            : `${row.label || 'Working'}, ${problem.column_labels?.[column] || `box ${column + 1}`}`;
          const accessibleLabel = `Question ${index + 1}, ${location}`;
          input.setAttribute('aria-label', accessibleLabel);
          const marker = node('span', 'cell-marker');
          marker.setAttribute('aria-hidden', 'true');
          marker.hidden = true;
          const entry = { cellId: cell.id, problemId: problem.id, input, marker, label: accessibleLabel, location };
          state.entries.set(cell.id, entry);
          entries.push(entry);
          rowEntries[rowIndex][column] = input;
          let lastValidValue = '';
          input.addEventListener('input', () => {
            if (!new RegExp(`^[0-9]{0,${cell.max_digits}}$`).test(input.value)) {
              input.value = lastValidValue;
              setNotice('Use digits from 0 to 9 in the boxes.');
              return;
            }
            lastValidValue = input.value;
            state.feedback.delete(cell.id);
            refreshFeedback(problem.id);
            setError('');
          });
          input.addEventListener('keydown', (event) => {
            if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
              const direction = event.key === 'ArrowLeft' ? -1 : 1;
              const atEdge = direction < 0 ? input.selectionStart === 0 : input.selectionEnd === input.value.length;
              if (!atEdge || input.selectionStart !== input.selectionEnd
                || event.shiftKey || event.altKey || event.metaKey || event.ctrlKey) return;
              for (let next = column + direction; next >= 0 && next < problem.columns; next += direction) {
                const target = rowEntries[rowIndex][next];
                if (target) {
                  event.preventDefault();
                  target.focus();
                  target.select();
                  break;
                }
              }
              return;
            }
            if (!['ArrowUp', 'ArrowDown'].includes(event.key)) return;
            const direction = event.key === 'ArrowUp' ? -1 : 1;
            for (let next = rowIndex + direction; next >= 0 && next < rowEntries.length; next += direction) {
              const target = rowEntries[next]?.[column];
              if (target && !target.disabled) {
                event.preventDefault();
                target.focus();
                target.select();
                break;
              }
            }
          });
          wrap.append(input, marker);
        }
        td.append(wrap);
        tr.append(td);
      });
      if (row.trailing_sign) tr.append(node('td', 'operation-sign', row.trailing_sign));
      tbody.append(tr);
    });
    table.append(tbody);
    scroll.append(table);
    card.append(scroll);
    if (state.mode === 'assisted') {
      const actions = node('div', 'exercise-actions');
      const check = node('button', 'button', 'Check this question');
      check.type = 'button';
      check.setAttribute('aria-label', `Check question ${index + 1}`);
      check.addEventListener('click', () => send('check', problem.id));
      state.buttons.push(check);
      actions.append(check);
      card.append(actions);
    }
    const feedback = node('div', 'exercise-feedback');
    feedback.setAttribute('aria-live', 'polite');
    state.exercises.set(problem.id, { feedback, entries, number: index + 1, showMissing: false });
    card.append(feedback);
    elements.exercises.append(card);
  }

  function initialize(rawPayload) {
    let payload;
    try {
      payload = validatePayload(rawPayload);
    } catch (error) {
      setError('This activity could not read its worksheet. Reopen it from your lesson.');
      throw error;
    }
    state.mode = payload.mode;
    state.startedAt = root.performance.now();
    elements['activity-title'].textContent = payload.worksheet.level.title;
    elements.instructions.textContent = payload.worksheet.level.instructions;
    elements['mode-badge'].textContent = state.mode === 'assessment' ? 'Assessment' : 'Assisted practice';
    elements['mode-badge'].classList.toggle('assessment', state.mode === 'assessment');
    elements['mode-badge'].hidden = false;
    elements['mode-guidance'].textContent = state.mode === 'assessment'
      ? 'Fill in each box on your own. You can see your corrections after you submit.'
      : 'Fill in each box. Use “Check this question” to check your work as you go.';
    elements.complete.textContent = state.mode === 'assessment' ? 'Submit assessment' : 'Finish practice';
    elements.exercises.classList.toggle('wide', payload.worksheet.problems.some((problem) => problem.columns > 5 || problem.rows.length > 5));
    payload.worksheet.problems.forEach(renderProblem);
    elements.actions.hidden = false;
    setError('');
    setNotice('');
    updateEnabled();
  }

  async function send(action, problemId) {
    if (!state.mode || state.busy || state.finished || (action === 'check' && state.mode !== 'assisted')) return;
    const exercise = state.exercises.get(problemId);
    const entries = exercise ? exercise.entries : Array.from(state.entries.values());
    const firstEmpty = entries.find((entry) => !entry.input.value);
    if (exercise) exercise.showMissing = true;
    if (firstEmpty && (action === 'complete' || entries.every((entry) => !entry.input.value))) {
      const unfinished = state.exercises.get(firstEmpty.problemId);
      unfinished.showMissing = true;
      refreshFeedback(firstEmpty.problemId);
      setError('');
      setNotice(`Question ${unfinished.number} still has empty boxes.`);
      firstEmpty.input.focus();
      return;
    }
    state.busy = true;
    setError('');
    setNotice(action === 'complete' ? 'Submitting your work…' : 'Checking this exercise…');
    updateEnabled();
    try {
      const rawResult = await bridge.request(action, {
        responses: entries.map((entry) => ({ item_id: entry.cellId, value: entry.input.value })),
        duration_seconds: Math.min(86400, Math.max(0, Math.floor((root.performance.now() - state.startedAt) / 1000))),
      });
      const result = normalizeResult(rawResult);
      if (action === 'complete') {
        state.finished = true;
        state.feedback.clear();
      }
      for (const item of result.feedback) {
        if (state.entries.get(item.cell_id)?.input.value) state.feedback.set(item.cell_id, item);
      }
      for (const id of state.exercises.keys()) refreshFeedback(id);
      const counts = result.correctCount !== null && result.totalCount !== null
        ? `${result.correctCount} of ${result.totalCount} boxes correct.` : '';
      if (state.finished) {
        elements.result.hidden = false;
        elements.complete.textContent = state.mode === 'assessment' ? 'Assessment submitted' : 'Practice finished';
        elements['completion-title'].textContent = result.summary || (state.mode === 'assessment' ? 'Assessment submitted' : 'Practice finished');
        elements['completion-detail'].textContent = counts;
        setNotice([elements.complete.textContent, counts].filter(Boolean).join('. '));
      } else {
        setNotice('');
      }
    } catch (error) {
      setError(error instanceof Error ? error.message : 'This request could not be completed. Try again.');
      setNotice('Your working is still here.');
    } finally {
      state.busy = false;
      updateEnabled();
    }
  }

  const bridge = root.CornerstoneActivityBridge.connect(root, initialize);
  elements.complete.addEventListener('click', () => send('complete'));
  root.addEventListener('pagehide', () => bridge.dispose(), { once: true });
  if (root.parent === root) {
    setNotice('Open this activity from Beacon to load a worksheet.');
    elements.activity.setAttribute('aria-busy', 'false');
  }
}(typeof window === 'undefined' ? globalThis : window));
