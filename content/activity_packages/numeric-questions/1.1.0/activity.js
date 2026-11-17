/* The package renders questions and working supplied by the host. Rust marks each field. */
(function (root) {
  'use strict';

  function validatePayload(payload) {
    if (!payload || !['assisted', 'assessment'].includes(payload.mode)
      || typeof payload.instructions !== 'string' || !Array.isArray(payload.items)
      || payload.items.length < 1 || payload.items.length > 500) throw new Error('Invalid question activity.');
    const ids = new Set();
    function takeId(id) {
      if (typeof id !== 'string' || !id.length || id.length > 200 || ids.has(id)) throw new Error('Invalid question ID.');
      ids.add(id);
    }
    for (const item of payload.items) {
      if (!item || typeof item.content !== 'string' || item.response_kind !== 'integer'
        || (item.answer_prompt != null && typeof item.answer_prompt !== 'string')) throw new Error('Invalid integer question.');
      takeId(item.item_id);
      if (item.steps !== undefined) {
        if (!Array.isArray(item.steps) || item.steps.length > 10) throw new Error('Invalid question steps.');
        for (const step of item.steps) {
          if (!step || typeof step.prompt !== 'string') throw new Error('Invalid step.');
          takeId(step.item_id);
        }
      }
      if (item.equation != null && (typeof item.equation !== 'string'
        || item.equation.split('□').length !== (item.steps?.length || 0) + 2)) throw new Error('Invalid equation fields.');
    }
    return payload;
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { validatePayload };
    return;
  }

  const document = root.document;
  const el = Object.fromEntries(['activity', 'title', 'mode', 'instructions', 'notice', 'error', 'questions',
    'actions', 'submit', 'result-title', 'result-detail'].map(id => [id, document.getElementById(id)]));
  const fields = new Map();
  const checkButtons = [];
  let busy = false;
  let finished = false;
  let startedAt;

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }

  function notice(text, error = false) {
    el.error.hidden = !error;
    el.error.textContent = error ? text : '';
    el.notice.textContent = error ? '' : text;
    el.notice.hidden = error || !text;
  }

  function updateEnabled() {
    el.activity.setAttribute('aria-busy', String(busy));
    for (const { input } of fields.values()) input.disabled = busy || finished;
    for (const button of checkButtons) button.disabled = busy || finished;
    el.submit.disabled = busy || finished;
  }

  function rowMessage(field, text, correct = false) {
    field.feedback.textContent = text;
    field.feedback.hidden = !text;
    field.feedback.classList.toggle('correct', correct);
  }

  function mark(field, wrong) {
    field.input.classList.toggle('incorrect', wrong);
    field.input.setAttribute('aria-invalid', String(wrong));
  }

  function addField(container, id, prompt, questionIndex, feedback) {
    const input = node('input', 'answer');
    input.type = 'text';
    input.inputMode = 'numeric';
    input.pattern = '-?[0-9]+';
    input.maxLength = 12;
    input.autocomplete = 'off';
    input.spellcheck = false;
    input.id = 'field-' + fields.size;
    input.setAttribute('enterkeyhint', 'next');
    input.setAttribute('aria-label', 'Question ' + (questionIndex + 1) + '. ' + prompt);
    input.setAttribute('aria-describedby', feedback.id);
    const field = { id, questionIndex, input, feedback };
    fields.set(id, field);
    input.addEventListener('input', () => {
      mark(field, false);
      rowMessage(field, '');
      notice('');
    });
    input.addEventListener('keydown', event => {
      if (event.key !== 'Enter') return;
      event.preventDefault();
      const next = input.closest('section.question')?.querySelector('button');
      const inputs = Array.from(fields.values());
      const following = inputs[inputs.indexOf(field) + 1];
      if (next && following?.questionIndex !== questionIndex) next.focus();
      else (following?.input || el.submit).focus();
    });
    container.append(input);
    return field;
  }

  function renderQuestion(item, index, canCheck) {
    const card = node('section', 'question');
    const number = node('span', 'question-number', String(index + 1));
    number.setAttribute('aria-hidden', 'true');
    const heading = node('div', 'question-row');
    heading.append(number);
    card.append(heading);
    const feedback = node('p', 'field-feedback');
    feedback.hidden = true;
    feedback.id = 'feedback-' + index;
    feedback.setAttribute('aria-live', 'polite');
    const equation = node('div', 'equation');
    heading.append(equation);
    const steps = item.steps || [];
    const prompts = [...steps, { item_id: item.item_id, prompt: item.answer_prompt || item.content }];
    const plain = item.content.replace(/ - /g, ' − ');
    // Older stored guided runs carry individual prompts instead of a typeset equation.
    const parts = item.equation ? item.equation.split('□')
      : steps.length ? [plain + ' ' + steps[0].prompt, ...steps.slice(1).map(s => s.prompt), item.answer_prompt || '=', '']
      : plain.includes('__') ? plain.split('__') : [plain, ''];
    const entries = prompts.map((field, i) => {
      if (parts[i]) equation.append(node('span', 'term', parts[i].trim()));
      const label = field.prompt === item.content ? plain : plain + ' ' + field.prompt;
      return addField(equation, field.item_id, label, index, feedback);
    });
    if (parts.at(-1)) equation.append(node('span', 'term', parts.at(-1).trim()));
    card.append(feedback);
    if (canCheck) {
      const button = node('button', 'check', 'Check my work');
      button.type = 'button';
      button.setAttribute('aria-label', 'Check my work for question ' + (index + 1));
      button.addEventListener('click', () => send('check', entries));
      card.append(button);
      checkButtons.push(button);
    }
    el.questions.append(card);
  }

  function initialize(raw) {
    const payload = validatePayload(raw);
    const assessment = payload.mode === 'assessment';
    const canCheck = !assessment && payload.capabilities?.check === true;
    startedAt = root.performance.now();
    el.title.textContent = payload.title || 'Number practice';
    el.instructions.textContent = payload.instructions;
    el.mode.textContent = assessment ? 'Checkpoint' : 'Practice';
    el.mode.hidden = false;
    el.mode.classList.toggle('assessment', assessment);
    el.submit.textContent = assessment ? 'Submit checkpoint' : 'Finish practice';
    payload.items.forEach((item, index) => renderQuestion(item, index, canCheck));
    el.actions.hidden = false;
    notice(canCheck ? 'Fill in a row, then check it.' : 'Fill in each answer, then submit your work.');
    updateEnabled();
  }

  async function send(action, entries) {
    if (busy || finished || startedAt === undefined) return;
    const finish = action === 'complete';
    const responses = [];
    let firstBlank;
    for (const entry of entries) {
      const value = entry.input.value.trim();
      if (!value) {
        firstBlank ??= entry;
      } else if (!/^-?[0-9]+$/.test(value)) {
        mark(entry, true);
        rowMessage(entry, 'Write a whole number in this box.');
        entry.input.focus();
        return;
      } else {
        responses.push({ item_id: entry.id, value });
      }
    }
    if (firstBlank) {
      rowMessage(firstBlank, 'Fill in this box to finish the row.');
      firstBlank.input.focus();
      return;
    }
    busy = true;
    updateEnabled();
    notice(finish ? 'Submitting your work…' : 'Checking…');
    try {
      const result = await bridge.request(action, {
        responses, duration_seconds: Math.min(86400, Math.max(0, Math.floor((root.performance.now() - startedAt) / 1000))),
      });
      const check = finish ? result.check_result : result;
      const summary = result.activity_summary || {};
      const feedback = check?.feedback || (summary.corrections || []).map(c => ({
        cell_id: c.item_id, correct: false, expected: c.expected_response, explanation: c.correction_cue,
      }));
      const wrongRows = new Set();
      for (const result of feedback) {
        const field = fields.get(result.cell_id);
        if (!field) continue;
        mark(field, !result.correct);
        if (!result.correct && !wrongRows.has(field.questionIndex)) {
          rowMessage(field, result.explanation || 'Check this number.');
          wrongRows.add(field.questionIndex);
        }
      }
      const rows = new Map(entries.map(field => [field.questionIndex, field]));
      for (const [index, field] of rows) {
        if (!wrongRows.has(index)) rowMessage(field, '✓ Correct', true);
      }
      if (finish) {
        finished = true;
        el['result-title'].textContent = result.run_outcome_label || 'Finished';
        el['result-detail'].textContent = Number.isInteger(summary.correct_count) && Number.isInteger(summary.item_count)
          ? summary.correct_count + ' of ' + summary.item_count + ' questions correct.' : '';
        el.submit.textContent = 'Submitted';
        notice([el['result-title'].textContent, el['result-detail'].textContent].join(' ').trim());
      } else {
        notice('');
      }
    } catch (error) {
      notice(error instanceof Error ? error.message : 'Your work is still here. Please try again.', true);
    } finally {
      busy = false;
      updateEnabled();
    }
  }

  const bridge = root.CornerstoneActivityBridge.connect(root, initialize);
  el.submit.addEventListener('click', () => send('complete', Array.from(fields.values())));
  root.addEventListener('pagehide', () => bridge.dispose(), { once: true });
}(typeof window === 'undefined' ? globalThis : window));
