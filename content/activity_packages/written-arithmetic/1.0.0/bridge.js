/* Cornerstone activity protocol v1. No credentials, API calls, or activity rules. */
(function (root) {
  'use strict';
  const PROTOCOL = 'cornerstone.activity';
  const VERSION = 1;

  function validOrigin(origin) {
    if (typeof origin !== 'string' || origin === 'null') return false;
    try {
      const url = new URL(origin);
      return (url.protocol === 'https:' || url.protocol === 'http:') && url.origin === origin;
    } catch (_) {
      return false;
    }
  }

  function envelope(data) {
    return data !== null && typeof data === 'object' && !Array.isArray(data)
      && data.protocol === PROTOCOL && data.version === VERSION;
  }

  function errorMessage(error) {
    if (typeof error === 'string' && error.length) return error;
    if (error && typeof error.message === 'string') return error.message;
    return 'The activity could not save this request. Please try again.';
  }

  function connect(surface, onInitialize) {
    let hostOrigin = null;
    let channel = null;
    let sequence = 0;
    let disposed = false;
    let readyTimer = null;
    const pending = new Map();

    function announce() {
      if (!disposed && !channel && surface.parent !== surface) {
        // Ready contains no learner data; the parent's origin is not known yet.
        surface.parent.postMessage({ protocol: PROTOCOL, version: VERSION, type: 'ready' }, '*');
      }
    }

    function receive(event) {
      const data = event.data;
      if (disposed || event.source !== surface.parent || !envelope(data)) return;
      if (!channel) {
        if (data.type !== 'initialize' || !validOrigin(event.origin)
          || typeof data.channel !== 'string' || data.channel.length < 1 || data.channel.length > 200) return;
        try {
          onInitialize(data.payload);
        } catch (_) {
          return; // A malformed initialization cannot establish the channel.
        }
        hostOrigin = event.origin;
        channel = data.channel;
        if (readyTimer !== null) surface.clearInterval(readyTimer);
        readyTimer = null;
        return;
      }
      if (event.origin !== hostOrigin || data.channel !== channel || data.type !== 'response'
        || typeof data.request_id !== 'string' || !pending.has(data.request_id)) return;
      if (data.ok !== true && data.ok !== false) return;
      const request = pending.get(data.request_id);
      pending.delete(data.request_id);
      if (data.ok) request.resolve(data.result);
      else request.reject(new Error(errorMessage(data.error)));
    }

    surface.addEventListener('message', receive);
    readyTimer = surface.setInterval(announce, 1000);
    announce();

    return {
      request(action, payload) {
        if (disposed || !channel) return Promise.reject(new Error('The activity is not connected yet.'));
        if (action !== 'check' && action !== 'complete') return Promise.reject(new Error('Unsupported activity action.'));
        const requestId = `activity-${++sequence}`;
        return new Promise((resolve, reject) => {
          pending.set(requestId, { resolve, reject });
          surface.parent.postMessage({
            responses: payload.responses,
            duration_seconds: payload.duration_seconds,
            protocol: PROTOCOL,
            version: VERSION,
            channel,
            type: 'request',
            request_id: requestId,
            action,
          }, hostOrigin);
        });
      },
      dispose() {
        if (disposed) return;
        disposed = true;
        surface.removeEventListener('message', receive);
        if (readyTimer !== null) surface.clearInterval(readyTimer);
        for (const request of pending.values()) request.reject(new Error('The activity has closed.'));
        pending.clear();
      },
    };
  }

  const api = Object.freeze({ connect, validOrigin, envelope });
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.CornerstoneActivityBridge = api;
}(typeof window === 'undefined' ? globalThis : window));
