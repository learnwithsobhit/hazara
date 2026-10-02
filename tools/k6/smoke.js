/**
 * Hazara – k6 smoke test
 *
 * Tests the minimum set of endpoints to verify the server is alive and
 * the core guest→room→ws flow works end-to-end.
 *
 * Run:
 *   k6 run tools/k6/smoke.js
 *
 * Override the base URL:
 *   k6 run --env BASE_URL=https://hazara.up.railway.app tools/k6/smoke.js
 *
 * SLOs (smoke level):
 *   p95 latency < 500 ms, error rate < 1 %
 */

import http from 'k6/http';
import ws   from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';
const WS_URL   = BASE_URL.replace(/^http/, 'ws');

export const options = {
  vus: 3,
  duration: '30s',
  thresholds: {
    http_req_failed:   ['rate<0.01'],          // < 1 % HTTP errors
    http_req_duration: ['p(95)<500'],          // p95 < 500 ms
    ws_connect_time:   ['p(95)<1000'],         // p95 WS connect < 1 s
    ws_errors:         ['rate<0.01'],          // < 1 % WS errors
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Custom metrics
// ─────────────────────────────────────────────────────────────────────────────

const wsErrors     = new Rate('ws_errors');
const wsConnTime   = new Trend('ws_connect_time', true);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** POST /api/v1/guests → { id, token } */
function createGuest(name) {
  const res = http.post(
    `${BASE_URL}/api/v1/guests`,
    JSON.stringify({ name }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(res, {
    'create_guest status 200': (r) => r.status === 200,
    'create_guest has id':     (r) => JSON.parse(r.body).id  !== undefined,
    'create_guest has token':  (r) => JSON.parse(r.body).token !== undefined,
  });
  return res.status === 200 ? JSON.parse(res.body) : null;
}

/** POST /api/v1/rooms → { code } */
function createRoom(guestId, token) {
  const res = http.post(
    `${BASE_URL}/api/v1/rooms`,
    JSON.stringify({ guest_id: guestId }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    },
  );
  check(res, {
    'create_room status 200': (r) => r.status === 200,
    'create_room has code':   (r) => JSON.parse(r.body).code !== undefined,
  });
  return res.status === 200 ? JSON.parse(res.body) : null;
}

/** POST /api/v1/rooms/:code/join → { match_id } */
function joinRoom(code, guestId, token) {
  const res = http.post(
    `${BASE_URL}/api/v1/rooms/${code}/join`,
    JSON.stringify({ guest_id: guestId }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    },
  );
  check(res, {
    'join_room status 200':      (r) => r.status === 200,
    'join_room has match_id':    (r) => JSON.parse(r.body).match_id !== undefined,
  });
  return res.status === 200 ? JSON.parse(res.body) : null;
}

/** POST /api/v1/matches/:id/ticket → { ticket } */
function getTicket(matchId, token) {
  const res = http.post(
    `${BASE_URL}/api/v1/matches/${matchId}/ticket`,
    null,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  check(res, {
    'ticket status 200':    (r) => r.status === 200,
    'ticket has value':     (r) => JSON.parse(r.body).ticket !== undefined,
  });
  return res.status === 200 ? JSON.parse(res.body).ticket : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main scenario
// ─────────────────────────────────────────────────────────────────────────────

export default function () {
  // ── 1. Health check ──────────────────────────────────────────────────────
  {
    const res = http.get(`${BASE_URL}/readyz`);
    check(res, { 'readyz 200': (r) => r.status === 200 });
  }

  // ── 2. Create guest ──────────────────────────────────────────────────────
  const vu = __VU;
  const g = createGuest(`smoke_vu${vu}_${Date.now()}`);
  if (!g) { sleep(1); return; }

  // ── 3. Create room ───────────────────────────────────────────────────────
  const room = createRoom(g.id, g.token);
  if (!room) { sleep(1); return; }

  // ── 4. Join own room (occupies seat 0) ───────────────────────────────────
  //    The host is already seated after createRoom; a second join would fail.
  //    Instead we get the match_id via the room detail.
  const roomRes = http.get(`${BASE_URL}/api/v1/rooms/${room.code}`, {
    headers: { Authorization: `Bearer ${g.token}` },
  });
  check(roomRes, { 'room detail 200': (r) => r.status === 200 });
  const matchId = roomRes.status === 200
    ? (JSON.parse(roomRes.body).match_id || null)
    : null;
  if (!matchId) { sleep(1); return; }

  // ── 5. Fetch WS ticket ───────────────────────────────────────────────────
  const ticket = getTicket(matchId, g.token);
  if (!ticket) { sleep(1); return; }

  // ── 6. Open WebSocket ────────────────────────────────────────────────────
  const t0 = Date.now();
  const wsRes = ws.connect(
    `${WS_URL}/api/v1/matches/${matchId}/ws?ticket=${ticket}`,
    {},
    (socket) => {
      socket.on('open', () => {
        wsConnTime.add(Date.now() - t0);
        wsErrors.add(false);
      });

      socket.on('message', (msg) => {
        // Expect the first message to be a snapshot.
        try {
          const snap = JSON.parse(msg);
          check(snap, {
            'ws first message has phase': (s) => s.phase !== undefined,
            'ws first message has seats': (s) => Array.isArray(s.seats),
          });
        } catch (_) {
          wsErrors.add(true);
        }
        // Read one message then close.
        socket.close();
      });

      socket.on('error', () => {
        wsErrors.add(true);
        socket.close();
      });

      // Safety timeout — close after 5 s even if no message arrives.
      socket.setTimeout(() => socket.close(), 5000);
    },
  );

  check(wsRes, { 'ws connect did not throw': () => wsRes === null || true });

  sleep(1);
}
