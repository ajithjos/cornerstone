/* Scalar question presentation. Generation, scoring, time policies, and mastery belong to the host. */
(function (root) {
  'use strict';
  function validatePayload(payload) {
    if (!payload || !['assisted', 'assessment'].includes(payload.mode)
      || typeof payload.instructions !== 'string' || !Array.isArray(payload.items)
      || payload.items.length < 1 || payload.items.length > 500) throw new Error('Invalid question activity.');
    const ids = new Set();
    for (const item of payload.items) {
      if (!item || typeof item.item_id !== 'string' || item.item_id.length < 1 || item.item_id.length > 200
        || ids.has(item.item_id) || typeof item.content !== 'string' || item.response_kind !== 'integer') {
        throw new Error('Invalid integer question.');
      }
      ids.add(item.item_id);
    }
    return payload;
  }

  function normalizeCompletion(result) {
    const value = result && typeof result === 'object' ? result : {};
    const summary = value.activity_summary || {};
    return {
      title: typeof value.run_outcome_label === 'string' ? value.run_outcome_label : 'Your work has been submitted.',
      correctCount: Number.isInteger(summary.correct_count) ? summary.correct_count : null,
      itemCount: Number.isInteger(summary.item_count) ? summary.item_count : null,
      corrections: Array.isArray(summary.corrections) ? summary.corrections.filter((item) => item
        && typeof item.item_id === 'string' && typeof item.expected_response === 'string'
        && typeof item.correction_cue === 'string') : [],
    };
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { validatePayload, normalizeCompletion };
    return;
  }

  const document = root.document;
  const elements = Object.fromEntries([
    'activity', 'title', 'mode', 'instructions', 'notice', 'error', 'questions-form', 'questions',
    'actions', 'submit', 'result-title', 'result-detail',
  ].map((id) => [id, document.getElementById(id)]));
  const state = { mode: null, busy: false, finished: false, startedAt: null, entries: new Map() };

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }
  function setError(message) {
    elements.error.textContent = message || '';
    elements.error.hidden = !message;
  }
  function updateEnabled() {
    elements.activity.setAttribute('aria-busy', String(state.busy));
    for (const entry of state.entries.values()) entry.input.disabled = state.busy || state.finished;
    elements.submit.disabled = state.busy || state.finished;
  }

  function initialize(rawPayload) {
    let payload;
    try { payload = validatePayload(rawPayload); }
    catch (error) {
      setError('This activity could not read its questions. Reopen it from your lesson.');
      throw error;
    }
    state.mode = payload.mode;
    state.startedAt = root.performance.now();
    elements.title.textContent = typeof payload.title === 'string' ? payload.title : 'Number practice';
    elements.instructions.textContent = payload.instructions;
    elements.mode.textContent = payload.mode === 'assessment' ? 'Assessment' : 'Practice';
    elements.mode.classList.toggle('assessment', payload.mode === 'assessment');
    elements.mode.hidden = false;
    elements.submit.textContent = payload.mode === 'assessment' ? 'Submit assessment' : 'Finish practice';
    payload.items.forEach((item, index) => {
      const card = node('section', 'question');
      const row = node('div', 'question-row');
      const number = node('span', 'question-number', String(index + 1));
      number.setAttribute('aria-hidden', 'true');
      const label = node('label', 'question-label', item.content);
      const input = node('input', 'answer');
      input.id = `answer-${index}`;
      label.htmlFor = input.id;
      input.type = 'text';
      input.inputMode = 'numeric';
      input.pattern = '-?[0-9]*';
      input.maxLength = 12;
      input.autocomplete = 'off';
      input.spellcheck = false;
      input.setAttribute('aria-label', `Question ${index + 1}: ${item.content}`);
      input.setAttribute('enterkeyhint', index === payload.items.length - 1 ? 'done' : 'next');
      let lastValidValue = '';
      input.addEventListener('input', () => {
        if (!/^-?[0-9]{0,11}$/.test(input.value)) {
          input.value = lastValidValue;
          elements.notice.textContent = 'Enter a whole-number answer.';
          return;
        }
        lastValidValue = input.value;
        setError('');
      });
      input.addEventListener('keydown', (event) => {
        if (event.key !== 'Enter') return;
        event.preventDefault();
        const next = document.getElementById(`answer-${index + 1}`);
        if (next) next.focus();
        else elements.submit.focus();
      });
      row.append(number, label, input);
      const correction = node('div', 'correction');
      correction.id = `correction-${index}`;
      correction.hidden = true;
      card.append(row, correction);
      elements.questions.append(card);
      state.entries.set(item.item_id, { input, correction });
    });
    elements.actions.hidden = false;
    elements.notice.textContent = 'Your questions are ready. Answer each one before submitting.';
    setError('');
    updateEnabled();
  }

  async function complete(event) {
    event.preventDefault();
    if (state.busy || state.finished || state.mode === null) return;
    state.busy = true;
    setError('');
    elements.notice.textContent = 'Submitting your answers…';
    updateEnabled();
    try {
      const result = normalizeCompletion(await bridge.request('complete', {
        responses: Array.from(state.entries, ([item_id, entry]) => ({ item_id, value: entry.input.value.trim() })),
        duration_seconds: Math.min(86400, Math.max(0, Math.floor((root.performance.now() - state.startedAt) / 1000))),
      }));
      state.finished = true;
      for (const correction of result.corrections) {
        const entry = state.entries.get(correction.item_id);
        if (!entry) continue;
        entry.input.classList.add('incorrect');
        entry.input.setAttribute('aria-invalid', 'true');
        entry.input.setAttribute('aria-describedby', entry.correction.id);
        entry.correction.replaceChildren(
          node('strong', '', `! Correct answer: ${correction.expected_response}`),
          node('span', '', correction.correction_cue),
        );
        entry.correction.hidden = false;
      }
      const counts = result.correctCount !== null && result.itemCount !== null
        ? `${result.correctCount} of ${result.itemCount} questions correct.` : '';
      elements['result-title'].textContent = result.title;
      elements['result-detail'].textContent = 'Review the corrections above, then return to your lesson.';
      elements.submit.textContent = state.mode === 'assessment' ? 'Assessment submitted' : 'Practice finished';
      elements.notice.textContent = [result.title, counts, 'Review any corrections above.'].filter(Boolean).join(' ');
    } catch (error) {
      setError(error instanceof Error ? error.message : 'Your answers could not be submitted. Please try again.');
      elements.notice.textContent = 'Your answers are still here.';
    } finally {
      state.busy = false;
      updateEnabled();
    }
  }

  const bridge = root.CornerstoneActivityBridge.connect(root, initialize);
  elements['questions-form'].addEventListener('submit', complete);
  root.addEventListener('pagehide', () => bridge.dispose(), { once: true });
  if (root.parent === root) {
    elements.notice.textContent = 'Open this activity from Cornerstone to load your questions.';
    elements.activity.setAttribute('aria-busy', 'false');
  }
}(typeof window === 'undefined' ? globalThis : window));
