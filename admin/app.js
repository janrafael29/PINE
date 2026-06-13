(function () {
  'use strict';

  const cfg = window.PINE_ADMIN_CONFIG;
  const $ = (id) => document.getElementById(id);

  const DETECTIONS_LIMIT = 2500;
  // Rendering thousands of SVG divIcons is expensive; keep the map responsive by only
  // drawing a bounded number of captures in/near the viewport.
  const MAP_VIEW_DETECTIONS_MAX = 900;
  const MAP_PIN_ZOOM_THRESHOLD = 15;

  function detectionIsPositive(d) {
    if (!d) return false;
    if (d.has_mealybugs === true) return true;
    return Number(d.count) > 0;
  }

  function positiveDetections(list) {
    const src = list || cacheDetections;
    return src.filter(detectionIsPositive);
  }

  function positiveCountByFieldId() {
    const m = Object.create(null);
    for (let i = 0; i < cacheDetections.length; i++) {
      const d = cacheDetections[i];
      if (!detectionIsPositive(d)) continue;
      const fid = d.field_id == null ? '' : String(d.field_id);
      if (!fid) continue;
      m[fid] = (m[fid] || 0) + 1;
    }
    return m;
  }

  function heatRgbForSeverity(s01) {
    const s = Math.max(0, Math.min(1, s01));
    // Green (low) → yellow → red (high) — high contrast on satellite imagery.
    const r = Math.round(56 + (231 - 56) * Math.pow(s, 0.85));
    const g = Math.round(192 + (76 - 192) * s);
    const b = Math.round(100 + (60 - 100) * s);
    return 'rgb(' + r + ',' + g + ',' + b + ')';
  }

  function updateHeatmapLegend(show) {
    const el = $('pine-heatmap-legend');
    if (!(el instanceof HTMLElement)) return;
    el.hidden = !show;
    el.setAttribute('aria-hidden', show ? 'false' : 'true');
  }

  function detectionStatusBadgeHtml(d) {
    const pos = detectionIsPositive(d);
    const cls = pos ? 'pine-badge pine-badge--positive' : 'pine-badge pine-badge--negative';
    const label = pos ? 'Positive' : 'Negative';
    return '<span class="' + cls + '">' + label + '</span>';
  }

  function expertResponseForDetection(detId) {
    const id = String(detId);
    for (let i = 0; i < cacheExpertResponses.length; i++) {
      if (String(cacheExpertResponses[i].detection_id) === id) {
        return cacheExpertResponses[i];
      }
    }
    return null;
  }

  function capturesForDrawer() {
    let list = cacheDetections.slice();
    if (capturesDrawerFilter === 'positive') {
      list = list.filter(detectionIsPositive);
    } else if (capturesDrawerFilter === 'pending') {
      list = list.filter(function (d) {
        return detectionIsPositive(d) && !expertResponseForDetection(d.id);
      });
    }
    return list;
  }

  function formatReportDate(iso) {
    if (!iso) return '—';
    try {
      const d = new Date(iso);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return months[d.getMonth()] + ' ' + d.getDate() + ', ' + d.getFullYear();
    } catch (_) {
      return String(iso);
    }
  }

  function latestFarmInsightForField(fieldId) {
    const fid = String(fieldId);
    let best = null;
    for (let i = 0; i < cacheFarmInsights.length; i++) {
      const row = cacheFarmInsights[i];
      if (String(row.field_id) !== fid) continue;
      if (!best || String(row.created_at || '') > String(best.created_at || '')) {
        best = row;
      }
    }
    return best;
  }

  async function saveFarmInsight(fieldId, insightText, statusEl) {
    if (!requireFullAdmin('Farm insight')) return;
    const fid = String(fieldId || '').trim();
    const text = String(insightText || '').trim();
    if (!fid || !text) {
      toast('Select a field and enter insight text.', true);
      return;
    }
    const {
      data: { session: authSession },
    } = await supabase.auth.getSession();
    const uid = authSession && authSession.user ? authSession.user.id : null;
    if (!uid) {
      toast('Sign in required.', true);
      return;
    }
    if (statusEl) {
      statusEl.textContent = 'Saving…';
      statusEl.classList.remove('ok', 'err');
    }
    try {
      const { data, error } = await supabase
        .from('farm_insights')
        .insert({
          field_id: fid,
          author_id: uid,
          insight_text: text,
        })
        .select()
        .single();
      if (error) throw error;
      cacheFarmInsights.push(data);
      if (statusEl) {
        statusEl.textContent = 'Saved';
        statusEl.classList.add('ok');
      }
      toast('Farm insight saved.');
    } catch (err) {
      if (statusEl) {
        statusEl.textContent = err && err.message ? err.message : 'Failed';
        statusEl.classList.add('err');
      }
      toast(err && err.message ? err.message : 'Save failed', true);
    }
  }

  async function saveExpertResponse(detId, strategyText, actionType, statusEl) {
    const text = String(strategyText || '').trim();
    if (!text) {
      toast('Enter advice text before saving.', true);
      return;
    }
    const {
      data: { session: authSession },
    } = await supabase.auth.getSession();
    const uid = authSession && authSession.user ? authSession.user.id : null;
    if (!uid) {
      toast('Sign in required.', true);
      return;
    }
    if (statusEl) {
      statusEl.textContent = 'Saving…';
      statusEl.classList.remove('ok', 'err');
    }
    try {
      const row = {
        detection_id: String(detId),
        author_id: uid,
        strategy_text: text,
        updated_at: new Date().toISOString(),
      };
      const act = String(actionType || '').trim();
      if (act) row.action_type = act;
      const { data, error } = await supabase
        .from('expert_responses')
        .upsert(row, { onConflict: 'detection_id' })
        .select()
        .single();
      if (error) throw error;
      let found = false;
      for (let i = 0; i < cacheExpertResponses.length; i++) {
        if (String(cacheExpertResponses[i].detection_id) === String(detId)) {
          cacheExpertResponses[i] = data;
          found = true;
          break;
        }
      }
      if (!found) cacheExpertResponses.push(data);
      if (statusEl) {
        statusEl.textContent = 'Saved';
        statusEl.classList.add('ok');
      }
      toast('DA/OMAG advice saved.');
      if (drawerSection === 'captures') renderDrawer();
    } catch (err) {
      if (statusEl) {
        statusEl.textContent = err && err.message ? err.message : 'Failed';
        statusEl.classList.add('err');
      }
      toast(err && err.message ? err.message : 'Save failed', true);
    }
  }

  /** Edge Function URL for Create user; derived from supabaseUrl so host typos don't break CORS. */
  function createUserFunctionUrlResolved() {
    if (!cfg) return '';
    const baseRaw = cfg.supabaseUrl && String(cfg.supabaseUrl).trim().replace(/\/$/, '');
    if (!baseRaw || baseRaw.indexOf('http') !== 0) return '';
    const defaultUrl = baseRaw + '/functions/v1/pine-admin-create-user';
    const ov = cfg.createUserFunctionUrl;
    if (!ov || String(ov).trim() === '') {
      return defaultUrl;
    }
    const trimmed = String(ov).trim().replace(/\/$/, '');
    if (trimmed.indexOf('http') !== 0) {
      return defaultUrl;
    }
    try {
      if (new URL(trimmed).host === new URL(baseRaw).host) {
        return trimmed;
      }
    } catch (_) {
      /* ignore */
    }
    return defaultUrl;
  }

  /** Edge Function: approve/reject DA access requests (full admin only). */
  function reviewDaRequestFunctionUrlResolved() {
    if (!cfg) return '';
    const baseRaw = cfg.supabaseUrl && String(cfg.supabaseUrl).trim().replace(/\/$/, '');
    if (!baseRaw || baseRaw.indexOf('http') !== 0) return '';
    return baseRaw + '/functions/v1/pine-admin-review-da-request';
  }

  async function reviewDaAccessRequest(requestId, action) {
    if (!requireFullAdmin('DA request review')) return false;
    const url = reviewDaRequestFunctionUrlResolved();
    if (!url || url.indexOf('http') !== 0) {
      toast('Missing supabaseUrl in config.', true);
      return false;
    }
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) {
      toast('Not signed in.', true);
      return false;
    }
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + session.access_token,
          apikey: cfg.supabaseAnonKey,
        },
        body: JSON.stringify({ request_id: requestId, action: action }),
      });
      const j = await res.json().catch(function () {
        return {};
      });
      if (!res.ok) {
        throw new Error(j.error || 'Request failed');
      }
      toast(action === 'approve' ? 'DA access approved.' : 'DA request rejected.');
      await loadDashboard();
      openDrawer('users');
      return true;
    } catch (e) {
      toast(e && e.message ? e.message : 'Review failed', true);
      return false;
    }
  }

  function buildDaRequestsSectionHtml() {
    const pending = cacheDaRequests.filter(function (r) {
      return r.status === 'pending';
    });
    if (pending.length === 0) {
      return (
        '<h3 class="pine-drawer-h3">DA access requests</h3>' +
        '<p class="pine-muted pine-drawer-fields-hint">No pending requests. Farmers submit from the mobile app under <strong>More → DA / OMAG access</strong>.</p>'
      );
    }
    const cards = pending
      .map(function (r) {
        const prof = cacheProfiles.find(function (p) {
          return String(p.id) === String(r.user_id);
        });
        const name = prof ? profileDisplayName(r.user_id) : String(r.user_id);
        const em =
          prof && prof.email != null && String(prof.email).trim() !== ''
            ? String(prof.email).trim()
            : '';
        const note =
          r.note != null && String(r.note).trim() !== ''
            ? '<p class="pine-muted" style="margin:0.35rem 0 0">' +
              escapeHtml(String(r.note).trim()) +
              '</p>'
            : '';
        const when =
          r.created_at != null
            ? '<span class="pine-muted" style="font-size:11px">' +
              escapeHtml(formatTs(r.created_at)) +
              '</span>'
            : '';
        return (
          '<article class="pine-da-request-card">' +
          '<div class="pine-da-request-head">' +
          '<strong>' +
          escapeHtml(name) +
          '</strong>' +
          when +
          (em ? '<br><span class="pine-muted">' + escapeHtml(em) + '</span>' : '') +
          note +
          '</div>' +
          '<div class="pine-da-request-actions">' +
          '<button type="button" class="pine-btn pine-btn-primary pine-btn--sm" data-da-request-approve="' +
          escapeHtml(String(r.id)) +
          '">Approve DA</button>' +
          '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-da-request-reject="' +
          escapeHtml(String(r.id)) +
          '">Reject</button>' +
          '</div></article>'
        );
      })
      .join('');
    return (
      '<h3 class="pine-drawer-h3">DA access requests</h3>' +
      '<p class="pine-muted pine-drawer-fields-hint">Approve to grant <code>da: true</code>. User must sign out and sign in again.</p>' +
      '<div class="pine-da-request-list">' +
      cards +
      '</div>'
    );
  }

  /** Edge Function URL for Delete user (Auth + cascaded profile/fields/detections). */
  function deleteUserFunctionUrlResolved() {
    if (!cfg) return '';
    const baseRaw = cfg.supabaseUrl && String(cfg.supabaseUrl).trim().replace(/\/$/, '');
    if (!baseRaw || baseRaw.indexOf('http') !== 0) return '';
    const defaultUrl = baseRaw + '/functions/v1/pine-admin-delete-user';
    const ov = cfg.deleteUserFunctionUrl;
    if (!ov || String(ov).trim() === '') {
      return defaultUrl;
    }
    const trimmed = String(ov).trim().replace(/\/$/, '');
    if (trimmed.indexOf('http') !== 0) {
      return defaultUrl;
    }
    try {
      if (new URL(trimmed).host === new URL(baseRaw).host) {
        return trimmed;
      }
    } catch (_) {
      /* ignore */
    }
    return defaultUrl;
  }

  /** Edge Function: update Auth email + profiles row (admin only). */
  function updateUserProfileFunctionUrlResolved() {
    if (!cfg) return '';
    const baseRaw = cfg.supabaseUrl && String(cfg.supabaseUrl).trim().replace(/\/$/, '');
    if (!baseRaw || baseRaw.indexOf('http') !== 0) return '';
    const defaultUrl = baseRaw + '/functions/v1/pine-admin-update-user-profile';
    const ov = cfg.updateUserProfileFunctionUrl;
    if (!ov || String(ov).trim() === '') {
      return defaultUrl;
    }
    const trimmed = String(ov).trim().replace(/\/$/, '');
    if (trimmed.indexOf('http') !== 0) {
      return defaultUrl;
    }
    try {
      if (new URL(trimmed).host === new URL(baseRaw).host) {
        return trimmed;
      }
    } catch (_) {
      /* ignore */
    }
    return defaultUrl;
  }

  const elConfigError = $('config-error');
  const elConfigErrorText = $('config-error-text');
  const elLoginSection = $('login-section');
  const elLoginForm = $('login-form');
  const elLoginError = $('login-error');
  const elLoginSubmit = $('login-submit');
  const elNotAdmin = $('not-admin-section');
  const elNotAdminEmail = $('not-admin-email');
  const elNotAdminSignOut = $('not-admin-sign-out');
  const elDashboard = $('dashboard-section');
  const elSignedInLabel = $('signed-in-label');
  const elSignOutBtn = $('sign-out-btn');
  const elStatAccounts = $('stat-accounts');
  const elStatFields = $('stat-fields');
  const elStatDetections = $('stat-detections');
  const elDashLoading = $('dashboard-loading');
  const elDashError = $('dashboard-error');
  const elDashBody = $('dashboard-body');
  const elDrawer = $('admin-drawer');
  const elDrawerContent = $('drawer-content');
  const elDrawerTitle = $('drawer-title');
  const elToast = $('pine-toast');

  let drawerSection = null;
  /** When set, Fields drawer row is in edit mode for this field id. */
  let drawerEditingFieldId = null;
  /** When set, Users drawer row is in edit mode for this profile (auth user) id. */
  let drawerEditingProfileId = null;
  let mapControlsBound = false;
  let mapInitialized = false;

  let cacheProfiles = [];
  let cacheFields = [];
  let cacheDaRequests = [];
  let cacheDetections = [];
  let cacheExpertResponses = [];
  let cacheFarmInsights = [];
  let capturesDrawerFilter = 'all';
  let analyticsChartInstances = [];

  function destroyAnalyticsCharts() {
    for (let i = 0; i < analyticsChartInstances.length; i++) {
      analyticsChartInstances[i].destroy();
    }
    analyticsChartInstances = [];
  }

  const mapViewState = {
    scope: 'all',
    showFields: true,
    showCaptures: true,
    showAccounts: false,
    satellite: true,
    /** When true, capture marker click only toggles selection (no popup). */
    multiSelectMode: false,
    /** When true, drag on the map draws a box and adds enclosed captures to the selection. */
    boxSelectMode: false,
  };

  /** @type {Set<string>} */
  const selectedDetIds = new Set();

  /** While drawing a selection box: start point in map container px + preview rectangle layer. */
  let boxSelectDrag = null;

  /** While Select mode is on: right-button drag pans the map (left drag stays box-select). */
  let rightButtonMapPan = null;

  /** One-step undo: previous `fields.boundary_json` before the last successful geofence save while editing this field. */
  let geofenceUndoSnapshot = null;

  const pineMap = {
    map: null,
    fieldGroup: null,
    fieldLabelLayer: null,
    captureGroup: null,
    userGroup: null,
    satellite: null,
    street: null,
    vertexGroup: null,
    vertexMarkers: [],
    editingFieldId: null,
    editingPolygon: null,
    geocodeMarker: null,
    _locateSearchBound: false,
  };

  function show(el, on) {
    if (el) el.hidden = !on;
  }

  function toast(msg, isError) {
    if (!elToast) return;
    elToast.textContent = msg;
    elToast.classList.toggle('pine-toast-error', !!isError);
    elToast.hidden = false;
    clearTimeout(toast._t);
    toast._t = setTimeout(function () {
      elToast.hidden = true;
    }, 3400);
  }

  let sessionUser = null;
  let sessionIsFullAdmin = false;
  let sessionIsDa = false;

  function readJwtRoles(user) {
    if (!user || !user.app_metadata) {
      return { fullAdmin: false, da: false, staff: false };
    }
    const meta = user.app_metadata;
    const fullAdmin = meta.admin === true || meta.admin === 'true';
    const da =
      meta.da === true ||
      meta.da === 'true' ||
      String(meta.role || '').toLowerCase() === 'da';
    return { fullAdmin: fullAdmin, da: da, staff: fullAdmin || da };
  }

  /** Full superuser (users, fields, bulk edits). */
  function isAdminUser(user) {
    return readJwtRoles(user).fullAdmin;
  }

  /** DA / OMAG staff — org-wide read + report replies only. */
  function isStaffUser(user) {
    return readJwtRoles(user).staff;
  }

  function requireFullAdmin(actionLabel) {
    if (sessionIsFullAdmin) return true;
    toast((actionLabel || 'That action') + ' is limited to full admins.', true);
    return false;
  }

  function syncRoleUi() {
    const full = sessionIsFullAdmin;
    const daOnly = sessionIsDa && !full;
    document.querySelectorAll('[data-admin-only]').forEach(function (el) {
      el.hidden = !full;
    });
    const brand = document.querySelector('.pine-map-sidebar-brand');
    if (brand) {
      brand.textContent = daOnly ? 'PineSight DA' : 'PineSight Admin';
    }
    document.title = daOnly ? 'PineSight — DA' : 'PineSight — Admin';
    if (!full) {
      clearCaptureSelection();
      mapViewState.multiSelectMode = false;
      mapViewState.boxSelectMode = false;
      syncMapSelectionChipUi();
      syncBoxSelectCursorClass();
      const bulkBar = $('capture-bulk-bar');
      if (bulkBar) bulkBar.hidden = true;
    }
  }

  /** Label for UI; JWT user sometimes omits email until refreshed. */
  function formatSessionUserLabel(user) {
    if (!user) return '';
    const um = user.user_metadata;
    return (
      user.email ||
      user.phone ||
      (um && um.email) ||
      user.id ||
      ''
    );
  }

  function formatTs(iso) {
    if (!iso) return '—';
    try {
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return iso;
      return d.toLocaleString();
    } catch (_) {
      return iso;
    }
  }

  function escapeHtml(s) {
    if (s == null) return '';
    const div = document.createElement('div');
    div.textContent = String(s);
    return div.innerHTML;
  }

  function debounce(fn, ms) {
    let t = null;
    return function () {
      const ctx = this;
      const args = arguments;
      clearTimeout(t);
      t = setTimeout(function () {
        fn.apply(ctx, args);
      }, ms);
    };
  }

  function validateConfig() {
    if (
      !cfg ||
      typeof cfg.supabaseUrl !== 'string' ||
      typeof cfg.supabaseAnonKey !== 'string' ||
      !cfg.supabaseUrl.startsWith('http') ||
      cfg.supabaseAnonKey.length < 20
    ) {
      elConfigErrorText.textContent =
        'Invalid admin/config.js — set supabaseUrl and supabaseAnonKey (copy config.example.js).';
      show(elConfigError, true);
      return null;
    }
    show(elConfigError, false);
    return cfg;
  }

  const validCfg = validateConfig();
  if (!validCfg) return;

  const supabase = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });

  function setView(mode) {
    show(elLoginSection, mode === 'login');
    show(elNotAdmin, mode === 'not_admin');
    show(elDashboard, mode === 'dashboard');
    if (mode !== 'dashboard') {
      show(elDashLoading, false);
      show(elDashBody, false);
      show(elDashError, false);
      closeDrawer();
      cancelBoxSelectDrag();
    }
  }

  function profileDisplayName(userId) {
    const p = cacheProfiles.find(function (x) {
      return x.id === userId;
    });
    if (!p) return String(userId).slice(0, 8) + '…';
    const n = (p.display_name || p.email || p.phone || userId).trim();
    return n || userId;
  }

  function parseBoundaryLatLngs(raw) {
    if (raw == null) return null;
    let list;
    try {
      if (typeof raw === 'string') {
        const t = raw.trim();
        if (!t) return null;
        list = JSON.parse(t);
      } else if (Array.isArray(raw)) {
        list = raw;
      } else return null;
    } catch (_) {
      return null;
    }
    if (!Array.isArray(list) || list.length < 3) return null;
    const out = [];
    for (let i = 0; i < list.length; i++) {
      const e = list[i];
      if (!e || typeof e !== 'object') continue;
      const lat = Number(e.lat);
      const lng = Number(e.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      out.push([lat, lng]);
    }
    return out.length >= 3 ? out : null;
  }

  /** Ring: array of [lat, lng]. Ray-cast point-in-polygon (same idea as app Flutter helper). */
  function pointInPolygon(lat, lng, ring) {
    let inside = false;
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const yi = ring[i][0];
      const xi = ring[i][1];
      const yj = ring[j][0];
      const xj = ring[j][1];
      const intersect =
        yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi + 1e-12) + xi;
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  function randomPointInPolygon(ring) {
    if (!ring || ring.length < 3) return null;
    let minLat = ring[0][0];
    let maxLat = ring[0][0];
    let minLng = ring[0][1];
    let maxLng = ring[0][1];
    for (let i = 1; i < ring.length; i++) {
      const la = ring[i][0];
      const ln = ring[i][1];
      if (la < minLat) minLat = la;
      if (la > maxLat) maxLat = la;
      if (ln < minLng) minLng = ln;
      if (ln > maxLng) maxLng = ln;
    }
    for (let k = 0; k < 120; k++) {
      const lat = minLat + Math.random() * (maxLat - minLat);
      const lng = minLng + Math.random() * (maxLng - minLng);
      if (pointInPolygon(lat, lng, ring)) {
        return { lat: lat, lng: lng };
      }
    }
    return null;
  }

  function strokeColorForField(id) {
    let h = 0;
    const s = String(id);
    for (let i = 0; i < s.length; i++) {
      h = (h + s.charCodeAt(i) * 13) % 280;
    }
    return 'hsl(' + (88 + (h % 50)) + ' 42% 36%)';
  }

  /** Centroid of one outer ring [[lat,lng], ...] for label anchor. */
  function ringCentroidLatLng(ring) {
    if (!ring || ring.length < 1) return null;
    let sLat = 0;
    let sLng = 0;
    let n = 0;
    for (let i = 0; i < ring.length; i++) {
      const la = Number(ring[i][0]);
      const ln = Number(ring[i][1]);
      if (!Number.isFinite(la) || !Number.isFinite(ln)) continue;
      sLat += la;
      sLng += ln;
      n++;
    }
    if (n < 1) return null;
    return L.latLng(sLat / n, sLng / n);
  }

  /**
   * Bounding box of one ring as Nominatim-style strings [south, north, west, east].
   * Used so "Go to place" can fly to the actual fence, not only the centroid.
   */
  function ringToSearchBoundingBox(ring, padDeg) {
    if (!ring || ring.length < 1) return null;
    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLng = Infinity;
    let maxLng = -Infinity;
    for (let i = 0; i < ring.length; i++) {
      const la = Number(ring[i][0]);
      const ln = Number(ring[i][1]);
      if (!Number.isFinite(la) || !Number.isFinite(ln)) continue;
      if (la < minLat) minLat = la;
      if (la > maxLat) maxLat = la;
      if (ln < minLng) minLng = ln;
      if (ln > maxLng) maxLng = ln;
    }
    if (minLat === Infinity) return null;
    const pad = padDeg == null ? 0.0004 : padDeg;
    const south = minLat - pad;
    const north = maxLat + pad;
    const west = minLng - pad;
    const east = maxLng + pad;
    if (!(north > south && east > west)) return null;
    return [String(south), String(north), String(west), String(east)];
  }

  /** Stable angle per field id so overlapping anchors start slightly apart. */
  function fieldIdToLabelJitterAngle(fid) {
    const s = String(fid);
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return ((h >>> 0) % 6283) / 1000;
  }

  function fieldLabelCollisionRadiusPx(name, wide) {
    const len = String(name || 'Field').length;
    if (wide) {
      return Math.min(96, 36 + len * 3.4);
    }
    return Math.min(64, 18 + len * 3.2);
  }

  function makeFieldLabelDivIcon(name, opts) {
    const options = opts || {};
    const count = options.positiveCount;
    const showCount =
      typeof count === 'number' && count > 0 && options.showCount === true;
    const countHtml = showCount
      ? '<span class="pine-field-label-count">' + String(count) + '</span>'
      : '';
    return L.divIcon({
      className: 'pine-field-label-divicon',
      html:
        '<div class="pine-field-label-chip' +
        (showCount ? ' pine-field-label-chip--has-count' : '') +
        '" role="button" tabindex="0" title="Click to zoom to this field">' +
        '<span class="pine-field-label-name">' +
        escapeHtml(name) +
        '</span>' +
        countHtml +
        '</div>',
      iconSize: [2, 2],
      iconAnchor: [1, 1],
    });
  }

  function makeHeatFieldBadgeIcon(name, count, sev) {
    let tier = 'low';
    if (sev >= 0.66) tier = 'high';
    else if (sev >= 0.33) tier = 'mid';
    return L.divIcon({
      className: 'pine-field-label-divicon',
      html:
        '<div class="pine-heat-badge pine-heat-badge--' +
        tier +
        '" role="button" tabindex="0" title="Click to zoom to this field">' +
        '<span class="pine-heat-badge-name">' +
        escapeHtml(name) +
        '</span>' +
        '<span class="pine-heat-badge-count">' +
        String(count) +
        '</span></div>',
      iconSize: [2, 2],
      iconAnchor: [1, 1],
    });
  }

  /** Push field name labels apart slightly in screen space; keep them near the field (strict clamp). */
  function layoutFieldLabelMarkers() {
    if (!pineMap.map || !pineMap.fieldLabelLayer) return;
    const map = pineMap.map;
    const items = [];
    pineMap.fieldLabelLayer.eachLayer(function (layer) {
      if (!(layer instanceof L.Marker)) return;
      if (!layer._pineFieldLabelAnchor) return;
      const anchor = map.latLngToContainerPoint(layer._pineFieldLabelAnchor);
      const ang = layer._pineFieldLabelAngle != null ? layer._pineFieldLabelAngle : 0;
      const r0 = 2;
      const pos = L.point(anchor.x + Math.cos(ang) * r0, anchor.y + Math.sin(ang) * r0);
      items.push({
        marker: layer,
        anchor: anchor,
        pos: pos,
        r: fieldLabelCollisionRadiusPx(layer._pineFieldLabelText, layer._pineFieldLabelWide),
      });
    });
    const n = items.length;
    if (!n) return;
    const pad = 5;
    const iters = 12;
    const z = map.getZoom();
    // Cap screen drift from centroid (tighter than before); separation still uses pad/iters to limit overlap.
    const maxShift = z >= 17 ? 24 : z >= 15 ? 28 : z >= 13 ? 34 : 40;
    for (let iter = 0; iter < iters; iter++) {
      for (let i = 0; i < n; i++) {
        for (let j = i + 1; j < n; j++) {
          const a = items[i];
          const b = items[j];
          let dx = b.pos.x - a.pos.x;
          let dy = b.pos.y - a.pos.y;
          const dist = Math.sqrt(dx * dx + dy * dy) || 0.0001;
          const need = a.r + b.r + pad - dist;
          if (need <= 0) continue;
          dx /= dist;
          dy /= dist;
          const half = need * 0.45;
          // Prefer sideways separation so labels stay nearer the field centroid vertically.
          const vx = dx * half * 1.08;
          const vy = dy * half * 0.92;
          a.pos.x -= vx;
          a.pos.y -= vy;
          b.pos.x += vx;
          b.pos.y += vy;
        }
      }
    }
    for (let k = 0; k < n; k++) {
      const it = items[k];
      let dx = it.pos.x - it.anchor.x;
      let dy = it.pos.y - it.anchor.y;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d > maxShift && d > 0) {
        const s = maxShift / d;
        it.pos.x = it.anchor.x + dx * s;
        it.pos.y = it.anchor.y + dy * s;
      }
      it.marker.setLatLng(map.containerPointToLatLng(it.pos));
    }
  }

  function cloneBoundaryForUndo(raw) {
    if (raw == null) return null;
    try {
      return JSON.parse(JSON.stringify(raw));
    } catch (_) {
      return raw;
    }
  }

  function syncGeofenceUndoButton() {
    const btn = $('pine-geofence-undo');
    if (!btn) return;
    const can =
      !!geofenceUndoSnapshot &&
      !!pineMap.editingFieldId &&
      String(geofenceUndoSnapshot.fieldId) === String(pineMap.editingFieldId);
    btn.hidden = !can;
    btn.disabled = !can;
  }

  async function runUndoGeofence() {
    if (!geofenceUndoSnapshot || !pineMap.editingFieldId) return;
    if (String(geofenceUndoSnapshot.fieldId) !== String(pineMap.editingFieldId)) return;
    const btn = $('pine-geofence-undo');
    if (btn instanceof HTMLButtonElement) {
      btn.disabled = true;
    }
    const fid = geofenceUndoSnapshot.fieldId;
    const payload = geofenceUndoSnapshot.boundary_json;
    try {
      const { error } = await supabase
        .from('fields')
        .update({
          boundary_json: payload,
          updated_at: new Date().toISOString(),
        })
        .eq('id', fid);
      if (error) throw error;
      for (let i = 0; i < cacheFields.length; i++) {
        if (String(cacheFields[i].id) === String(fid)) {
          cacheFields[i].boundary_json = payload;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      geofenceUndoSnapshot = null;
      rebuildMapLayers(false, true);
      const st = $('pine-geofence-save-status');
      if (st) {
        st.textContent = 'Undone';
        st.classList.remove('err');
        st.classList.add('ok');
      }
      toast('Geofence restored to the previous version.');
    } catch (err) {
      toast(err && err.message ? err.message : 'Undo failed', true);
    } finally {
      syncGeofenceUndoButton();
    }
  }

  function clearFieldVertexEdit() {
    if (pineMap.editingPolygon && pineMap._geofencePolygonClick) {
      pineMap.editingPolygon.off('click', pineMap._geofencePolygonClick);
      pineMap._geofencePolygonClick = null;
    }
    if (pineMap.vertexGroup && pineMap.map) {
      pineMap.map.removeLayer(pineMap.vertexGroup);
    }
    pineMap.vertexGroup = null;
    pineMap.vertexMarkers = [];
    pineMap.editingFieldId = null;
    pineMap.editingPolygon = null;
    const saveWrap = $('pine-map-geofence-save');
    if (saveWrap) saveWrap.hidden = true;
  }

  function syncPolygonFromVertexMarkers() {
    if (!pineMap.editingPolygon || !pineMap.vertexMarkers.length) return;
    const latlngs = pineMap.vertexMarkers.map(function (m) {
      return m.getLatLng();
    });
    pineMap.editingPolygon.setLatLngs([latlngs]);
  }

  function distanceSqPlanarDeg(latA, lngA, latB, lngB) {
    const dLat = latA - latB;
    const dLng = lngA - lngB;
    return dLat * dLat + dLng * dLng;
  }

  function closestPointOnSegmentPlanar(lat, lng, lat1, lng1, lat2, lng2) {
    const x = lng;
    const y = lat;
    const x1 = lng1;
    const y1 = lat1;
    const x2 = lng2;
    const y2 = lat2;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len2 = dx * dx + dy * dy;
    if (len2 < 1e-18) {
      return { lat: lat1, lng: lng1 };
    }
    let t = ((x - x1) * dx + (y - y1) * dy) / len2;
    t = Math.max(0, Math.min(1, t));
    return { lat: y1 + t * dy, lng: x1 + t * dx };
  }

  function findEdgeForNewVertex(lat, lng, markers) {
    const n = markers.length;
    if (n < 3) return null;
    let bestI = 0;
    let bestDist = Infinity;
    let bestLat = 0;
    let bestLng = 0;
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      const ll1 = markers[i].getLatLng();
      const ll2 = markers[j].getLatLng();
      const p = closestPointOnSegmentPlanar(lat, lng, ll1.lat, ll1.lng, ll2.lat, ll2.lng);
      const d = distanceSqPlanarDeg(lat, lng, p.lat, p.lng);
      if (d < bestDist) {
        bestDist = d;
        bestI = i;
        bestLat = p.lat;
        bestLng = p.lng;
      }
    }
    return { insertAfterIndex: bestI, lat: bestLat, lng: bestLng };
  }

  function makeGeofenceVertexMarker(latlng) {
    const vertexIcon = L.divIcon({
      className: 'pine-vertex-marker',
      iconSize: [12, 12],
      iconAnchor: [6, 6],
    });
    const marker = L.marker(latlng, {
      draggable: true,
      icon: vertexIcon,
      zIndexOffset: 500,
    });
    marker.on('drag', syncPolygonFromVertexMarkers);
    marker.on('dragend', function () {
      schedulePersistGeofence();
    });
    return marker;
  }

  function insertGeofenceVertexAfter(insertAfterIndex, latlng) {
    if (!pineMap.vertexGroup || !pineMap.editingPolygon) return;
    const marker = makeGeofenceVertexMarker(latlng);
    marker.addTo(pineMap.vertexGroup);
    pineMap.vertexMarkers.splice(insertAfterIndex + 1, 0, marker);
    syncPolygonFromVertexMarkers();
    schedulePersistGeofence();
  }

  function onGeofencePolygonClickInsertVertex(e) {
    if (!pineMap.editingPolygon || pineMap.vertexMarkers.length < 3) return;
    const ll = e.latlng;
    const lat = ll.lat;
    const lng = ll.lng;
    const found = findEdgeForNewVertex(lat, lng, pineMap.vertexMarkers);
    if (!found) return;
    // Only reject if the snapped point on the chosen edge is essentially on top of one of
    // *that edge's* endpoints. The old check used the raw click vs all vertices: clicks
    // near any corner (common on short edges or zoomed out) were ignored even when the
    // user clearly clicked an edge to add a vertex.
    const n = pineMap.vertexMarkers.length;
    const i = found.insertAfterIndex;
    const j = (i + 1) % n;
    const e1 = pineMap.vertexMarkers[i].getLatLng();
    const e2 = pineMap.vertexMarkers[j].getLatLng();
    const segLen2 = distanceSqPlanarDeg(e1.lat, e1.lng, e2.lat, e2.lng);
    const eps = Math.max(1e-16, segLen2 * 1e-8);
    const d1 = distanceSqPlanarDeg(found.lat, found.lng, e1.lat, e1.lng);
    const d2 = distanceSqPlanarDeg(found.lat, found.lng, e2.lat, e2.lng);
    if (d1 <= eps || d2 <= eps) {
      return;
    }
    L.DomEvent.stopPropagation(e);
    insertGeofenceVertexAfter(found.insertAfterIndex, L.latLng(found.lat, found.lng));
  }

  function setupFieldVertexEditing(fieldId, polygon, ring) {
    if (!sessionIsFullAdmin) return;
    if (!pineMap.map || !polygon || !ring || ring.length < 3) return;
    clearFieldVertexEdit();
    pineMap.editingFieldId = fieldId;
    pineMap.editingPolygon = polygon;
    pineMap.vertexGroup = L.layerGroup().addTo(pineMap.map);
    pineMap.vertexMarkers = [];

    let pts = ring.map(function (p) {
      return [Number(p[0]), Number(p[1])];
    });
    if (
      pts.length > 1 &&
      pts[0][0] === pts[pts.length - 1][0] &&
      pts[0][1] === pts[pts.length - 1][1]
    ) {
      pts = pts.slice(0, -1);
    }
    if (pts.length < 3) return;

    for (let i = 0; i < pts.length; i++) {
      const marker = makeGeofenceVertexMarker(L.latLng(pts[i][0], pts[i][1]));
      marker.addTo(pineMap.vertexGroup);
      pineMap.vertexMarkers.push(marker);
    }

    pineMap._geofencePolygonClick = onGeofencePolygonClickInsertVertex;
    polygon.on('click', pineMap._geofencePolygonClick);

    const saveWrap = $('pine-map-geofence-save');
    if (saveWrap) saveWrap.hidden = false;
    const st = $('pine-geofence-save-status');
    if (st) {
      st.textContent = '';
      st.classList.remove('ok', 'err');
    }
    syncGeofenceUndoButton();
  }

  function buildFieldPopupHtml(f) {
    const userOpts = cacheProfiles
      .map(function (p) {
        const sel = f.user_id === p.id ? ' selected' : '';
        return (
          '<option value="' +
          escapeHtml(String(p.id)) +
          '"' +
          sel +
          '>' +
          escapeHtml(profileDisplayName(p.id)) +
          '</option>'
        );
      })
      .join('');
    const prev =
      f.preview_image_path != null && String(f.preview_image_path).trim() !== ''
        ? '<br><a href="' +
          escapeHtml(f.preview_image_path) +
          '" target="_blank" rel="noopener">Current preview</a>'
        : '';
    const ownerBlock = sessionIsFullAdmin
      ? '<label class="pine-label">Owner account</label>' +
        '<select class="pine-input pine-map-popup-select" data-field-popup-owner="' +
        escapeHtml(String(f.id)) +
        '">' +
        userOpts +
        '</select>' +
        '<p class="pine-popup-autosave-hint">Owner and preview save automatically.</p>' +
        '<label class="pine-label">Preview image</label>' +
        '<input type="file" accept="image/*" class="pine-input" data-field-preview-file="' +
        escapeHtml(String(f.id)) +
        '" />' +
        '<div class="pine-save-status" data-field-preview-status="' +
        escapeHtml(String(f.id)) +
        '"></div>'
      : '<p class="pine-muted">Owner: <strong>' +
        escapeHtml(profileDisplayName(f.user_id)) +
        '</strong></p>';
    return (
      '<div class="pine-field-popup">' +
      '<strong>' +
      escapeHtml(f.name || 'Field') +
      '</strong><br><span class="pine-mono" style="font-size:11px">' +
      escapeHtml(String(f.id)) +
      '</span><br>' +
      escapeHtml(f.address || '') +
      prev +
      ownerBlock +
      '</div>'
    );
  }

  function bugCountFromDetection(d) {
    if (d == null || d.count == null) return 0;
    const n = Number(d.count);
    return Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 0;
  }

  function confidencePctFromDetection(d) {
    if (d == null || d.confidence == null) return 0;
    const x = Number(d.confidence);
    if (!Number.isFinite(x)) return 0;
    if (x >= 0 && x <= 1) return Math.round(x * 100);
    return Math.max(0, Math.min(100, Math.round(x)));
  }

  /** Same curve as Flutter [severity01] (lib/utils/severity_score.dart). */
  function detectionSeverity01(d) {
    const b = bugCountFromDetection(d);
    const c = confidencePctFromDetection(d);
    const raw = b * (c / 100);
    if (raw <= 0) return 0;
    return Math.min(1, 1 - Math.exp(-raw / 8));
  }

  /**
   * Discrete green → yellow → orange → red by severity, matching Flutter
   * [severityColor] (lib/utils/severity_score.dart).
   */
  function severityDiscreteRgb(s) {
    const v = Math.max(0, Math.min(1, s));
    if (v < 0.25) return { r: 0x2e, g: 0xcc, b: 0x71 }; // green
    if (v < 0.55) return { r: 0xf1, g: 0xc4, b: 0x0f }; // yellow
    if (v < 0.8) return { r: 0xf3, g: 0x9c, b: 0x12 }; // orange
    return { r: 0xe7, g: 0x4c, b: 0x3c }; // red
  }

  function hexagonSvgPoints(r) {
    const parts = [];
    for (let i = 0; i < 6; i++) {
      const a = (Math.PI / 3) * i - Math.PI / 2;
      parts.push(r * Math.cos(a) + ',' + r * Math.sin(a));
    }
    return parts.join(' ');
  }

  /** Pointy-top hex + pin; hue from discrete severity (green / yellow / orange / red). */
  function makeCaptureIcon(selected, d) {
    const sev = detectionSeverity01(d);
    const rgb = severityDiscreteRgb(sev);
    const rgbStr = rgb.r + ',' + rgb.g + ',' + rgb.b;
    const fillInner = 'rgba(' + rgbStr + ',0.4)';
    const strokeSolid = 'rgb(' + rgbStr + ')';
    const pinFill = strokeSolid;
    // Smaller pins so field fences remain visible underneath.
    const rOut = 18;
    const rIn = 18 * 0.66;
    const selClass = selected ? ' pine-capture-hex-wrap--selected' : '';
    const px = selected ? 32 : 28;
    const a = Math.round(px / 2);
    const html =
      '<div class="pine-capture-hex-wrap' +
      selClass +
      '">' +
      '<svg class="pine-capture-hex-svg" viewBox="-24 -24 48 48" width="' +
      px +
      '" height="' +
      px +
      '" aria-hidden="true">' +
      '<polygon points="' +
      hexagonSvgPoints(rIn) +
      '" fill="' +
      fillInner +
      '"/>' +
      '<polygon points="' +
      hexagonSvgPoints(rOut) +
      '" fill="none" stroke="rgba(20,24,40,0.88)" stroke-width="4.2" stroke-linejoin="round" />' +
      '<polygon class="pine-capture-hex-outer" points="' +
      hexagonSvgPoints(rOut) +
      '" fill="none" stroke="' +
      strokeSolid +
      '" stroke-width="2.85" stroke-linejoin="round"/>' +
      '<path d="M0,-6.2c2.9,0 5.2,2.3 5.2,5.1 0,3.7-5.2,9.9-5.2,9.9S-5.2,2.6-5.2,-1.1c0-2.8 2.3-5.1 5.2-5.1z" fill="' +
      pinFill +
      '" stroke="rgba(20,24,40,0.9)" stroke-width="1.1" stroke-linejoin="round" paint-order="stroke fill"/>' +
      '</svg></div>';
    return L.divIcon({
      className: 'pine-capture-divicon',
      html: html,
      iconSize: [px, px],
      iconAnchor: [a, a],
    });
  }

  function makeAccountIcon() {
    return L.divIcon({
      className: 'pine-account-divicon',
      html: '<div class="pine-account-dot"></div>',
      iconSize: [22, 22],
      iconAnchor: [11, 11],
    });
  }

  let bulkFieldSilent = false;
  let bulkUserSilent = false;

  function updateBulkBar() {
    const bar = $('capture-bulk-bar');
    const countEl = $('capture-bulk-count');
    const sel = $('capture-bulk-field');
    const userSel = $('capture-bulk-user');
    const n = selectedDetIds.size;
    if (bar) bar.hidden = n === 0;
    if (countEl) countEl.textContent = n === 1 ? '1 selected' : n + ' selected';
    if (sel && n > 0) {
      const opts =
        '<option value="">— none —</option>' +
        cacheFields
          .slice()
          .sort(function (a, b) {
            return (a.name || '').localeCompare(b.name || '');
          })
          .map(function (f) {
            return (
              '<option value="' +
              escapeHtml(String(f.id)) +
              '">' +
              escapeHtml(f.name || 'Field') +
              '</option>'
            );
          })
          .join('');
      const prev = sel.value;
      bulkFieldSilent = true;
      try {
        sel.innerHTML = opts;
        sel.value = prev && [...sel.options].some(function (o) {
          return o.value === prev;
        })
          ? prev
          : '';
      } finally {
        bulkFieldSilent = false;
      }
    }
    const moveBtn = $('capture-bulk-move');
    if (moveBtn) {
      const canMove =
        n > 0 &&
        sel &&
        sel instanceof HTMLSelectElement &&
        sel.value.trim() !== '';
      moveBtn.disabled = !canMove;
    }
    if (userSel && n > 0) {
      const prevU = userSel.value;
      const uopts =
        '<option value="">— choose account —</option>' +
        cacheProfiles
          .slice()
          .sort(function (a, b) {
            return profileDisplayName(a.id).localeCompare(profileDisplayName(b.id));
          })
          .map(function (p) {
            return (
              '<option value="' +
              escapeHtml(String(p.id)) +
              '">' +
              escapeHtml(profileDisplayName(p.id)) +
              '</option>'
            );
          })
          .join('');
      bulkUserSilent = true;
      try {
        userSel.innerHTML = uopts;
        userSel.value =
          prevU && [...userSel.options].some(function (o) {
            return o.value === prevU;
          })
            ? prevU
            : '';
      } finally {
        bulkUserSilent = false;
      }
    }
    const assignUserBtn = $('capture-bulk-assign-user');
    if (assignUserBtn) {
      const canAssignUser =
        n > 0 &&
        userSel &&
        userSel instanceof HTMLSelectElement &&
        userSel.value.trim() !== '';
      assignUserBtn.disabled = !canAssignUser;
    }
    const assignFieldBtn = $('capture-bulk-assign-field');
    if (assignFieldBtn) {
      assignFieldBtn.disabled = n === 0;
    }
  }

  function toggleCaptureSelection(detId, mk) {
    if (selectedDetIds.has(detId)) {
      selectedDetIds.delete(detId);
    } else {
      selectedDetIds.add(detId);
    }
    const on = selectedDetIds.has(detId);
    const det = mk._pineDet || cacheDetections.find(function (x) {
      return String(x.id) === String(detId);
    });
    mk.setIcon(makeCaptureIcon(on, det || {}));
    mk.setZIndexOffset(on ? 400 : 300);
    updateBulkBar();
  }

  function clearCaptureSelection() {
    selectedDetIds.clear();
    if (pineMap.captureGroup) {
      pineMap.captureGroup.eachLayer(function (layer) {
        if (layer._pineDetId) {
          const det = layer._pineDet || cacheDetections.find(function (x) {
            return String(x.id) === String(layer._pineDetId);
          });
          layer.setIcon(makeCaptureIcon(false, det || {}));
          layer.setZIndexOffset(300);
        }
      });
    }
    updateBulkBar();
  }

  function buildExpertReplyHtml(detId, d, variant) {
    if (!detectionIsPositive(d)) return '';
    const resp = expertResponseForDetection(detId);
    const replyText = resp && resp.strategy_text ? String(resp.strategy_text) : '';
    const id = escapeHtml(String(detId));
    const boxClass =
      variant === 'drawer'
        ? 'pine-reply-box pine-reply-box--drawer'
        : 'pine-reply-box pine-reply-box--popup';
    return (
      '<div class="' +
      boxClass +
      '">' +
      '<label class="pine-reply-label" for="pine-reply-text-' +
      id +
      '">DA/OMAG advice</label>' +
      '<textarea class="pine-input" id="pine-reply-text-' +
      id +
      '" data-expert-reply-text="' +
      id +
      '" placeholder="Treatment advice or next steps for the farmer…" rows="3">' +
      escapeHtml(replyText) +
      '</textarea>' +
      '<div class="pine-reply-actions-row">' +
      '<select class="pine-input pine-reply-action-select" data-expert-reply-action="' +
      id +
      '" aria-label="Recommended action">' +
      '<option value="">Action type</option>' +
      '<option value="monitor"' +
      (resp && resp.action_type === 'monitor' ? ' selected' : '') +
      '>Monitor</option>' +
      '<option value="treat"' +
      (resp && resp.action_type === 'treat' ? ' selected' : '') +
      '>Treat</option>' +
      '<option value="inspect"' +
      (resp && resp.action_type === 'inspect' ? ' selected' : '') +
      '>Inspect</option></select>' +
      '<button type="button" class="pine-btn pine-btn-primary pine-btn--sm" data-expert-reply-save="' +
      id +
      '">Save advice</button></div>' +
      '<div class="pine-save-status pine-save-status--compact" data-expert-reply-status="' +
      id +
      '"></div></div>'
    );
  }

  function reportHasExpertReply(detId) {
    const resp = expertResponseForDetection(detId);
    return !!(resp && resp.strategy_text && String(resp.strategy_text).trim());
  }

  function buildReportThumbHtml(imageUrl, detId) {
    const url = imageUrl != null ? String(imageUrl).trim() : '';
    if (!url) {
      return (
        '<div class="pine-report-thumb pine-report-thumb--empty" aria-hidden="true">' +
        '<span>No image</span></div>'
      );
    }
    const safe = escapeHtml(url);
    const id = escapeHtml(String(detId));
    return (
      '<a class="pine-report-thumb" href="' +
      safe +
      '" target="_blank" rel="noopener" title="Open full image">' +
      '<img src="' +
      safe +
      '" alt="Field capture" loading="lazy" data-report-thumb="' +
      id +
      '" />' +
      '<span class="pine-report-thumb-zoom">View</span></a>'
    );
  }

  function buildReportCardHtml(d) {
    const idRaw = String(d.id);
    const id = escapeHtml(idRaw);
    const latN = d.latitude == null ? NaN : Number(d.latitude);
    const lngN = d.longitude == null ? NaN : Number(d.longitude);
    const hasCoords = Number.isFinite(latN) && Number.isFinite(lngN);
    const fid = d.field_id == null ? '' : String(d.field_id);
    const field = cacheFields.find(function (f) {
      return String(f.id) === fid;
    });
    const fieldName = field ? field.name || 'Field' : fid || 'Unassigned';
    const owner = profileDisplayName(d.user_id);
    const pos = detectionIsPositive(d);
    const replied = pos && reportHasExpertReply(d.id);
    let replyPill = '';
    if (pos) {
      replyPill = replied
        ? '<span class="pine-report-pill pine-report-pill--replied">Replied</span>'
        : '<span class="pine-report-pill pine-report-pill--pending">Needs reply</span>';
    }
    let mapBtn = '';
    if (hasCoords) {
      mapBtn =
        '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-show-det-on-map="' +
        id +
        '" title="Pan map to this report"><span aria-hidden="true">📍</span> Map</button>';
    } else if (fid) {
      mapBtn =
        '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-place-det-in-field="' +
        id +
        '" title="Place inside field boundary"><span aria-hidden="true">📍</span> Place</button>';
    }
    const conf =
      d.confidence == null
        ? ''
        : '<span class="pine-report-stat">' +
          escapeHtml(
            String(
              Number(d.confidence) <= 1
                ? Math.round(Number(d.confidence) * 100)
                : Math.round(Number(d.confidence))
            )
          ) +
          '% conf.</span>';
    const adviceBlock = pos
      ? '<div class="pine-report-advice">' + buildExpertReplyHtml(d.id, d, 'drawer') + '</div>'
      : '';
    const cardMod = pos ? (replied ? ' pine-report-card--replied' : ' pine-report-card--pending') : '';
    return (
      '<article class="pine-report-card' +
      cardMod +
      '" data-report-id="' +
      id +
      '">' +
      '<div class="pine-report-card-main">' +
      buildReportThumbHtml(d.image_url, d.id) +
      '<div class="pine-report-body">' +
      '<div class="pine-report-top-row">' +
      detectionStatusBadgeHtml(d) +
      replyPill +
      '<time class="pine-report-date">' +
      escapeHtml(formatReportDate(d.created_at)) +
      '</time></div>' +
      '<h3 class="pine-report-field">' +
      escapeHtml(fieldName) +
      '</h3>' +
      '<p class="pine-report-farmer">' +
      escapeHtml(owner) +
      '</p>' +
      '<div class="pine-report-stats">' +
      '<span class="pine-report-stat pine-report-stat--count"><strong>' +
      escapeHtml(String(d.count)) +
      '</strong> detected</span>' +
      conf +
      '</div>' +
      '<div class="pine-report-actions">' +
      mapBtn +
      '</div></div></div>' +
      adviceBlock +
      '</article>'
    );
  }

  function buildCapturePopupHtml(d, lat, lng) {
    const img =
      d.image_url != null && String(d.image_url).trim() !== ''
        ? '<br><a href="' +
          escapeHtml(d.image_url) +
          '" target="_blank" rel="noopener">Open image</a>'
        : '';
    const fieldOpts = cacheFields
      .map(function (f) {
        const sel = d.field_id === f.id ? ' selected' : '';
        return (
          '<option value="' +
          escapeHtml(String(f.id)) +
          '"' +
          sel +
          '>' +
          escapeHtml(f.name || 'Field') +
          '</option>'
        );
      })
      .join('');
    const fieldName =
      d.field_id != null
        ? (cacheFields.find(function (f) {
            return f.id === d.field_id;
          }) || {}).name || '—'
        : '— none —';
    const fieldBlock = sessionIsFullAdmin
      ? 'Field<br><select class="pine-input pine-map-popup-select" data-map-det-field="' +
        escapeHtml(String(d.id)) +
        '"><option value="">— none —</option>' +
        fieldOpts +
        '</select>'
      : 'Field: <strong>' + escapeHtml(fieldName) + '</strong>';
    const autosaveHint = sessionIsFullAdmin
      ? '<p class="pine-popup-autosave-hint">Location and field save automatically.</p>'
      : '';
    return (
      '<div class="pine-map-popup">' +
      '<strong>Capture</strong><br>Count: ' +
      escapeHtml(d.count) +
      '<br>' +
      fieldBlock +
      '<br>Lat <code>' +
      escapeHtml(lat.toFixed(7)) +
      '</code><br>Lng <code>' +
      escapeHtml(lng.toFixed(7)) +
      '</code><br><span class="pine-mono" style="font-size:11px">' +
      escapeHtml(String(d.id)) +
      '</span>' +
      img +
      buildExpertReplyHtml(d.id, d) +
      autosaveHint +
      '<div class="pine-save-status" data-map-det-status="' +
      escapeHtml(String(d.id)) +
      '"></div></div>'
    );
  }

  /** Submenu rows for map scope flyout; rebuilt in populateMapScopeUi. */
  const mapScopeSubmenus = {
    unassigned: [],
    fields: [],
    accounts: [],
  };

  let mapScopeUiEventsBound = false;

  /** Field name + optional owner line (avoids "albert · Albert" redundancy). */
  function fieldMapScopeParts(f) {
    if (!f) {
      return { title: 'Field', sub: '' };
    }
    const name =
      f.name != null && String(f.name).trim() ? String(f.name).trim() : 'Field';
    const owner = profileDisplayName(f.user_id);
    if (!owner || name.toLowerCase() === String(owner).toLowerCase()) {
      return { title: name, sub: '' };
    }
    return { title: name, sub: owner };
  }

  function fieldMapScopeSummary(f) {
    const p = fieldMapScopeParts(f);
    return p.sub ? p.title + ' — ' + p.sub : p.title;
  }

  function mapScopeMenuItemButton(it) {
    const v = escapeHtml(it.value);
    const subRaw = it.sublabel != null ? String(it.sublabel).trim() : '';
    const inner = subRaw
      ? '<span class="pine-map-scope-item-lines"><span class="pine-map-scope-item-primary">' +
        escapeHtml(it.label) +
        '</span><span class="pine-map-scope-item-sub">' +
        escapeHtml(subRaw) +
        '</span></span>'
      : escapeHtml(it.label);
    return (
      '<li role="none"><button type="button" class="pine-map-scope-item" data-scope-value="' +
      v +
      '" role="menuitem">' +
      inner +
      '</button></li>'
    );
  }

  function labelForScopeValue(scopeVal) {
    const v = scopeVal == null ? '' : String(scopeVal);
    if (v === 'all') return 'All fields & captures';
    if (v === 'det:null') return 'Unassigned captures';
    if (v.indexOf('field:') === 0) {
      const id = v.slice(6);
      const f = cacheFields.find(function (x) {
        return String(x.id) === id;
      });
      return f ? fieldMapScopeSummary(f) : v;
    }
    if (v.indexOf('user:') === 0) {
      const uid = v.slice(5);
      return 'Account: ' + profileDisplayName(uid);
    }
    return v || 'All fields & captures';
  }

  function syncMapScopeTriggerLabel() {
    const el = $('pine-map-scope-label');
    if (el) {
      el.textContent = labelForScopeValue(mapViewState.scope);
    }
  }

  function mapScopeOptionIsAvailable(scopeVal) {
    const v = String(scopeVal);
    if (v === 'all' || v === 'det:null') return true;
    if (v.indexOf('field:') === 0) {
      return mapScopeSubmenus.fields.some(function (x) {
        return x.value === v;
      });
    }
    if (v.indexOf('user:') === 0) {
      return mapScopeSubmenus.accounts.some(function (x) {
        return x.value === v;
      });
    }
    return false;
  }

  function hideMapScopeSubmenu() {
    const wrap = $('pine-map-scope-submenu-wrap');
    if (wrap) wrap.hidden = true;
  }

  function showMapScopeSubmenu(key) {
    const wrap = $('pine-map-scope-submenu-wrap');
    const sub = $('pine-map-scope-submenu');
    const items = mapScopeSubmenus[key];
    if (!wrap || !sub || !items || !items.length) return;
    sub.innerHTML = items.map(mapScopeMenuItemButton).join('');
    wrap.hidden = false;
    sub.querySelectorAll('[data-scope-value]').forEach(function (btn) {
      btn.classList.toggle(
        'pine-map-scope-item--active',
        btn.getAttribute('data-scope-value') === mapViewState.scope
      );
    });
  }

  function applyMapScope(value) {
    mapViewState.scope = value;
    syncMapScopeTriggerLabel();
    rebuildMapLayers(true);
  }

  function positionMapScopeFlyout() {
    const trigger = $('pine-map-scope-trigger');
    const panel = $('pine-map-scope-panel');
    if (!trigger || !panel) return;
    const r = trigger.getBoundingClientRect();
    const gap = 8;
    const estW = 300;
    let left = Math.round(r.right + gap);
    let top = Math.round(r.top);
    if (left + estW > window.innerWidth - 10) {
      left = Math.max(10, Math.round(r.left - estW - gap));
    }
    if (top < 8) {
      top = 8;
    }
    panel.style.left = left + 'px';
    panel.style.top = top + 'px';
  }

  function bindMapScopeUiEvents() {
    if (mapScopeUiEventsBound) return;
    mapScopeUiEventsBound = true;
    const widget = $('pine-map-scope-widget');
    const panel = $('pine-map-scope-panel');
    const trigger = $('pine-map-scope-trigger');
    const menu = $('pine-map-scope-menu');
    if (!widget || !panel || !trigger || !menu) return;

    const scrollHost = document.querySelector('.pine-map-sidebar-scroll');
    function onScrollOrResize() {
      positionMapScopeFlyout();
    }
    window.addEventListener('resize', onScrollOrResize);
    if (scrollHost) {
      scrollHost.addEventListener('scroll', onScrollOrResize, { passive: true });
    }

    widget.addEventListener('mouseenter', function () {
      positionMapScopeFlyout();
    });

    trigger.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      const open = widget.classList.toggle('pine-map-scope-widget--open');
      trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
      if (open) {
        requestAnimationFrame(function () {
          positionMapScopeFlyout();
        });
      } else {
        hideMapScopeSubmenu();
      }
    });

    panel.addEventListener('mouseover', function (ev) {
      const cat = ev.target.closest('.pine-map-scope-cat');
      if (cat && menu.contains(cat)) {
        const key = cat.getAttribute('data-submenu');
        if (key) showMapScopeSubmenu(key);
        return;
      }
      if (ev.target.closest('.pine-map-scope-menu .pine-map-scope-item')) {
        hideMapScopeSubmenu();
      }
    });

    widget.addEventListener('click', function (ev) {
      const btn = ev.target.closest('[data-scope-value]');
      if (!btn || !widget.contains(btn)) return;
      const v = btn.getAttribute('data-scope-value');
      if (!v) return;
      ev.preventDefault();
      applyMapScope(v);
      widget.classList.remove('pine-map-scope-widget--open');
      trigger.setAttribute('aria-expanded', 'false');
      hideMapScopeSubmenu();
    });

    widget.addEventListener('mouseleave', function () {
      hideMapScopeSubmenu();
    });

    document.addEventListener('click', function (ev) {
      const t = ev.target;
      if (!(t instanceof Node)) return;
      if (!widget.contains(t)) {
        widget.classList.remove('pine-map-scope-widget--open');
        trigger.setAttribute('aria-expanded', 'false');
        hideMapScopeSubmenu();
      }
    });

    document.addEventListener('keydown', function (ev) {
      if (ev.key !== 'Escape') return;
      if (!widget.classList.contains('pine-map-scope-widget--open')) return;
      widget.classList.remove('pine-map-scope-widget--open');
      trigger.setAttribute('aria-expanded', 'false');
      hideMapScopeSubmenu();
    });
  }

  function populateMapScopeUi() {
    const menu = $('pine-map-scope-menu');
    if (!menu) return;
    const prev = mapViewState.scope;
    mapScopeSubmenus.unassigned = [{ value: 'det:null', label: 'Captures without a field' }];
    mapScopeSubmenus.fields = cacheFields
      .slice()
      .sort(function (a, b) {
        return (a.name || '').localeCompare(b.name || '');
      })
      .map(function (f) {
        const parts = fieldMapScopeParts(f);
        return {
          value: 'field:' + String(f.id),
          label: parts.title,
          sublabel: parts.sub,
        };
      });
    const userIdSet = new Set();
    let i;
    for (i = 0; i < cacheProfiles.length; i++) {
      userIdSet.add(cacheProfiles[i].id);
    }
    for (i = 0; i < cacheFields.length; i++) {
      userIdSet.add(cacheFields[i].user_id);
    }
    const userIds = Array.from(userIdSet).filter(Boolean);
    userIds.sort(function (a, b) {
      return profileDisplayName(a).localeCompare(profileDisplayName(b));
    });
    mapScopeSubmenus.accounts = userIds.map(function (uid) {
      return {
        value: 'user:' + String(uid),
        label: profileDisplayName(uid),
      };
    });

    menu.innerHTML =
      '<li role="none"><button type="button" class="pine-map-scope-item" data-scope-value="all" role="menuitem">All fields &amp; captures</button></li>' +
      '<li role="none" class="pine-map-scope-cat" data-submenu="unassigned"><span class="pine-map-scope-cat-label">Unassigned captures</span><span class="pine-map-scope-cat-arrow" aria-hidden="true">›</span></li>' +
      '<li role="none" class="pine-map-scope-cat" data-submenu="fields"><span class="pine-map-scope-cat-label">By field</span><span class="pine-map-scope-cat-arrow" aria-hidden="true">›</span></li>' +
      '<li role="none" class="pine-map-scope-cat" data-submenu="accounts"><span class="pine-map-scope-cat-label">By account</span><span class="pine-map-scope-cat-arrow" aria-hidden="true">›</span></li>';

    if (!mapScopeOptionIsAvailable(prev)) {
      mapViewState.scope = 'all';
    }
    syncMapScopeTriggerLabel();
    bindMapScopeUiEvents();
    hideMapScopeSubmenu();
    requestAnimationFrame(function () {
      positionMapScopeFlyout();
    });
  }

  /**
   * @param {boolean} [animateCamera] When true (e.g. Map focus dropdown changed), use flyTo / flyToBounds instead of jumping.
   * @param {boolean} [preserveView] When true, skip pan/zoom so the user’s viewport stays fixed (e.g. geofence autosave after dragging a vertex).
   */
  function rebuildMapLayers(animateCamera, preserveView) {
    if (!pineMap.map || !pineMap.fieldGroup || !pineMap.fieldLabelLayer || !pineMap.captureGroup || !pineMap.userGroup) {
      return;
    }
    const animate = animateCamera === true;
    const keepView = preserveView === true;
    clearFieldVertexEdit();
    if (geofenceUndoSnapshot) {
      const scopedField =
        mapViewState.scope.indexOf('field:') === 0 ? String(mapViewState.scope.slice(6)) : null;
      if (!scopedField || scopedField !== String(geofenceUndoSnapshot.fieldId)) {
        geofenceUndoSnapshot = null;
      }
    }
    pineMap.fieldGroup.clearLayers();
    pineMap.fieldLabelLayer.clearLayers();
    pineMap.captureGroup.clearLayers();
    pineMap.userGroup.clearLayers();

    if (mapViewState.multiSelectMode && !mapViewState.showCaptures) {
      mapViewState.showCaptures = true;
      const capChip = document.querySelector('[data-map-layer="captures"]');
      if (capChip) {
        capChip.classList.remove('pine-layer-chip-off');
        capChip.setAttribute('aria-pressed', 'true');
      }
    }

    const viewBounds = (function () {
      try {
        // Pad so pins don't pop in/out aggressively near edges.
        return pineMap.map.getBounds().pad(0.25);
      } catch (_) {
        return null;
      }
    })();

    const scope = mapViewState.scope;
    let fieldFilter;
    let detFilter;

    if (scope === 'all') {
      fieldFilter = function () {
        return true;
      };
      detFilter = function () {
        return true;
      };
    } else if (scope === 'det:null') {
      fieldFilter = function () {
        return true;
      };
      detFilter = function (d) {
        return d.field_id == null || String(d.field_id).trim() === '';
      };
    } else if (scope.indexOf('field:') === 0) {
      const id = scope.slice(6);
      fieldFilter = function (f) {
        return f.id === id;
      };
      detFilter = function (d) {
        return d.field_id === id;
      };
    } else if (scope.indexOf('user:') === 0) {
      const uid = scope.slice(5);
      const fieldIdsForUser = new Set();
      for (let fi = 0; fi < cacheFields.length; fi++) {
        if (String(cacheFields[fi].user_id) === uid) {
          fieldIdsForUser.add(String(cacheFields[fi].id));
        }
      }
      fieldFilter = function (f) {
        return String(f.user_id) === uid;
      };
      // Show captures uploaded by this account and captures placed on their fields
      // (bulk assign / admin moves set field_id but often leave user_id as the uploader).
      detFilter = function (d) {
        if (d.user_id != null && String(d.user_id) === uid) return true;
        if (d.field_id != null && fieldIdsForUser.has(String(d.field_id))) return true;
        return false;
      };
    } else {
      fieldFilter = function () {
        return true;
      };
      detFilter = function () {
        return true;
      };
    }

    const bounds = [];
    let pendingFieldEdit = null;
    const renderedDetIds = new Set();

    let mapZoom = MAP_PIN_ZOOM_THRESHOLD;
    try {
      if (pineMap.map) {
        mapZoom = pineMap.map.getZoom();
      }
    } catch (_) {
      /* ignore */
    }
    const showCapturePins = mapZoom >= MAP_PIN_ZOOM_THRESHOLD;
    const showFieldHeatmap = mapZoom < MAP_PIN_ZOOM_THRESHOLD;
    const posByField = positiveCountByFieldId();
    let maxPosField = 0;
    for (const k in posByField) {
      if (posByField[k] > maxPosField) {
        maxPosField = posByField[k];
      }
    }
    if (maxPosField < 1) {
      maxPosField = 1;
    }

    for (let fi = 0; fi < cacheFields.length; fi++) {
      const f = cacheFields[fi];
      if (!fieldFilter(f)) continue;
      const rings = parseBoundaryLatLngs(f.boundary_json);
      if (!rings) continue;
      const stroke = strokeColorForField(f.id);
      const fidStr = String(f.id);
      const posCount = posByField[fidStr] || 0;
      let fillColor = stroke;
      let fillOpacity = 0.18;
      let borderColor = stroke;
      let weight = 1.75;
      if (showFieldHeatmap) {
        if (posCount > 0) {
          const sev = posCount / maxPosField;
          fillColor = heatRgbForSeverity(sev);
          fillOpacity = 0.62 + sev * 0.18;
          borderColor = heatRgbForSeverity(Math.min(1, sev + 0.08));
          weight = 3;
        } else {
          fillColor = 'rgba(255, 255, 255, 0.16)';
          fillOpacity = 0.16;
          borderColor = 'rgba(255, 255, 255, 0.68)';
          weight = 1.75;
        }
      } else if (posCount > 0) {
        fillColor = heatRgbForSeverity(posCount / maxPosField);
        fillOpacity = 0.28;
        borderColor = heatRgbForSeverity(posCount / maxPosField);
        weight = 2.25;
      }
      const poly = L.polygon(rings, {
        color: borderColor,
        weight: weight,
        fillColor: fillColor,
        fillOpacity: fillOpacity,
      });
      poly.bindPopup(buildFieldPopupHtml(f), { maxWidth: 320 });
      poly.addTo(pineMap.fieldGroup);
      const fieldName = (f && typeof f.name === 'string' && f.name.trim()) ? f.name.trim() : 'Field';
      const centroid = ringCentroidLatLng(rings);
      if (centroid && pineMap.fieldLabelLayer) {
        const shouldShowHeatBadge = showFieldHeatmap && posCount > 0;
        const shouldShowNameLabel = !showFieldHeatmap && posCount > 0;
        if (shouldShowHeatBadge || shouldShowNameLabel) {
          const sev = posCount / maxPosField;
          const lm = L.marker(centroid, {
            icon: shouldShowHeatBadge
                ? makeHeatFieldBadgeIcon(fieldName, posCount, sev)
                : makeFieldLabelDivIcon(fieldName, {
                    positiveCount: posCount,
                    showCount: posCount > 0,
                  }),
            interactive: true,
            keyboard: false,
            zIndexOffset: shouldShowHeatBadge ? 700 : 650,
          });
          lm._pineFieldLabelAnchor = L.latLng(centroid.lat, centroid.lng);
          lm._pineFieldLabelText = fieldName;
          lm._pineFieldLabelWide = shouldShowHeatBadge;
          lm._pineFieldLabelAngle = fieldIdToLabelJitterAngle(fidStr);
          lm._pineFieldId = fidStr;
          lm.on('click', function (ev) {
            L.DomEvent.stopPropagation(ev);
            flyMapToFieldFence(fidStr);
          });
          lm.addTo(pineMap.fieldLabelLayer);
        }
      }
      for (let j = 0; j < rings.length; j++) {
        bounds.push(rings[j]);
      }
      if (scope.indexOf('field:') === 0 && scope.slice(6) === f.id) {
        pendingFieldEdit = {
          fieldId: f.id,
          polygon: poly,
          ring: rings.map(function (p) {
            return [Number(p[0]), Number(p[1])];
          }),
        };
      }
    }

    for (let di = 0; di < cacheDetections.length; di++) {
      const d = cacheDetections[di];
      if (!detFilter(d)) continue;
      if (!detectionIsPositive(d)) continue;
      if (!showCapturePins) continue;
      if (d.latitude == null || d.longitude == null) continue;
      const lat = Number(d.latitude);
      const lng = Number(d.longitude);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
      if (viewBounds && !viewBounds.contains([lat, lng])) continue;
      if (renderedDetIds.size >= MAP_VIEW_DETECTIONS_MAX) break;
      renderedDetIds.add(d.id);
      const isSel = selectedDetIds.has(d.id);
      const mk = L.marker([lat, lng], {
        draggable: sessionIsFullAdmin,
        icon: makeCaptureIcon(isSel, d),
        zIndexOffset: isSel ? 400 : 300,
      });
      mk._pineDetId = d.id;
      mk._pineDet = d;
      if (mapViewState.multiSelectMode) {
        mk.on('click', function () {
          toggleCaptureSelection(d.id, mk);
        });
      } else {
        mk.on('click', function (e) {
          const oe = e.originalEvent;
          if (oe && oe.shiftKey) {
            if (typeof oe.stopImmediatePropagation === 'function') {
              oe.stopImmediatePropagation();
            }
            L.DomEvent.stopPropagation(e);
            toggleCaptureSelection(d.id, mk);
            requestAnimationFrame(function () {
              mk.closePopup();
            });
          }
        });
        mk.bindPopup(buildCapturePopupHtml(d, lat, lng), { maxWidth: 300 });
      }
      mk.on('dragend', function () {
        const ll = mk.getLatLng();
        let fieldId = d.field_id;
        const pu = mk.getPopup();
        const popupEl = pu && pu.getElement();
        if (popupEl) {
          const sel = popupEl.querySelector('[data-map-det-field="' + d.id + '"]');
          if (sel instanceof HTMLSelectElement) {
            fieldId = sel.value.trim() || null;
          }
        }
        const merged = Object.assign({}, d, { field_id: fieldId });
        if (!mapViewState.multiSelectMode) {
          mk.setPopupContent(buildCapturePopupHtml(merged, ll.lat, ll.lng));
        }
        schedulePersistCapture(d.id);
      });
      mk.addTo(pineMap.captureGroup);
      bounds.push([lat, lng]);
    }

    const visFields = cacheFields.filter(fieldFilter);
    const visDets = cacheDetections.filter(detFilter);
    if (mapViewState.showAccounts) {
      const uidSet = new Set();
      let ui;
      for (ui = 0; ui < visFields.length; ui++) {
        if (visFields[ui].user_id) {
          uidSet.add(visFields[ui].user_id);
        }
      }
      for (ui = 0; ui < visDets.length; ui++) {
        if (visDets[ui].user_id) {
          uidSet.add(visDets[ui].user_id);
        }
      }
      uidSet.forEach(function (uid) {
        let sumLat = 0;
        let sumLng = 0;
        let n = 0;
        let fi;
        for (fi = 0; fi < visFields.length; fi++) {
          const f = visFields[fi];
          if (f.user_id !== uid) continue;
          const rings = parseBoundaryLatLngs(f.boundary_json);
          if (!rings) continue;
          for (let k = 0; k < rings.length; k++) {
            sumLat += Number(rings[k][0]);
            sumLng += Number(rings[k][1]);
            n++;
          }
        }
        if (n === 0) {
          let di;
          for (di = 0; di < visDets.length; di++) {
            const d = visDets[di];
            if (d.user_id !== uid) continue;
            if (d.latitude == null || d.longitude == null) continue;
            sumLat += Number(d.latitude);
            sumLng += Number(d.longitude);
            n++;
          }
        }
        if (n === 0) return;
        const aLat = sumLat / n;
        const aLng = sumLng / n;
        if (!Number.isFinite(aLat) || !Number.isFinite(aLng)) return;
        const am = L.marker([aLat, aLng], {
          icon: makeAccountIcon(),
          zIndexOffset: 200,
        });
        const prof = cacheProfiles.find(function (x) {
          return x.id === uid;
        });
        const emailLine =
          prof && prof.email
            ? '<br>' + escapeHtml(prof.email)
            : '';
        am.bindPopup(
          '<div class="pine-account-popup"><strong>Account</strong><br>' +
            escapeHtml(profileDisplayName(uid)) +
            emailLine +
            '<br><span class="pine-mono">' +
            escapeHtml(String(uid).slice(0, 8)) +
            '…</span></div>',
          { maxWidth: 280 }
        );
        am.addTo(pineMap.userGroup);
        bounds.push([aLat, aLng]);
      });
    }

    for (const id of Array.from(selectedDetIds)) {
      if (!renderedDetIds.has(id)) {
        selectedDetIds.delete(id);
      }
    }
    updateBulkBar();

    if (!keepView) {
      const fitMax = 19;
      const sidebarCss = getComputedStyle(document.documentElement)
        .getPropertyValue('--pine-sidebar-width')
        .trim();
      const sidebarW = parseInt(sidebarCss, 10) || 236;
      const padTL = L.point(sidebarW + 20, 20);
      const padBR = L.point(28, 28);
      const flyOpts = { duration: 0.95, easeLinearity: 0.28 };
      const fitOpts = {
        paddingTopLeft: padTL,
        paddingBottomRight: padBR,
        maxZoom: fitMax,
      };
      if (bounds.length === 1) {
        const z = Math.min(16, fitMax);
        if (animate) {
          pineMap.map.flyTo(bounds[0], z, flyOpts);
        } else {
          pineMap.map.setView(bounds[0], z);
        }
      } else if (bounds.length > 1) {
        if (animate) {
          pineMap.map.flyToBounds(bounds, Object.assign({}, fitOpts, flyOpts));
        } else {
          pineMap.map.fitBounds(bounds, fitOpts);
        }
      } else {
        if (animate) {
          pineMap.map.flyTo([12.3, 122.5], 5, flyOpts);
        } else {
          pineMap.map.setView([12.3, 122.5], 5);
        }
      }
    }

    if (mapViewState.showFields) {
      pineMap.fieldGroup.addTo(pineMap.map);
      pineMap.fieldLabelLayer.addTo(pineMap.map);
    } else {
      pineMap.map.removeLayer(pineMap.fieldGroup);
      pineMap.map.removeLayer(pineMap.fieldLabelLayer);
    }
    if (mapViewState.showCaptures) {
      pineMap.captureGroup.addTo(pineMap.map);
    } else {
      pineMap.map.removeLayer(pineMap.captureGroup);
    }
    if (mapViewState.showAccounts) {
      pineMap.userGroup.addTo(pineMap.map);
    } else {
      pineMap.map.removeLayer(pineMap.userGroup);
    }

    // Field focus auto-opens vertex editing — but that sets editingFieldId, which
    // blocks box/select drag on the map. Defer vertex handles while those modes are on.
    if (
      sessionIsFullAdmin &&
      pendingFieldEdit &&
      pendingFieldEdit.ring.length >= 3 &&
      !mapViewState.multiSelectMode &&
      !mapViewState.boxSelectMode
    ) {
      setupFieldVertexEditing(
        pendingFieldEdit.fieldId,
        pendingFieldEdit.polygon,
        pendingFieldEdit.ring
      );
    }

    requestAnimationFrame(function () {
      layoutFieldLabelMarkers();
    });
    updateHeatmapLegend(showFieldHeatmap);
  }

  function syncMapSelectionChipUi() {
    const chipSelection = document.querySelector('[data-map-selection-toggle]');
    if (!chipSelection) return;
    const on = mapViewState.multiSelectMode;
    chipSelection.classList.toggle('pine-layer-chip-active', on);
    chipSelection.setAttribute('aria-pressed', on ? 'true' : 'false');
  }

  async function createStarterBoundaryForField(fieldId) {
    if (!requireFullAdmin('Boundary editing')) return false;
    if (!pineMap.map) return false;
    const fid = String(fieldId);
    const c = pineMap.map.getCenter();
    const size = 0.0028;
    const payload = [
      { lat: c.lat + size, lng: c.lng },
      { lat: c.lat - size * 0.55, lng: c.lng - size * 0.95 },
      { lat: c.lat - size * 0.55, lng: c.lng + size * 0.95 },
    ];
    try {
      const { error } = await supabase
        .from('fields')
        .update({
          boundary_json: payload,
          updated_at: new Date().toISOString(),
        })
        .eq('id', fid);
      if (error) throw error;
      for (let i = 0; i < cacheFields.length; i++) {
        if (String(cacheFields[i].id) === fid) {
          cacheFields[i].boundary_json = payload;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      return true;
    } catch (e) {
      toast(e && e.message ? e.message : 'Could not save boundary', true);
      return false;
    }
  }

  /** Map focus → one field, turn off capture Select mode, add starter geofence if missing, open vertex editing. */
  async function focusFieldBoundaryOnMap(fieldId) {
    const fid = String(fieldId);
    if (!pineMap.map) {
      toast('Open the dashboard map first.', true);
      return;
    }
    mapViewState.multiSelectMode = false;
    mapViewState.boxSelectMode = false;
    cancelBoxSelectDrag();
    syncBoxSelectCursorClass();
    syncMapSelectionChipUi();
    mapViewState.scope = 'field:' + fid;
    syncMapScopeTriggerLabel();
    const f = cacheFields.find(function (x) {
      return String(x.id) === fid;
    });
    if (!f) {
      toast('Field not found. Try refreshing.', true);
      return;
    }
    rebuildMapLayers(true);
    let ring = parseBoundaryLatLngs(f.boundary_json);
    if (!ring) {
      const ok = await createStarterBoundaryForField(fid);
      if (!ok) return;
      rebuildMapLayers(true);
      toast('Starter geofence added. Drag the vertex handles on the map; it saves automatically.');
    } else {
      toast('Drag the vertex handles on the map to edit the boundary. It saves automatically.');
    }
  }

  function findCaptureMarkerByDetId(detId) {
    let found = null;
    if (!pineMap.captureGroup) return null;
    pineMap.captureGroup.eachLayer(function (layer) {
      if (layer._pineDetId === detId) {
        found = layer;
      }
    });
    return found;
  }

  function focusDetectionOnMap(detId) {
    const idStr = String(detId);
    const d = cacheDetections.find(function (x) {
      return String(x.id) === idStr;
    });
    if (!d) return;
    if (d.latitude == null || d.longitude == null) return;
    const lat = Number(d.latitude);
    const lng = Number(d.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    if (!pineMap.map) {
      toast('Map is not ready yet.', true);
      return;
    }
    const z = Math.max(pineMap.map.getZoom(), 16);
    pineMap.map.setView([lat, lng], z);
    requestAnimationFrame(function () {
      const mk = findCaptureMarkerByDetId(d.id);
      if (mk) {
        mk.openPopup();
      } else {
        toast(
          'Panned to capture. If you do not see a pin, set Map focus to All or a scope that includes this capture.'
        );
      }
    });
  }

  async function placeDetectionInAssignedField(detId, triggerBtn) {
    const idStr = String(detId);
    const panel = elDrawerContent;
    if (!panel) return;
    const fieldIn = panel.querySelector('[data-det-field="' + idStr + '"]');
    const latIn = panel.querySelector('[data-det-lat="' + idStr + '"]');
    const lngIn = panel.querySelector('[data-det-lng="' + idStr + '"]');
    const st = panel.querySelector('[data-det-status="' + idStr + '"]');
    if (!(fieldIn instanceof HTMLInputElement)) return;
    const field_id = fieldIn.value.trim();
    if (!field_id) {
      toast('Enter a field id for this row first (the field must have a drawn boundary).', true);
      return;
    }
    const field = cacheFields.find(function (f) {
      return String(f.id) === field_id;
    });
    if (!field) {
      toast('Field not found in loaded fields.', true);
      return;
    }
    const ring = parseBoundaryLatLngs(field.boundary_json);
    if (!ring || ring.length < 3) {
      toast('This field has no geofence. Draw a boundary on the map first.', true);
      return;
    }
    const pt = randomPointInPolygon(ring);
    if (!pt) {
      toast('Could not sample a point inside the field boundary.', true);
      return;
    }
    if (triggerBtn instanceof HTMLButtonElement) {
      triggerBtn.disabled = true;
    }
    if (st) {
      st.textContent = '';
      st.classList.remove('ok', 'err');
    }
    try {
      const { error } = await supabase
        .from('detections')
        .update({
          latitude: pt.lat,
          longitude: pt.lng,
          field_id: field_id,
        })
        .eq('id', detId);
      if (error) throw error;
      for (let i = 0; i < cacheDetections.length; i++) {
        if (String(cacheDetections[i].id) === idStr) {
          cacheDetections[i].latitude = pt.lat;
          cacheDetections[i].longitude = pt.lng;
          cacheDetections[i].field_id = field_id;
          break;
        }
      }
      if (latIn instanceof HTMLInputElement) {
        latIn.value = String(pt.lat);
      }
      if (lngIn instanceof HTMLInputElement) {
        lngIn.value = String(pt.lng);
      }
      if (st) {
        st.textContent = 'Placed';
        st.classList.add('ok');
      }
      const row = fieldIn.closest('tr');
      if (row) {
        const mapTd = row.querySelector('.pine-drawer-captures-map-cell');
        if (mapTd) {
          const safeId = escapeHtml(idStr);
          mapTd.innerHTML =
            '<div class="pine-drawer-captures-map-actions">' +
            '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-show-det-on-map="' +
            safeId +
            '" title="Pan map to this capture">Map</button></div>';
        }
      }
      toast('Capture placed inside ' + (field.name || 'field') + '.');
      if (pineMap.map) {
        rebuildMapLayers();
      }
      focusDetectionOnMap(detId);
    } catch (err) {
      if (st) {
        st.textContent = err && err.message ? err.message : 'Failed';
        st.classList.add('err');
      }
      toast(err && err.message ? err.message : 'Failed', true);
    } finally {
      if (triggerBtn instanceof HTMLButtonElement) {
        triggerBtn.disabled = false;
      }
    }
  }

  const capPersistTimers = Object.create(null);
  const capSaveGen = Object.create(null);
  const detRowPersistTimers = Object.create(null);

  async function persistGeofence(toastOnOk) {
    if (!requireFullAdmin('Geofence editing')) return;
    if (!pineMap.editingFieldId || !pineMap.vertexMarkers.length) return;
    const st = $('pine-geofence-save-status');
    if (st) {
      st.textContent = '';
      st.classList.remove('ok', 'err');
    }
    const payload = pineMap.vertexMarkers.map(function (m) {
      const ll = m.getLatLng();
      return { lat: ll.lat, lng: ll.lng };
    });
    if (payload.length < 3) {
      if (st) {
        st.textContent = 'Need 3+ vertices.';
        st.classList.add('err');
      }
      return;
    }
    const sig = JSON.stringify(payload);
    let previousBoundary = null;
    for (let pi = 0; pi < cacheFields.length; pi++) {
      if (String(cacheFields[pi].id) === String(pineMap.editingFieldId)) {
        previousBoundary = cloneBoundaryForUndo(cacheFields[pi].boundary_json);
        break;
      }
    }
    try {
      const { error } = await supabase
        .from('fields')
        .update({
          boundary_json: payload,
          updated_at: new Date().toISOString(),
        })
        .eq('id', pineMap.editingFieldId);
      if (error) throw error;
      const nowSig = JSON.stringify(
        pineMap.vertexMarkers.map(function (m) {
          const ll = m.getLatLng();
          return { lat: ll.lat, lng: ll.lng };
        })
      );
      if (nowSig !== sig) {
        schedulePersistGeofence();
        return;
      }
      for (let i = 0; i < cacheFields.length; i++) {
        if (cacheFields[i].id === pineMap.editingFieldId) {
          cacheFields[i].boundary_json = payload;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      if (st) {
        st.textContent = 'Saved';
        st.classList.add('ok');
      }
      geofenceUndoSnapshot = {
        fieldId: String(pineMap.editingFieldId),
        boundary_json: previousBoundary,
      };
      rebuildMapLayers(false, true);
      syncGeofenceUndoButton();
      if (toastOnOk) {
        toast('Geofence saved.');
      }
    } catch (err) {
      if (st) {
        st.textContent = err && err.message ? err.message : 'Failed';
        st.classList.add('err');
      }
      toast(err && err.message ? err.message : 'Failed', true);
    }
  }

  const schedulePersistGeofence = debounce(function () {
    void persistGeofence(false);
  }, 850);

  function schedulePersistCapture(detId) {
    clearTimeout(capPersistTimers[detId]);
    capPersistTimers[detId] = setTimeout(function () {
      delete capPersistTimers[detId];
      void persistCaptureMarker(detId, { toastOnOk: false });
    }, 550);
  }

  async function persistCaptureMarker(detId, opts) {
    if (!requireFullAdmin('Capture editing')) return;
    opts = opts || {};
    const toastOnOk = opts.toastOnOk !== false;
    const mk = findCaptureMarkerByDetId(detId);
    if (!mk) return;
    capSaveGen[detId] = (capSaveGen[detId] || 0) + 1;
    const gen = capSaveGen[detId];
    const ll = mk.getLatLng();
    let field_id = null;
    let popupEl = null;
    if (typeof mk.isPopupOpen === 'function' && mk.isPopupOpen()) {
      const pu = mk.getPopup();
      const root = pu && pu.getElement ? pu.getElement() : null;
      if (root) {
        popupEl = root.querySelector('.leaflet-popup-content');
      }
    }
    if (popupEl) {
      const sel = popupEl.querySelector('[data-map-det-field="' + detId + '"]');
      if (sel instanceof HTMLSelectElement) {
        field_id = sel.value.trim() || null;
      }
    } else {
      const row = cacheDetections.find(function (x) {
        return x.id === detId;
      });
      if (row) {
        field_id = row.field_id;
      }
    }
    const st = popupEl && popupEl.querySelector('[data-map-det-status="' + detId + '"]');
    if (st) {
      st.textContent = '';
      st.classList.remove('ok', 'err');
    }
    try {
      const { error } = await supabase
        .from('detections')
        .update({ latitude: ll.lat, longitude: ll.lng, field_id })
        .eq('id', detId);
      if (error) throw error;
      if (capSaveGen[detId] !== gen) return;
      for (let i = 0; i < cacheDetections.length; i++) {
        if (cacheDetections[i].id === detId) {
          cacheDetections[i].latitude = ll.lat;
          cacheDetections[i].longitude = ll.lng;
          cacheDetections[i].field_id = field_id;
          break;
        }
      }
      if (st) {
        st.textContent = 'Saved';
        st.classList.add('ok');
      }
      if (toastOnOk) {
        toast('Capture saved.');
      }
    } catch (err) {
      if (capSaveGen[detId] !== gen) return;
      if (st) {
        st.textContent = err && err.message ? err.message : 'Failed';
        st.classList.add('err');
      }
      toast(err && err.message ? err.message : 'Failed', true);
    }
  }

  async function persistFieldOwnerFromPopup(fid, userId) {
    if (!requireFullAdmin('Field owner change')) return;
    try {
      const { error } = await supabase
        .from('fields')
        .update({ user_id: userId, updated_at: new Date().toISOString() })
        .eq('id', fid);
      if (error) throw error;
      for (let i = 0; i < cacheFields.length; i++) {
        if (cacheFields[i].id === fid) {
          cacheFields[i].user_id = userId;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      rebuildMapLayers();
      populateMapScopeUi();
      toast('Field owner updated.');
    } catch (err) {
      toast(err && err.message ? err.message : 'Failed', true);
    }
  }

  async function runFieldPreviewUpload(fid, popup) {
    if (!requireFullAdmin('Field preview upload')) return;
    const inp = popup.querySelector('[data-field-preview-file="' + fid + '"]');
    const st = popup.querySelector('[data-field-preview-status="' + fid + '"]');
    if (!(inp instanceof HTMLInputElement) || !st) return;
    const file = inp.files && inp.files[0];
    if (!file) {
      st.textContent = 'Choose an image file.';
      st.classList.add('err');
      return;
    }
    const sel = popup.querySelector('[data-field-popup-owner="' + fid + '"]');
    let ownerId = null;
    if (sel instanceof HTMLSelectElement) {
      ownerId = sel.value;
    } else {
      const frow = cacheFields.find(function (x) {
        return x.id === fid;
      });
      ownerId = frow ? frow.user_id : null;
    }
    if (!ownerId) {
      st.textContent = 'Could not resolve owner.';
      st.classList.add('err');
      return;
    }
    st.textContent = '';
    st.classList.remove('ok', 'err');
    try {
      const path = ownerId + '/field_previews/' + fid + '.jpg';
      const { error: upErr } = await supabase.storage.from('detections').upload(path, file, {
        upsert: true,
        contentType: file.type || 'image/jpeg',
      });
      if (upErr) throw upErr;
      const pub = supabase.storage.from('detections').getPublicUrl(path);
      const url =
        pub && pub.data && pub.data.publicUrl
          ? pub.data.publicUrl
          : pub && pub.publicUrl
            ? pub.publicUrl
            : '';
      if (!url) throw new Error('No public URL returned');
      const { error: dbErr } = await supabase
        .from('fields')
        .update({ preview_image_path: url, updated_at: new Date().toISOString() })
        .eq('id', fid);
      if (dbErr) throw dbErr;
      for (let i = 0; i < cacheFields.length; i++) {
        if (cacheFields[i].id === fid) {
          cacheFields[i].preview_image_path = url;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      st.textContent = 'Uploaded.';
      st.classList.add('ok');
      toast('Preview image saved.');
      rebuildMapLayers();
      inp.value = '';
    } catch (err) {
      st.textContent = err && err.message ? err.message : 'Upload failed';
      st.classList.add('err');
      toast(err && err.message ? err.message : 'Upload failed', true);
    }
  }

  async function persistDetectionDrawerRow(detId) {
    if (!requireFullAdmin('Detection editing')) return;
    const panel = elDrawerContent;
    if (!panel) return;
    const latIn = panel.querySelector('[data-det-lat="' + detId + '"]');
    const lngIn = panel.querySelector('[data-det-lng="' + detId + '"]');
    const fieldIn = panel.querySelector('[data-det-field="' + detId + '"]');
    const st = panel.querySelector('[data-det-status="' + detId + '"]');
    if (
      !(latIn instanceof HTMLInputElement) ||
      !(lngIn instanceof HTMLInputElement) ||
      !(fieldIn instanceof HTMLInputElement) ||
      !st
    ) {
      return;
    }
    st.textContent = '';
    st.classList.remove('ok', 'err');
    const latStr = latIn.value.trim();
    const lngStr = lngIn.value.trim();
    let latitude = null;
    let longitude = null;
    if (latStr !== '') {
      latitude = Number(latStr);
      if (!Number.isFinite(latitude)) {
        st.textContent = 'Invalid lat';
        st.classList.add('err');
        return;
      }
    }
    if (lngStr !== '') {
      longitude = Number(lngStr);
      if (!Number.isFinite(longitude)) {
        st.textContent = 'Invalid lng';
        st.classList.add('err');
        return;
      }
    }
    if ((latStr === '') !== (lngStr === '')) {
      st.textContent = 'Set both lat and lng or clear both.';
      st.classList.add('err');
      return;
    }
    const field_id = fieldIn.value.trim() === '' ? null : fieldIn.value.trim();
    try {
      const { error } = await supabase
        .from('detections')
        .update({ latitude, longitude, field_id })
        .eq('id', detId);
      if (error) throw error;
      for (let i = 0; i < cacheDetections.length; i++) {
        if (cacheDetections[i].id === detId) {
          cacheDetections[i].latitude = latitude;
          cacheDetections[i].longitude = longitude;
          cacheDetections[i].field_id = field_id;
          break;
        }
      }
      st.textContent = 'Saved';
      st.classList.add('ok');
      if (pineMap.map) {
        rebuildMapLayers();
      }
    } catch (err) {
      st.textContent = err && err.message ? err.message : 'Failed';
      st.classList.add('err');
      toast(err && err.message ? err.message : 'Failed', true);
    }
  }

  function schedulePersistDetectionRow(detId) {
    clearTimeout(detRowPersistTimers[detId]);
    detRowPersistTimers[detId] = setTimeout(function () {
      delete detRowPersistTimers[detId];
      void persistDetectionDrawerRow(detId);
    }, 700);
  }

  async function runBulkAssignUserFromBar() {
    if (!requireFullAdmin('Bulk owner change')) return;
    const userSel = $('capture-bulk-user');
    if (!(userSel instanceof HTMLSelectElement) || selectedDetIds.size === 0) return;
    const user_id = userSel.value.trim();
    if (!user_id) {
      toast('Choose an account.', true);
      return;
    }
    const ids = Array.from(selectedDetIds);
    const label = profileDisplayName(user_id);
    if (
      !confirm(
        'Move ' +
          ids.length +
          ' capture(s) to ' +
          label +
          '?\n\nField assignment will be cleared so you can assign a field owned by that account.'
      )
    ) {
      return;
    }
    const assignBtn = $('capture-bulk-assign-user');
    if (assignBtn instanceof HTMLButtonElement) {
      assignBtn.disabled = true;
    }
    try {
      const results = await Promise.all(
        ids.map(function (id) {
          return supabase
            .from('detections')
            .update({ user_id: user_id, field_id: null })
            .eq('id', id);
        })
      );
      for (let i = 0; i < results.length; i++) {
        if (results[i].error) throw results[i].error;
      }
      for (let j = 0; j < cacheDetections.length; j++) {
        if (selectedDetIds.has(cacheDetections[j].id)) {
          cacheDetections[j].user_id = user_id;
          cacheDetections[j].field_id = null;
        }
      }
      toast('Moved ' + ids.length + ' capture(s) to ' + label + '.');
      rebuildMapLayers();
    } catch (err) {
      toast(err && err.message ? err.message : 'Could not change owner', true);
    } finally {
      if (assignBtn instanceof HTMLButtonElement) {
        assignBtn.disabled = false;
      }
      updateBulkBar();
    }
  }

  async function runBulkAssignFromBar() {
    if (!requireFullAdmin('Bulk field assign')) return;
    const sel = $('capture-bulk-field');
    const assignBtn = $('capture-bulk-assign-field');
    if (!(sel instanceof HTMLSelectElement) || selectedDetIds.size === 0) return;
    const field_id = sel.value.trim() === '' ? null : sel.value.trim();
    const ids = Array.from(selectedDetIds);
    const fieldLabel = field_id
      ? (cacheFields.find(function (f) {
          return String(f.id) === field_id;
        }) || {}).name || 'field'
      : null;
    if (
      !confirm(
        fieldLabel
          ? 'Link ' +
              ids.length +
              ' selected capture(s) to “' +
              fieldLabel +
              '”?\n\nThis changes their field only (not coordinates). Use Move to reposition inside a geofence.'
          : 'Clear field link for ' + ids.length + ' capture(s)?'
      )
    ) {
      return;
    }
    if (assignBtn instanceof HTMLButtonElement) {
      assignBtn.disabled = true;
    }
    try {
      const results = await Promise.all(
        ids.map(function (id) {
          return supabase.from('detections').update({ field_id }).eq('id', id);
        })
      );
      for (let i = 0; i < results.length; i++) {
        if (results[i].error) throw results[i].error;
      }
      for (let j = 0; j < cacheDetections.length; j++) {
        if (selectedDetIds.has(cacheDetections[j].id)) {
          cacheDetections[j].field_id = field_id;
        }
      }
      toast(
        fieldLabel
          ? 'Linked ' + ids.length + ' capture(s) to “' + fieldLabel + '”.'
          : 'Cleared field link on ' + ids.length + ' capture(s).'
      );
      rebuildMapLayers();
    } catch (err) {
      toast(err && err.message ? err.message : 'Bulk update failed', true);
    } finally {
      if (assignBtn instanceof HTMLButtonElement) {
        assignBtn.disabled = false;
      }
      updateBulkBar();
    }
  }

  async function runBulkMoveIntoField() {
    if (!requireFullAdmin('Bulk move')) return;
    const sel = $('capture-bulk-field');
    const moveBtn = $('capture-bulk-move');
    if (!(sel instanceof HTMLSelectElement) || selectedDetIds.size === 0) return;
    const field_id = sel.value.trim();
    if (!field_id) {
      toast('Choose a field first.', true);
      return;
    }
    const field = cacheFields.find(function (f) {
      return String(f.id) === field_id;
    });
    if (!field) {
      toast('Field not found.', true);
      return;
    }
    const ring = parseBoundaryLatLngs(field.boundary_json);
    if (!ring || ring.length < 3) {
      toast('This field has no geofence. Draw a boundary on the map first.', true);
      return;
    }
    const ids = Array.from(selectedDetIds);
    const coords = [];
    for (let i = 0; i < ids.length; i++) {
      const pt = randomPointInPolygon(ring);
      if (!pt) {
        toast('Could not sample a point inside the field boundary.', true);
        return;
      }
      coords.push({ id: ids[i], lat: pt.lat, lng: pt.lng });
    }
    if (moveBtn instanceof HTMLButtonElement) {
      moveBtn.disabled = true;
    }
    try {
      const results = await Promise.all(
        coords.map(function (c) {
          return supabase
            .from('detections')
            .update({
              latitude: c.lat,
              longitude: c.lng,
              field_id: field_id,
            })
            .eq('id', c.id);
        })
      );
      for (let i = 0; i < results.length; i++) {
        if (results[i].error) throw results[i].error;
      }
      for (let j = 0; j < cacheDetections.length; j++) {
        const row = cacheDetections[j];
        if (!selectedDetIds.has(row.id)) continue;
        const hit = coords.find(function (c) {
          return String(c.id) === String(row.id);
        });
        if (hit) {
          row.latitude = hit.lat;
          row.longitude = hit.lng;
          row.field_id = field_id;
        }
      }
      toast('Moved ' + ids.length + ' capture(s) inside ' + (field.name || 'field') + '.');
      rebuildMapLayers();
    } catch (err) {
      toast(err && err.message ? err.message : 'Move failed', true);
    } finally {
      if (moveBtn instanceof HTMLButtonElement) {
        moveBtn.disabled = false;
      }
      updateBulkBar();
    }
  }

  function bindMapControls() {
    if (mapControlsBound) return;
    mapControlsBound = true;

    bindMapScopeUiEvents();

    const chipFields = document.querySelector('[data-map-layer="fields"]');
    const chipCap = document.querySelector('[data-map-layer="captures"]');
    const chipBase = document.querySelector('[data-map-basemap]');

    function syncChip(btn, on) {
      if (!btn) return;
      btn.classList.toggle('pine-layer-chip-off', !on);
      btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    }

    const chipAccounts = document.querySelector('[data-map-layer="accounts"]');
    syncChip(chipFields, mapViewState.showFields);
    syncChip(chipCap, mapViewState.showCaptures);
    syncChip(chipAccounts, mapViewState.showAccounts);

    if (chipFields) {
      chipFields.addEventListener('click', function () {
        mapViewState.showFields = !mapViewState.showFields;
        syncChip(chipFields, mapViewState.showFields);
        if (mapViewState.showFields) {
          pineMap.fieldGroup.addTo(pineMap.map);
          pineMap.fieldLabelLayer.addTo(pineMap.map);
        } else {
          pineMap.map.removeLayer(pineMap.fieldGroup);
          pineMap.map.removeLayer(pineMap.fieldLabelLayer);
        }
      });
    }
    if (chipCap) {
      chipCap.addEventListener('click', function () {
        if (mapViewState.showCaptures && mapViewState.multiSelectMode) {
          toast('Turn off Select before hiding captures.', true);
          return;
        }
        mapViewState.showCaptures = !mapViewState.showCaptures;
        syncChip(chipCap, mapViewState.showCaptures);
        if (mapViewState.showCaptures) {
          pineMap.captureGroup.addTo(pineMap.map);
        } else {
          pineMap.map.removeLayer(pineMap.captureGroup);
        }
      });
    }
    if (chipAccounts) {
      chipAccounts.addEventListener('click', function () {
        mapViewState.showAccounts = !mapViewState.showAccounts;
        syncChip(chipAccounts, mapViewState.showAccounts);
        if (mapViewState.showAccounts) {
          pineMap.userGroup.addTo(pineMap.map);
        } else {
          pineMap.map.removeLayer(pineMap.userGroup);
        }
        rebuildMapLayers();
      });
    }
    if (chipBase && pineMap.satellite && pineMap.street) {
      chipBase.textContent = mapViewState.satellite ? 'Street' : 'Satellite';
      chipBase.addEventListener('click', function () {
        mapViewState.satellite = !mapViewState.satellite;
        pineMap.map.removeLayer(pineMap.satellite);
        pineMap.map.removeLayer(pineMap.street);
        if (mapViewState.satellite) {
          pineMap.satellite.addTo(pineMap.map);
        } else {
          pineMap.street.addTo(pineMap.map);
        }
        chipBase.textContent = mapViewState.satellite ? 'Street' : 'Satellite';
        applyBasemapMaxZoom();
      });
    }

    const chipSelection = document.querySelector('[data-map-selection-toggle]');
    if (chipSelection) {
      syncMapSelectionChipUi();
      chipSelection.addEventListener('click', function () {
        if (!sessionIsFullAdmin) return;
        const next = !mapViewState.multiSelectMode;
        mapViewState.multiSelectMode = next;
        mapViewState.boxSelectMode = false;
        cancelBoxSelectDrag();
        if (next) {
          clearFieldVertexEdit();
          if (!mapViewState.showCaptures && chipCap && pineMap.captureGroup && pineMap.map) {
            mapViewState.showCaptures = true;
            syncChip(chipCap, true);
            pineMap.captureGroup.addTo(pineMap.map);
          }
        }
        syncBoxSelectCursorClass();
        syncMapSelectionChipUi();
        rebuildMapLayers();
      });
    }

    const bulkClear = $('capture-bulk-clear');
    if (bulkClear) {
      bulkClear.addEventListener('click', function () {
        clearCaptureSelection();
      });
    }

    const bulkMove = $('capture-bulk-move');
    if (bulkMove) {
      bulkMove.addEventListener('click', function () {
        void runBulkMoveIntoField();
      });
    }

    const geofenceUndo = $('pine-geofence-undo');
    if (geofenceUndo) {
      geofenceUndo.addEventListener('click', function () {
        void runUndoGeofence();
      });
    }

    const bulkAssignField = $('capture-bulk-assign-field');
    if (bulkAssignField) {
      bulkAssignField.addEventListener('click', function () {
        void runBulkAssignFromBar();
      });
    }

    const bulkAssignUser = $('capture-bulk-assign-user');
    if (bulkAssignUser) {
      bulkAssignUser.addEventListener('click', function () {
        void runBulkAssignUserFromBar();
      });
    }

    const bulkUserSelect = $('capture-bulk-user');
    if (bulkUserSelect) {
      bulkUserSelect.addEventListener('change', function () {
        if (bulkUserSilent) return;
        updateBulkBar();
      });
    }
  }

  function applyBasemapMaxZoom() {
    if (!pineMap.map) return;
    const maxZ = 19;
    pineMap.map.setMaxZoom(maxZ);
    if (pineMap.map.getZoom() > maxZ) {
      pineMap.map.setZoom(maxZ);
    }
  }

  function syncBoxSelectCursorClass() {
    if (!pineMap.map) return;
    const c = pineMap.map.getContainer();
    const allowDragBox = mapViewState.boxSelectMode || mapViewState.multiSelectMode;
    c.classList.toggle('pine-map-box-select-mode', !!allowDragBox);
  }

  function cancelBoxSelectDrag() {
    if (!pineMap.map) {
      boxSelectDrag = null;
      return;
    }
    const map = pineMap.map;
    const mapEl = map.getContainer();
    mapEl.classList.remove('pine-map-box-selecting');
    if (map.dragging && !map.dragging.enabled()) {
      map.dragging.enable();
    }
    if (map.doubleClickZoom && !map.doubleClickZoom.enabled()) {
      map.doubleClickZoom.enable();
    }
    if (pineMap.boxSelectLayer) {
      pineMap.boxSelectLayer.clearLayers();
    }
    boxSelectDrag = null;
    rightButtonMapPan = null;
  }

  function installBoxSelectHandlers() {
    if (!pineMap.map || pineMap._boxSelectInstalled) return;
    pineMap._boxSelectInstalled = true;
    const map = pineMap.map;

    if (!pineMap.boxSelectLayer) {
      pineMap.boxSelectLayer = L.layerGroup().addTo(map);
    }

    L.DomEvent.on(map.getContainer(), 'contextmenu', function (domEv) {
      if (
        (mapViewState.boxSelectMode || mapViewState.multiSelectMode) &&
        !pineMap.editingFieldId
      ) {
        L.DomEvent.preventDefault(domEv);
      }
    });

    function startRightButtonPanIfAllowed(domEv) {
      if (!mapViewState.boxSelectMode && !mapViewState.multiSelectMode) return;
      if (pineMap.editingFieldId) return;
      if (domEv.button !== 2) return;
      const el = domEv.target;
      if (
        el &&
        el.closest &&
        (el.closest('.leaflet-marker-icon') ||
          el.closest('.leaflet-marker-pane .leaflet-interactive') ||
          el.closest('.leaflet-popup') ||
          el.closest('.leaflet-popup-pane'))
      ) {
        return;
      }
      L.DomEvent.preventDefault(domEv);
      L.DomEvent.stopPropagation(domEv);
      rightButtonMapPan = {
        last: map.mouseEventToContainerPoint(domEv),
      };
    }

    map.on('mousedown', function (ev) {
      if (!mapViewState.boxSelectMode && !mapViewState.multiSelectMode) return;
      if (pineMap.editingFieldId) return;
      const oe = ev.originalEvent;
      if (!oe) return;

      if (oe.button === 2) {
        startRightButtonPanIfAllowed(oe);
        return;
      }

      if (oe.button !== 0) return;
      const el = oe.target;
      if (
        el &&
        el.closest &&
        (el.closest('.leaflet-marker-icon') ||
          el.closest('.leaflet-marker-pane .leaflet-interactive') ||
          el.closest('.leaflet-popup') ||
          el.closest('.leaflet-popup-pane'))
      ) {
        return;
      }
      L.DomEvent.stopPropagation(oe);
      cancelBoxSelectDrag();
      rightButtonMapPan = null;
      map.dragging.disable();
      map.doubleClickZoom.disable();
      map.getContainer().classList.add('pine-map-box-selecting');
      boxSelectDrag = {
        startContainer: map.mouseEventToContainerPoint(oe),
        rectLayer: null,
      };
    });

    map.on('pointerdown', function (ev) {
      const oe = ev.originalEvent;
      if (!oe || typeof oe.button !== 'number') return;
      if (oe.pointerType && oe.pointerType !== 'mouse') return;
      if (oe.button === 2) {
        startRightButtonPanIfAllowed(oe);
      }
    });

    map.on('mousemove', function (ev) {
      if (rightButtonMapPan) {
        const oe = ev.originalEvent;
        if (!oe) {
          return;
        }
        const cur = map.mouseEventToContainerPoint(oe);
        const diff = cur.subtract(rightButtonMapPan.last);
        rightButtonMapPan.last = cur;
        map.panBy(L.point(-diff.x, -diff.y), { animate: false });
      }
      if (!boxSelectDrag) return;
      const oe = ev.originalEvent;
      const cur = map.mouseEventToContainerPoint(oe);
      const start = boxSelectDrag.startContainer;
      const ll1 = map.containerPointToLatLng(start);
      const ll2 = map.containerPointToLatLng(cur);
      const b = L.latLngBounds([ll1, ll2]);
      if (boxSelectDrag.rectLayer) {
        pineMap.boxSelectLayer.removeLayer(boxSelectDrag.rectLayer);
      }
      boxSelectDrag.rectLayer = L.rectangle(b, {
        color: '#ffd21f',
        weight: 2,
        dashArray: '6 4',
        fillColor: '#ffd21f',
        fillOpacity: 0.12,
      });
      pineMap.boxSelectLayer.addLayer(boxSelectDrag.rectLayer);
    });

    function finishFromEvent(domEv) {
      if (domEv.button === 2) {
        rightButtonMapPan = null;
      }
      if (!boxSelectDrag || !pineMap.map) return;
      if (domEv.button !== 0) {
        return;
      }
      const cur = map.mouseEventToContainerPoint(domEv);
      const start = boxSelectDrag.startContainer;
      const w = Math.abs(cur.x - start.x);
      const h = Math.abs(cur.y - start.y);
      map.getContainer().classList.remove('pine-map-box-selecting');
      if (map.dragging && !map.dragging.enabled()) {
        map.dragging.enable();
      }
      if (map.doubleClickZoom && !map.doubleClickZoom.enabled()) {
        map.doubleClickZoom.enable();
      }
      if (pineMap.boxSelectLayer) {
        pineMap.boxSelectLayer.clearLayers();
      }
      boxSelectDrag = null;
      if (w < 10 || h < 10) return;
      const ll1 = map.containerPointToLatLng(start);
      const ll2 = map.containerPointToLatLng(cur);
      const bounds = L.latLngBounds([ll1, ll2]);
      if (!pineMap.captureGroup) return;
      let anyInside = false;
      pineMap.captureGroup.eachLayer(function (layer) {
        if (!layer._pineDetId) return;
        const ll = layer.getLatLng();
        if (!bounds.contains(ll)) return;
        anyInside = true;
        if (!selectedDetIds.has(layer._pineDetId)) {
          selectedDetIds.add(layer._pineDetId);
        }
        const det = layer._pineDet || cacheDetections.find(function (x) {
          return String(x.id) === String(layer._pineDetId);
        });
        layer.setIcon(makeCaptureIcon(true, det || {}));
        if (typeof layer.setZIndexOffset === 'function') {
          layer.setZIndexOffset(400);
        }
      });
      if (anyInside) {
        updateBulkBar();
      }
    }

    L.DomEvent.on(document, 'mouseup', finishFromEvent);
  }

  /** Parse "lat, lng" or "lat lng" (decimal degrees). */
  function parseLatLngQuery(raw) {
    const s = String(raw || '').trim();
    if (!s) return null;
    const m = s.match(/^(-?\d+(?:\.\d+)?)\s*[,; ]\s*(-?\d+(?:\.\d+)?)\s*$/);
    if (!m) return null;
    const lat = parseFloat(m[1]);
    const lng = parseFloat(m[2]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return { lat: lat, lng: lng };
  }

  function clearGeocodeMarker() {
    if (pineMap.geocodeMarker && pineMap.map) {
      pineMap.map.removeLayer(pineMap.geocodeMarker);
    }
    pineMap.geocodeMarker = null;
  }

  /**
   * @param {{ lat: number, lng: number, label?: string, boundingbox?: string[], preferFieldFenceFit?: boolean }} place
   */
  function flyMapToPlace(place) {
    if (!pineMap.map || !place) return;
    const lat = place.lat;
    const lng = place.lng;
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    const label = place.label || 'Here';
    clearGeocodeMarker();
    pineMap.geocodeMarker = L.marker([lat, lng], { keyboard: false }).addTo(pineMap.map);
    pineMap.geocodeMarker.bindPopup(escapeHtml(label), { maxWidth: 260 });
    const bb = place.boundingbox;
    const flyOpts = { duration: 0.85, easeLinearity: 0.28 };
    function openPop() {
      if (pineMap.geocodeMarker) pineMap.geocodeMarker.openPopup();
    }
    /** When bbox is huge (municipality/province), fitBounds zooms out too far — jump to the hit at street scale. */
    function bboxMaxSpanDeg(south, north, west, east) {
      return Math.max(Math.abs(north - south), Math.abs(east - west));
    }
    const BBOX_TIGHT_FIT_MAX_DEG = 0.02;
    if (bb && bb.length === 4) {
      const south = parseFloat(bb[0]);
      const north = parseFloat(bb[1]);
      const west = parseFloat(bb[2]);
      const east = parseFloat(bb[3]);
      if (
        Number.isFinite(south) &&
        Number.isFinite(north) &&
        Number.isFinite(west) &&
        Number.isFinite(east)
      ) {
        const span = bboxMaxSpanDeg(south, north, west, east);
        pineMap.map.once('moveend', openPop);
        if (place.preferFieldFenceFit && span > 0) {
          pineMap.map.flyToBounds(
            L.latLngBounds(L.latLng(south, west), L.latLng(north, east)),
            { padding: [18, 18], maxZoom: 19, animate: true, duration: flyOpts.duration }
          );
        } else if (span > 0 && span <= BBOX_TIGHT_FIT_MAX_DEG) {
          pineMap.map.flyToBounds(
            L.latLngBounds(L.latLng(south, west), L.latLng(north, east)),
            { padding: [22, 22], maxZoom: 19, animate: true, duration: flyOpts.duration }
          );
        } else {
          pineMap.map.flyTo([lat, lng], 18, flyOpts);
        }
        return;
      }
    }
    pineMap.map.once('moveend', openPop);
    pineMap.map.flyTo([lat, lng], 17, flyOpts);
  }

  /** Zoom map to a field's geofence (name label click). */
  function flyMapToFieldFence(fieldId) {
    if (!pineMap.map) return;
    const fid = String(fieldId);
    const f = cacheFields.find(function (x) {
      return String(x.id) === fid;
    });
    if (!f) {
      toast('Field not found.', true);
      return;
    }
    const ring = parseBoundaryLatLngs(f.boundary_json);
    if (!ring) {
      toast('This field has no boundary yet.', true);
      return;
    }
    const bbox = ringToSearchBoundingBox(ring);
    if (!bbox || bbox.length !== 4) return;
    const south = parseFloat(bbox[0]);
    const north = parseFloat(bbox[1]);
    const west = parseFloat(bbox[2]);
    const east = parseFloat(bbox[3]);
    if (
      !Number.isFinite(south) ||
      !Number.isFinite(north) ||
      !Number.isFinite(west) ||
      !Number.isFinite(east)
    ) {
      return;
    }
    const flyOpts = { duration: 0.78, easeLinearity: 0.28 };
    pineMap.map.flyToBounds(
      L.latLngBounds(L.latLng(south, west), L.latLng(north, east)),
      { padding: [22, 22], maxZoom: 19, animate: true, duration: flyOpts.duration }
    );
    const nm = f.name && String(f.name).trim() ? String(f.name).trim() : 'Field';
    toast('Zoomed to “' + nm + '”.');
  }

  /** Lowercase trim for place / field search. */
  function normalizeMapSearchText(s) {
    return String(s == null ? '' : s)
      .toLowerCase()
      .replace(/\s+/g, ' ')
      .trim();
  }

  /** Edit distance; inputs capped for admin-scale field lists. */
  function levenshteinDist(a, b) {
    a = String(a);
    b = String(b);
    if (a.length > 56) a = a.slice(0, 56);
    if (b.length > 56) b = b.slice(0, 56);
    const m = a.length;
    const n = b.length;
    if (m === 0) return n;
    if (n === 0) return m;
    let v0 = new Array(n + 1);
    let v1 = new Array(n + 1);
    for (let j = 0; j <= n; j++) v0[j] = j;
    for (let i = 0; i < m; i++) {
      v1[0] = i + 1;
      for (let j = 0; j < n; j++) {
        const cost = a.charCodeAt(i) === b.charCodeAt(j) ? 0 : 1;
        v1[j + 1] = Math.min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      const t = v0;
      v0 = v1;
      v1 = t;
    }
    return v0[n];
  }

  /**
   * True if the query correlates with this field’s name or address:
   * substring (case-insensitive), compact alphanumeric overlap, token fuzzy match, or short full-name edit distance.
   */
  function fieldCorrelatesWithQuery(query, f) {
    const needle = normalizeMapSearchText(query);
    if (needle.length < 2) return false;
    const name = normalizeMapSearchText(f.name);
    const addr = normalizeMapSearchText(f.address);
    if (name.includes(needle) || addr.includes(needle)) return true;
    if (needle.length >= 3) {
      const ncomp = needle.replace(/[^a-z0-9]+/g, '');
      const compact = (name + addr).replace(/[^a-z0-9]+/g, '');
      if (ncomp.length >= 3 && compact.includes(ncomp)) return true;
    }
    const tokenStr = name + ' ' + addr;
    const tokens = tokenStr.split(/[^a-z0-9]+/).filter(function (t) {
      return t.length >= 2;
    });
    for (let ti = 0; ti < tokens.length; ti++) {
      const t = tokens[ti];
      const maxLen = Math.max(needle.length, t.length);
      if (maxLen >= 5) {
        const d = levenshteinDist(needle, t);
        if (d <= 1 && maxLen <= 12) return true;
        if (d <= 2 && maxLen <= 16) return true;
      }
      if (needle.length >= 4 && t.indexOf(needle) === 0) return true;
      if (t.length >= 4 && needle.indexOf(t) === 0) return true;
    }
    if (needle.length >= 4 && name.length >= 4 && name.length <= 28 && needle.length <= 28) {
      const d = levenshteinDist(needle, name);
      const maxLen = Math.max(needle.length, name.length);
      if (maxLen >= 6 && d <= 2) return true;
      if (maxLen >= 5 && d <= 1) return true;
    }
    return false;
  }

  /** Union bbox of several rings as Nominatim-style [south, north, west, east] strings. */
  function unionBoundingBoxFromRings(ringsArray, padDeg) {
    if (!ringsArray || ringsArray.length < 1) return null;
    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLng = Infinity;
    let maxLng = -Infinity;
    for (let r = 0; r < ringsArray.length; r++) {
      const ring = ringsArray[r];
      if (!ring || ring.length < 1) continue;
      for (let i = 0; i < ring.length; i++) {
        const la = Number(ring[i][0]);
        const ln = Number(ring[i][1]);
        if (!Number.isFinite(la) || !Number.isFinite(ln)) continue;
        if (la < minLat) minLat = la;
        if (la > maxLat) maxLat = la;
        if (ln < minLng) minLng = ln;
        if (ln > maxLng) maxLng = ln;
      }
    }
    if (minLat === Infinity) return null;
    const pad = padDeg == null ? 0.00085 : padDeg;
    const south = minLat - pad;
    const north = maxLat + pad;
    const west = minLng - pad;
    const east = maxLng + pad;
    if (!(north > south && east > west)) return null;
    return [String(south), String(north), String(west), String(east)];
  }

  /** Fit map to every listed field that has a boundary (search: multiple correlated fields). */
  function flyMapToCorrelatedFieldIds(fieldIds) {
    if (!pineMap.map || !fieldIds || fieldIds.length < 1) return;
    const rings = [];
    for (let i = 0; i < fieldIds.length; i++) {
      const f = cacheFields.find(function (x) {
        return String(x.id) === String(fieldIds[i]);
      });
      if (!f) continue;
      const ring = parseBoundaryLatLngs(f.boundary_json);
      if (ring && ring.length >= 3) rings.push(ring);
    }
    if (!rings.length) {
      toast('Matching fields have no boundaries to zoom to.', true);
      return;
    }
    const bbox = unionBoundingBoxFromRings(rings);
    if (!bbox || bbox.length !== 4) return;
    const south = parseFloat(bbox[0]);
    const north = parseFloat(bbox[1]);
    const west = parseFloat(bbox[2]);
    const east = parseFloat(bbox[3]);
    if (
      !Number.isFinite(south) ||
      !Number.isFinite(north) ||
      !Number.isFinite(west) ||
      !Number.isFinite(east)
    ) {
      return;
    }
    clearGeocodeMarker();
    const flyOpts = { duration: 0.85, easeLinearity: 0.28 };
    pineMap.map.flyToBounds(
      L.latLngBounds(L.latLng(south, west), L.latLng(north, east)),
      { padding: [32, 32], maxZoom: 19, animate: true, duration: flyOpts.duration }
    );
    const n = fieldIds.length;
    const withRing = rings.length;
    if (withRing === n) {
      toast('Zoomed to fit ' + n + ' matching field' + (n === 1 ? '' : 's') + '.');
    } else {
      toast(
        'Zoomed to ' +
          withRing +
          ' field' +
          (withRing === 1 ? '' : 's') +
          ' with boundaries (' +
          n +
          ' matched).'
      );
    }
  }

  function setLocateResultsVisible(visible) {
    const el = $('pine-map-locate-results');
    if (el) el.hidden = !visible;
  }

  function renderLocateResultList(items) {
    const wrap = $('pine-map-locate-results');
    if (!wrap) return;
    if (!items || !items.length) {
      wrap.innerHTML = '';
      setLocateResultsVisible(false);
      return;
    }
    wrap.innerHTML = items
      .map(function (it, idx) {
        return (
          '<button type="button" class="pine-map-locate-result" data-locate-idx="' +
          idx +
          '">' +
          escapeHtml(it.label) +
          '</button>'
        );
      })
      .join('');
    setLocateResultsVisible(true);
  }

  async function nominatimSearchPlaces(query) {
    const q = String(query || '').trim();
    if (!q) return [];
    const url =
      'https://nominatim.openstreetmap.org/search?' +
      new URLSearchParams({
        q: q,
        format: 'json',
        limit: '6',
        addressdetails: '0',
      }).toString();
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'Accept-Language': 'en',
      },
    });
    if (!res.ok) throw new Error('Nominatim HTTP ' + res.status);
    const data = await res.json();
    if (!Array.isArray(data)) return [];
    return data.map(function (r) {
      const lat = parseFloat(r.lat);
      const lng = parseFloat(r.lon);
      const label = r.display_name || (String(lat) + ', ' + String(lng));
      return {
        lat: lat,
        lng: lng,
        label: label,
        boundingbox: r.boundingbox,
        source: 'remote',
      };
    });
  }

  /** Photon (Komoot) — usually works from the browser when Nominatim is empty or blocked. */
  async function photonSearchPlaces(query) {
    const q = String(query || '').trim();
    if (!q) return [];
    const url =
      'https://photon.komoot.io/api/?' +
      new URLSearchParams({ q: q, lang: 'en', limit: '10' }).toString();
    const res = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });
    if (!res.ok) throw new Error('Photon HTTP ' + res.status);
    const data = await res.json();
    if (!data || !Array.isArray(data.features)) return [];
    return data.features
      .map(function (f) {
        const c = f.geometry && f.geometry.coordinates;
        if (!c || c.length < 2) return null;
        const lng = Number(c[0]);
        const lat = Number(c[1]);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
        const p = f.properties || {};
        const parts = [];
        if (p.name) parts.push(p.name);
        if (p.street && p.street !== p.name) parts.push(p.street);
        if (p.city) parts.push(p.city);
        if (p.state) parts.push(p.state);
        if (p.country) parts.push(p.country);
        let label = parts.length ? parts.join(', ') : q;
        let boundingbox = null;
        if (Array.isArray(p.extent) && p.extent.length === 4) {
          const w = p.extent[0];
          const s = p.extent[1];
          const e = p.extent[2];
          const n = p.extent[3];
          if (Number.isFinite(s) && Number.isFinite(n) && Number.isFinite(w) && Number.isFinite(e)) {
            boundingbox = [String(s), String(n), String(w), String(e)];
          }
        }
        return { lat: lat, lng: lng, label: label, boundingbox: boundingbox, source: 'remote' };
      })
      .filter(Boolean);
  }

  /** Match loaded fields by name or address (substring + light fuzzy / token similarity). */
  function localFieldPlaceMatches(query) {
    const qTrim = String(query || '').trim();
    if (qTrim.length < 2) return [];
    const out = [];
    const seen = new Set();
    for (let i = 0; i < cacheFields.length; i++) {
      const f = cacheFields[i];
      if (!fieldCorrelatesWithQuery(qTrim, f)) continue;
      const ring = parseBoundaryLatLngs(f.boundary_json);
      const c = ring ? ringCentroidLatLng(ring) : null;
      if (!c) continue;
      const fid = String(f.id);
      if (seen.has(fid)) continue;
      seen.add(fid);
      const label =
        'Field: ' +
        (f.name && String(f.name).trim() ? String(f.name).trim() : 'Field') +
        (f.address && String(f.address).trim() ? ' · ' + String(f.address).trim() : '');
      const bbox = ring ? ringToSearchBoundingBox(ring) : null;
      out.push({
        fieldId: fid,
        lat: c.lat,
        lng: c.lng,
        label: label,
        boundingbox: bbox,
        preferFieldFenceFit: true,
        source: 'local',
      });
    }
    return out;
  }

  function dedupePlacesByProximity(places, minDeg) {
    const m = minDeg == null ? 0.00025 : minDeg;
    const res = [];
    for (let i = 0; i < places.length; i++) {
      const a = places[i];
      if (!Number.isFinite(a.lat) || !Number.isFinite(a.lng)) continue;
      let dup = false;
      for (let j = 0; j < res.length; j++) {
        const b = res[j];
        const dlat = a.lat - b.lat;
        const dlng = a.lng - b.lng;
        if (dlat * dlat + dlng * dlng < m * m) {
          dup = true;
          break;
        }
      }
      if (!dup) res.push(a);
    }
    return res;
  }

  async function searchPlacesCombined(query) {
    const q = String(query || '').trim();
    if (!q) return { locals: [], merged: [] };
    const local = localFieldPlaceMatches(q);
    let remote = [];
    try {
      remote = await nominatimSearchPlaces(q);
    } catch (_) {
      remote = [];
    }
    if (!remote.length) {
      try {
        remote = await photonSearchPlaces(q);
      } catch (_) {
        remote = [];
      }
    }
    const merged = dedupePlacesByProximity(local.concat(remote), 0.0002);
    return {
      locals: local,
      merged: merged.filter(function (x) {
        return Number.isFinite(x.lat) && Number.isFinite(x.lng);
      }),
    };
  }

  function bindMapLocationSearch() {
    if (pineMap._locateSearchBound) return;
    pineMap._locateSearchBound = true;
    const input = $('pine-map-locate-input');
    const go = $('pine-map-locate-go');
    const results = $('pine-map-locate-results');
    let lastResults = [];

    function runSearch() {
      if (!input || !pineMap.map) return;
      const raw = input.value;
      const parsed = parseLatLngQuery(raw);
      if (parsed) {
        renderLocateResultList([]);
        flyMapToPlace({ lat: parsed.lat, lng: parsed.lng, label: raw.trim() });
        toast('Moved map to coordinates.');
        return;
      }
      const q = String(raw || '').trim();
      if (!q) {
        toast('Type a place name or lat, lng.', true);
        return;
      }
      if (go instanceof HTMLButtonElement) go.disabled = true;
      void (async function () {
        try {
          const combo = await searchPlacesCombined(q);
          const locals = combo.locals || [];
          const list = combo.merged || [];
          lastResults = list;
          if (locals.length >= 1) {
            renderLocateResultList([]);
            if (locals.length > 1) {
              const ids = locals
                .map(function (l) {
                  return l.fieldId;
                })
                .filter(Boolean);
              flyMapToCorrelatedFieldIds(ids);
            } else {
              flyMapToPlace(locals[0]);
              toast('Zoomed to your field.');
            }
            return;
          }
          if (!lastResults.length) {
            renderLocateResultList([]);
            toast(
              'No matches. Try a longer place name, lat/lng (e.g. 6.34, 125.12), or a field name from your list.',
              true
            );
            return;
          }
          if (lastResults.length === 1) {
            renderLocateResultList([]);
            flyMapToPlace(lastResults[0]);
            toast('Moved map to result.');
            return;
          }
          renderLocateResultList(
            lastResults.map(function (r) {
              return { label: r.label };
            })
          );
          toast('Pick a result below.');
        } catch (e) {
          renderLocateResultList([]);
          toast(
            e && e.message
              ? e.message
              : 'Search unavailable. Try lat, lng (e.g. 6.34, 125.12).',
            true
          );
        } finally {
          if (go instanceof HTMLButtonElement) go.disabled = false;
        }
      })();
    }

    if (go) {
      go.addEventListener('click', function () {
        runSearch();
      });
    }
    if (input) {
      input.addEventListener('keydown', function (ev) {
        if (ev.key === 'Enter') {
          ev.preventDefault();
          runSearch();
        }
      });
    }
    if (results) {
      results.addEventListener('click', function (ev) {
        const btn = ev.target.closest('[data-locate-idx]');
        if (!btn || !results.contains(btn)) return;
        const idx = parseInt(btn.getAttribute('data-locate-idx') || '-1', 10);
        if (idx < 0 || idx >= lastResults.length) return;
        renderLocateResultList([]);
        flyMapToPlace(lastResults[idx]);
        toast('Moved map to result.');
      });
    }
  }

  function ensureMap() {
    if (typeof L === 'undefined') {
      toast('Map library failed to load.', true);
      return false;
    }
    const mapEl = $('map-full');
    if (!mapEl) return false;
    if (mapInitialized) {
      setTimeout(function () {
        if (pineMap.map) {
          pineMap.map.invalidateSize();
        }
      }, 120);
      return true;
    }

    try {
      pineMap.map = L.map(mapEl, { zoomControl: true, maxZoom: 19 });
      pineMap.satellite = L.tileLayer(
        'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        {
          attribution: 'Esri',
          maxZoom: 19,
          maxNativeZoom: 17,
        }
      );
      pineMap.street = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OSM',
        maxZoom: 19,
        maxNativeZoom: 19,
      });
      if (mapViewState.satellite) {
        pineMap.satellite.addTo(pineMap.map);
      } else {
        pineMap.street.addTo(pineMap.map);
      }
      pineMap.fieldGroup = L.layerGroup();
      pineMap.fieldLabelLayer = L.layerGroup();
      pineMap.captureGroup = L.layerGroup();
      pineMap.userGroup = L.layerGroup();
      if (mapViewState.showFields) {
        pineMap.fieldGroup.addTo(pineMap.map);
        pineMap.fieldLabelLayer.addTo(pineMap.map);
      }
      if (mapViewState.showCaptures) {
        pineMap.captureGroup.addTo(pineMap.map);
      }
      if (mapViewState.showAccounts) {
        pineMap.userGroup.addTo(pineMap.map);
      }
      if (pineMap.map.zoomControl && typeof pineMap.map.zoomControl.setPosition === 'function') {
        pineMap.map.zoomControl.setPosition('topright');
      }
      applyBasemapMaxZoom();
      bindMapControls();
      bindMapLocationSearch();
      installBoxSelectHandlers();
      syncBoxSelectCursorClass();
      // Keep marker DOM count low by re-rendering the visible subset on pan/zoom.
      // Preserve the user's view (no auto-fit) and debounce to avoid thrash.
      const refreshVisible = debounce(function () {
        rebuildMapLayers(false, true);
      }, 140);
      pineMap.map.on('moveend zoomend', refreshVisible);
      mapInitialized = true;
      setTimeout(function () {
        if (pineMap.map) {
          pineMap.map.invalidateSize();
        }
      }, 200);
      return true;
    } catch (err) {
      console.error(err);
      toast('Could not start map.', true);
      return false;
    }
  }

  function openDrawer(section) {
    if ((section === 'users' || section === 'fields') && !sessionIsFullAdmin) {
      toast('Users and Fields are limited to full admins.', true);
      return;
    }
    drawerEditingFieldId = null;
    drawerEditingProfileId = null;
    drawerSection = section;
    if (!elDrawer || !elDrawerContent) return;
    elDrawer.hidden = false;
    elDrawer.classList.toggle(
      'pine-drawer--wide',
      section === 'users' || section === 'fields' || section === 'analytics'
    );
    elDrawer.classList.toggle('pine-drawer--reports', section === 'captures');
    if (elDrawerTitle) {
      elDrawerTitle.textContent =
        section === 'users'
          ? 'Users'
          : section === 'fields'
            ? 'Fields'
            : section === 'analytics'
              ? 'Analytics'
              : 'Reports';
    }
    renderDrawer();
  }

  function closeDrawer() {
    drawerSection = null;
    if (elDrawer) {
      elDrawer.hidden = true;
      elDrawer.classList.remove('pine-drawer--wide');
      elDrawer.classList.remove('pine-drawer--reports');
    }
  }

  function renderDrawer() {
    if (!elDrawerContent || !drawerSection) return;
    if (drawerSection === 'users') {
      const rows = cacheProfiles
        .map(function (p) {
          const pid = String(p.id);
          const isEditing = drawerEditingProfileId === pid;
          const dn = p.display_name == null ? '' : String(p.display_name);
          const em = p.email == null ? '' : String(p.email);
          const nameCell = isEditing
            ? '<div class="pine-users-edit-stack">' +
              '<label class="pine-users-edit-label" for="profile-name-' +
              escapeHtml(pid) +
              '">Display name</label>' +
              '<input id="profile-name-' +
              escapeHtml(pid) +
              '" type="text" class="pine-input pine-inline-input pine-users-edit-input" data-profile-edit-name="' +
              escapeHtml(pid) +
              '" value="' +
              escapeHtml(dn) +
              '" />' +
              '<label class="pine-users-edit-label" for="profile-email-' +
              escapeHtml(pid) +
              '">Email</label>' +
              '<input id="profile-email-' +
              escapeHtml(pid) +
              '" type="email" class="pine-input pine-inline-input pine-inline-input-wide pine-users-edit-input" data-profile-edit-email="' +
              escapeHtml(pid) +
              '" value="' +
              escapeHtml(em) +
              '" autocomplete="off" /></div>'
            : escapeHtml(dn.trim() === '' ? '—' : dn);
          const deleteProfBtn =
            '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm pine-btn-danger-text" data-drawer-delete-profile="' +
            escapeHtml(pid) +
            '" title="Remove Auth user, profile, and related data (cascade)">Delete</button>';
          const actionBtns = isEditing
            ? '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-save-profile="' +
              escapeHtml(pid) +
              '">Save</button>' +
              '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-cancel-profile-edit="1">Cancel</button>' +
              deleteProfBtn
            : '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-edit-profile="' +
              escapeHtml(pid) +
              '">Edit</button>' +
              deleteProfBtn;
          return (
            '<tr><td class="pine-users-name-cell">' +
            nameCell +
            '</td><td class="pine-drawer-field-actions-cell"><div class="pine-drawer-field-actions">' +
            actionBtns +
            '</div></td></tr>'
          );
        })
        .join('');
      const fnUrl = createUserFunctionUrlResolved();
      const hint =
        fnUrl && fnUrl.indexOf('http') === 0
          ? '<p class="pine-subtle">Creates Supabase Auth user + profile (Edge Function). If the browser reports CORS errors, redeploy the function and confirm the project URL in config matches Supabase.</p>'
          : '<p class="pine-error">Set <code>supabaseUrl</code> in config.js and deploy <code>supabase/functions/pine-admin-create-user</code>.</p>';
      elDrawerContent.innerHTML =
        buildDaRequestsSectionHtml() +
        '<hr class="pine-drawer-divider" />' +
        hint +
        '<form id="form-new-user" class="pine-drawer-form pine-drawer-form--new-user">' +
        '<div class="pine-field"><label class="pine-label">Email</label><input class="pine-input" name="email" type="email" required autocomplete="off" /></div>' +
        '<div class="pine-field"><label class="pine-label">Password (min 6)</label><input class="pine-input" name="password" type="password" required minlength="6" autocomplete="new-password" /></div>' +
        '<div class="pine-field pine-drawer-form--full-row"><label class="pine-label">Display name</label><input class="pine-input" name="display_name" type="text" autocomplete="off" /></div>' +
        '<div class="pine-drawer-form--full-row pine-drawer-form--actions">' +
        '<button type="submit" class="pine-btn pine-btn-primary">Create user</button>' +
        '<p id="new-user-status" class="pine-save-status"></p></div></form>' +
        '<p class="pine-muted pine-drawer-fields-hint" style="margin-top:0.75rem"><strong>Save</strong> updates display name, <code>profiles</code> email, and <strong>Auth sign-in email</strong> (deploy <code>pine-admin-update-user-profile</code>). Email is only shown while <strong>Edit</strong> is active. You cannot change your own email here — use Supabase Dashboard → Authentication. <strong>Delete</strong> needs <code>pine-admin-delete-user</code>.</p>' +
        '<div class="pine-table-wrap pine-table-wrap--users-drawer" style="margin-top:0.5rem"><table class="pine-table pine-table--users-drawer"><thead><tr><th>Name</th><th class="pine-th-actions">Actions</th></tr></thead><tbody>' +
        (rows || '<tr><td colspan="2" class="pine-empty">No profiles</td></tr>') +
        '</tbody></table></div>';

      const form = $('form-new-user');
      if (form) {
        form.addEventListener('submit', async function (ev) {
          ev.preventDefault();
          const st = $('new-user-status');
          if (st) {
            st.textContent = '';
            st.classList.remove('ok', 'err');
          }
          const fd = new FormData(form);
          const email = String(fd.get('email') || '').trim();
          const password = String(fd.get('password') || '');
          const display_name = String(fd.get('display_name') || '').trim();
          const url = createUserFunctionUrlResolved();
          if (!url || url.indexOf('http') !== 0) {
            if (st) {
              st.textContent = 'Missing supabaseUrl in config.';
              st.classList.add('err');
            }
            return;
          }
          const {
            data: { session },
          } = await supabase.auth.getSession();
          if (!session) return;
          try {
            const res = await fetch(url, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: 'Bearer ' + session.access_token,
                apikey: cfg.supabaseAnonKey,
              },
              body: JSON.stringify({ email, password, display_name }),
            });
            const j = await res.json().catch(function () {
              return {};
            });
            if (!res.ok) {
              throw new Error(j.error || 'Request failed');
            }
            if (st) {
              st.textContent = 'Created.';
              st.classList.add('ok');
            }
            toast('User created.');
            form.reset();
            await loadDashboard();
            openDrawer('users');
          } catch (e) {
            if (st) {
              st.textContent = e && e.message ? e.message : 'Failed';
              st.classList.add('err');
            }
            toast(e && e.message ? e.message : 'Create failed', true);
          }
        });
      }
      return;
    }

    if (drawerSection === 'fields') {
      const userOpts = cacheProfiles
        .map(function (p) {
          return (
            '<option value="' +
            escapeHtml(String(p.id)) +
            '">' +
            escapeHtml(profileDisplayName(p.id)) +
            '</option>'
          );
        })
        .join('');
      const tableRows = cacheFields
        .map(function (f) {
          const fid = String(f.id);
          const isEditing = drawerEditingFieldId === fid;
          const addrRaw = f.address == null ? '' : String(f.address);
          const addrTitle = escapeHtml(addrRaw);
          const addrShow =
            addrRaw.trim() === ''
              ? '—'
              : addrRaw.length > 48
                ? escapeHtml(addrRaw.slice(0, 47)) + '…'
                : escapeHtml(addrRaw);
          const opts = cacheProfiles
            .map(function (p) {
              const sel = f.user_id === p.id ? ' selected' : '';
              return (
                '<option value="' +
                escapeHtml(String(p.id)) +
                '"' +
                sel +
                '>' +
                escapeHtml(profileDisplayName(p.id)) +
                '</option>'
              );
            })
            .join('');
          const nameCell = isEditing
            ? '<input type="text" class="pine-input pine-inline-input pine-field-edit-name" data-field-edit-name="' +
              escapeHtml(fid) +
              '" value="' +
              escapeHtml(f.name || '') +
              '" />'
            : escapeHtml(f.name || '');
          const addrCell = isEditing
            ? '<input type="text" class="pine-input pine-inline-input pine-inline-input-wide" data-field-edit-address="' +
              escapeHtml(fid) +
              '" value="' +
              escapeHtml(addrRaw) +
              '" />'
            : '<span title="' +
              addrTitle +
              '">' +
              addrShow +
              '</span>';
          const boundaryBtn =
            '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-boundary-field="' +
            escapeHtml(fid) +
            '" title="Focus on the map and edit geofence (adds a starter shape if none)">Boundary</button>';
          const mainActionBtns = isEditing
            ? boundaryBtn +
              '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-save-field="' +
              escapeHtml(fid) +
              '">Save</button>' +
              '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-cancel-field-edit="1">Cancel</button>'
            : boundaryBtn +
              '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-drawer-edit-field="' +
              escapeHtml(fid) +
              '">Edit</button>';
          const actionCell =
            '<div class="pine-drawer-field-actions pine-drawer-field-actions--fields">' +
            '<div class="pine-drawer-field-actions-row">' +
            mainActionBtns +
            '</div><div class="pine-drawer-field-actions-row">' +
            '<button type="button" class="pine-btn pine-btn-secondary pine-btn--sm pine-btn-danger-text" data-drawer-delete-field="' +
            escapeHtml(fid) +
            '">Delete</button></div></div>';
          return (
            '<tr><td>' +
            nameCell +
            '</td><td class="pine-fields-owner-cell"><select class="pine-input pine-inline-select" data-drawer-assign-field="' +
            escapeHtml(fid) +
            '">' +
            opts +
            '</select></td><td class="pine-fields-address-cell">' +
            addrCell +
            '</td><td class="pine-drawer-field-actions-cell">' +
            actionCell +
            '</td></tr>'
          );
        })
        .join('');
      elDrawerContent.innerHTML =
        '<h3 class="pine-drawer-h3">New field</h3>' +
        '<form id="form-new-field" class="pine-drawer-form">' +
        '<div class="pine-field"><label class="pine-label">Owner</label><select class="pine-input" name="user_id" required>' +
        userOpts +
        '</select></div>' +
        '<div class="pine-field"><label class="pine-label">Name</label><input class="pine-input" name="name" required /></div>' +
        '<div class="pine-field"><label class="pine-label">Address</label><input class="pine-input" name="address" /></div>' +
        '<button type="submit" class="pine-btn pine-btn-primary">Create field</button>' +
        '<p id="new-field-status" class="pine-save-status"></p></form>' +
        '<p class="pine-muted pine-drawer-fields-hint" style="margin-top:0.35rem">After creating, use <strong>Boundary</strong> in the list to add or edit the map geofence.</p>' +
        '<h3 class="pine-drawer-h3">All fields</h3>' +
        '<p class="pine-muted pine-drawer-fields-hint">Use <strong>Edit</strong> for name and address. <strong>Boundary</strong> focuses the map and lets you drag geofence vertices (starter triangle if the field has none). Owner: dropdown.</p>' +
        '<div class="pine-table-wrap"><table class="pine-table pine-table--fields-drawer"><thead><tr><th>Name</th><th>Owner</th><th>Address</th><th class="pine-th-actions">Actions</th></tr></thead><tbody>' +
        (tableRows || '<tr><td colspan="4" class="pine-empty">No fields</td></tr>') +
        '</tbody></table></div>' +
        '<h3 class="pine-drawer-h3" style="margin-top:1rem">DA farm insight</h3>' +
        '<p class="pine-muted pine-drawer-fields-hint">Universal guidance for a farm (visible to the field owner in a future app update; stored for DA records).</p>' +
        '<div class="pine-field"><label class="pine-label" for="pine-farm-insight-field">Field</label><select class="pine-input" id="pine-farm-insight-field">' +
        cacheFields
          .map(function (f) {
            return (
              '<option value="' +
              escapeHtml(String(f.id)) +
              '">' +
              escapeHtml(f.name || 'Field') +
              ' — ' +
              escapeHtml(profileDisplayName(f.user_id)) +
              '</option>'
            );
          })
          .join('') +
        '</select></div>' +
        '<div class="pine-field pine-reply-box"><label class="pine-label" for="pine-farm-insight-text">Insight</label><textarea class="pine-input" id="pine-farm-insight-text" placeholder="Seasonal advice, monitoring schedule, area-wide treatment notes…"></textarea></div>' +
        '<button type="button" class="pine-btn pine-btn-primary pine-btn--sm" id="pine-farm-insight-save">Save farm insight</button>' +
        '<span class="pine-save-status" id="pine-farm-insight-status"></span>';

      const farmInsightSelect = $('pine-farm-insight-field');
      const farmInsightText = $('pine-farm-insight-text');
      function syncFarmInsightTextarea() {
        if (!(farmInsightSelect instanceof HTMLSelectElement) || !(farmInsightText instanceof HTMLTextAreaElement)) {
          return;
        }
        const latest = latestFarmInsightForField(farmInsightSelect.value);
        farmInsightText.value = latest && latest.insight_text ? String(latest.insight_text) : '';
      }
      if (farmInsightSelect) {
        farmInsightSelect.addEventListener('change', syncFarmInsightTextarea);
        syncFarmInsightTextarea();
      }
      const farmInsightSave = $('pine-farm-insight-save');
      if (farmInsightSave) {
        farmInsightSave.addEventListener('click', function () {
          const st = $('pine-farm-insight-status');
          const fid = farmInsightSelect instanceof HTMLSelectElement ? farmInsightSelect.value : '';
          const txt = farmInsightText instanceof HTMLTextAreaElement ? farmInsightText.value : '';
          void saveFarmInsight(fid, txt, st);
        });
      }

      const nf = $('form-new-field');
      if (nf) {
        nf.addEventListener('submit', async function (ev) {
          ev.preventDefault();
          const st = $('new-field-status');
          if (st) {
            st.textContent = '';
            st.classList.remove('ok', 'err');
          }
          const fd = new FormData(nf);
          try {
            const { data: created, error } = await supabase
              .from('fields')
              .insert({
                user_id: String(fd.get('user_id')),
                name: String(fd.get('name') || '').trim(),
                address: String(fd.get('address') || '').trim(),
              })
              .select('id')
              .maybeSingle();
            if (error) throw error;
            if (st) {
              st.textContent = 'Created.';
              st.classList.add('ok');
            }
            toast('Field created.');
            nf.reset();
            await loadDashboard();
            openDrawer('fields');
            const newId = created && created.id;
            if (newId) {
              void focusFieldBoundaryOnMap(newId);
            }
          } catch (e) {
            if (st) {
              st.textContent = e && e.message ? e.message : 'Failed';
              st.classList.add('err');
            }
            toast(e && e.message ? e.message : 'Failed', true);
          }
        });
      }
      return;
    }

    if (drawerSection === 'captures') {
      if (cacheDetections.length === 0) {
        elDrawerContent.innerHTML = '<div class="pine-empty">No reports loaded.</div>';
        return;
      }
      const filtered = capturesForDrawer();
      const pendingCount = cacheDetections.filter(function (d) {
        return detectionIsPositive(d) && !reportHasExpertReply(d.id);
      }).length;
      const positiveCount = positiveDetections(cacheDetections).length;
      const filterBtn = function (key, label) {
        const active = capturesDrawerFilter === key ? ' is-active' : '';
        return (
          '<button type="button" class="pine-report-filter' +
          active +
          '" data-captures-filter="' +
          key +
          '">' +
          escapeHtml(label) +
          '</button>'
        );
      };
      const cards =
        filtered.length === 0
          ? '<div class="pine-empty pine-empty--reports">No reports match this filter.</div>'
          : filtered.map(buildReportCardHtml).join('');
      elDrawerContent.innerHTML =
        '<div class="pine-reports-header">' +
        '<p class="pine-reports-lead">Review farmer submissions, open captures, and write <strong>DA/OMAG advice</strong> per positive sighting.</p>' +
        '<div class="pine-reports-summary">' +
        '<div class="pine-reports-summary-item"><span class="pine-reports-summary-num">' +
        String(filtered.length) +
        '</span><span class="pine-reports-summary-label">Showing</span></div>' +
        '<div class="pine-reports-summary-item"><span class="pine-reports-summary-num">' +
        String(positiveCount) +
        '</span><span class="pine-reports-summary-label">Positive</span></div>' +
        '<div class="pine-reports-summary-item pine-reports-summary-item--warn"><span class="pine-reports-summary-num">' +
        String(pendingCount) +
        '</span><span class="pine-reports-summary-label">Pending reply</span></div>' +
        '</div></div>' +
        '<div class="pine-captures-filter-row pine-report-filters">' +
        filterBtn('all', 'All') +
        filterBtn('positive', 'Positive only') +
        filterBtn('pending', 'Pending reply') +
        '</div>' +
        '<div class="pine-reports-list">' +
        cards +
        '</div>';
      return;
    }

    if (drawerSection === 'analytics') {
      const pos = positiveDetections(cacheDetections);
      const negCount = cacheDetections.length - pos.length;
      const now = Date.now();
      const dayMs = 86400000;
      const pos7 = pos.filter(function (d) {
        const t = d.created_at ? new Date(d.created_at).getTime() : 0;
        return t >= now - 7 * dayMs;
      }).length;
      const pos30 = pos.filter(function (d) {
        const t = d.created_at ? new Date(d.created_at).getTime() : 0;
        return t >= now - 30 * dayMs;
      }).length;
      const farmAgg = Object.create(null);
      for (let i = 0; i < pos.length; i++) {
        const d = pos[i];
        const fid = d.field_id == null ? '' : String(d.field_id);
        if (!fid) continue;
        if (!farmAgg[fid]) {
          farmAgg[fid] = { count: 0, last: d.created_at || '' };
        }
        farmAgg[fid].count += 1;
        if (String(d.created_at || '') > String(farmAgg[fid].last)) {
          farmAgg[fid].last = d.created_at;
        }
      }
      const topFarms = Object.keys(farmAgg)
        .map(function (fid) {
          const field = cacheFields.find(function (f) {
            return String(f.id) === fid;
          });
          return {
            fid: fid,
            name: field ? field.name || 'Field' : fid,
            owner: field ? profileDisplayName(field.user_id) : '—',
            count: farmAgg[fid].count,
            last: farmAgg[fid].last,
          };
        })
        .sort(function (a, b) {
          return b.count - a.count;
        })
        .slice(0, 10);
      const topRows = topFarms
        .map(function (row) {
          return (
            '<tr><td>' +
            escapeHtml(row.name) +
            '</td><td>' +
            escapeHtml(row.owner) +
            '</td><td><strong>' +
            String(row.count) +
            '</strong></td><td>' +
            escapeHtml(formatReportDate(row.last)) +
            '</td><td><button type="button" class="pine-btn pine-btn-secondary pine-btn--sm" data-analytics-map-field="' +
            escapeHtml(row.fid) +
            '">View on map</button></td></tr>'
          );
        })
        .join('');
      elDrawerContent.innerHTML =
        '<div class="pine-analytics-grid">' +
        '<div class="pine-analytics-stat"><strong>' +
        String(pos.length) +
        '</strong><span>Positive reports</span></div>' +
        '<div class="pine-analytics-stat"><strong>' +
        String(negCount) +
        '</strong><span>Negative scans</span></div>' +
        '<div class="pine-analytics-stat"><strong>' +
        String(pos7) +
        '</strong><span>Positive (7 days)</span></div>' +
        '<div class="pine-analytics-stat"><strong>' +
        String(pos30) +
        '</strong><span>Positive (30 days)</span></div>' +
        '</div>' +
        '<h3 class="pine-drawer-subtitle">Report mix</h3>' +
        '<div class="pine-analytics-charts">' +
        '<div class="pine-analytics-chart-card">' +
        '<p class="pine-analytics-chart-label">Positive vs negative <span class="pine-analytics-viz-tag">Donut</span></p>' +
        '<canvas id="pine-analytics-donut" height="140"></canvas>' +
        '</div>' +
        '<div class="pine-analytics-chart-card">' +
        '<p class="pine-analytics-chart-label">30-day positive trend <span class="pine-analytics-viz-tag">Line</span></p>' +
        '<canvas id="pine-analytics-trend" height="140"></canvas>' +
        '</div>' +
        '<div class="pine-analytics-chart-card pine-analytics-chart-card--wide">' +
        '<p class="pine-analytics-chart-label">Top farms <span class="pine-analytics-viz-tag">Bar</span></p>' +
        '<canvas id="pine-analytics-farms-bar" height="160"></canvas>' +
        '</div>' +
        '</div>' +
        '<p class="pine-analytics-viz-note">Map uses <strong>choropleth heatmap</strong> + <strong>dot map</strong> (Location). Charts follow Data-to-Viz families — see <code>docs/thesis/ADMIN_UI_REDESIGN.md</code>.</p>' +
        '<h3 class="pine-drawer-subtitle" style="margin-top:1rem">Top farms (table)</h3>' +
        '<div class="pine-table-wrap"><table class="pine-table"><thead><tr><th>Field</th><th>Owner</th><th>Positive</th><th>Last sighting</th><th></th></tr></thead><tbody>' +
        (topRows || '<tr><td colspan="5" class="pine-muted">No positive reports yet.</td></tr>') +
        '</tbody></table></div>';
      if (typeof Chart !== 'undefined') {
        destroyAnalyticsCharts();
        const olive = 'rgba(118, 148, 76, 0.85)';
        const oliveSoft = 'rgba(118, 148, 76, 0.35)';
        const taupe = 'rgba(192, 182, 172, 0.75)';

        const donutCanvas = document.getElementById('pine-analytics-donut');
        if (donutCanvas && (pos.length > 0 || negCount > 0)) {
          analyticsChartInstances.push(
            new Chart(donutCanvas, {
              type: 'doughnut',
              data: {
                labels: ['Positive', 'Negative'],
                datasets: [
                  {
                    data: [pos.length, negCount],
                    backgroundColor: [olive, taupe],
                    borderWidth: 0,
                  },
                ],
              },
              options: {
                responsive: true,
                plugins: {
                  legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } },
                },
              },
            }),
          );
        }

        const trendLabels = [];
        const trendValues = [];
        for (let di = 29; di >= 0; di--) {
          const dayStart = new Date(now - di * dayMs);
          dayStart.setHours(0, 0, 0, 0);
          const dayEnd = dayStart.getTime() + dayMs;
          trendLabels.push(
            di % 5 === 0 ? formatReportDate(dayStart.toISOString()).split(',')[0] : '',
          );
          let c = 0;
          for (let pi = 0; pi < pos.length; pi++) {
            const t = pos[pi].created_at ? new Date(pos[pi].created_at).getTime() : 0;
            if (t >= dayStart.getTime() && t < dayEnd) c += 1;
          }
          trendValues.push(c);
        }
        const trendCanvas = document.getElementById('pine-analytics-trend');
        if (trendCanvas) {
          analyticsChartInstances.push(
            new Chart(trendCanvas, {
              type: 'line',
              data: {
                labels: trendLabels,
                datasets: [
                  {
                    label: 'Positive reports',
                    data: trendValues,
                    borderColor: olive,
                    backgroundColor: oliveSoft,
                    fill: true,
                    tension: 0.3,
                    pointRadius: 0,
                    pointHitRadius: 8,
                  },
                ],
              },
              options: {
                responsive: true,
                plugins: { legend: { display: false } },
                scales: {
                  x: { ticks: { maxRotation: 0, autoSkip: true, maxTicksLimit: 8 } },
                  y: { beginAtZero: true, ticks: { precision: 0 } },
                },
              },
            }),
          );
        }

        const barFarms = topFarms.slice(0, 8);
        const farmsBarCanvas = document.getElementById('pine-analytics-farms-bar');
        if (farmsBarCanvas && barFarms.length > 0) {
          analyticsChartInstances.push(
            new Chart(farmsBarCanvas, {
              type: 'bar',
              data: {
                labels: barFarms.map(function (row) {
                  return row.name.length > 18 ? row.name.slice(0, 16) + '…' : row.name;
                }),
                datasets: [
                  {
                    label: 'Positive sightings',
                    data: barFarms.map(function (row) {
                      return row.count;
                    }),
                    backgroundColor: olive,
                  },
                ],
              },
              options: {
                indexAxis: 'y',
                responsive: true,
                plugins: { legend: { display: false } },
                scales: {
                  x: { beginAtZero: true, ticks: { precision: 0 } },
                  y: { ticks: { font: { size: 11 } } },
                },
              },
            }),
          );
        }
      }
    }
  }

  elDrawerContent.addEventListener('click', async function (ev) {
    const t = ev.target;
    if (!(t instanceof HTMLElement)) return;

    const capFilter = t.closest('[data-captures-filter]');
    if (capFilter) {
      const key = capFilter.getAttribute('data-captures-filter');
      if (key) {
        capturesDrawerFilter = key;
        renderDrawer();
      }
      return;
    }

    const replySave = t.closest('[data-expert-reply-save]');
    if (replySave) {
      const detId = replySave.getAttribute('data-expert-reply-save');
      if (detId) {
        const textEl = elDrawerContent.querySelector('[data-expert-reply-text="' + detId + '"]');
        const actEl = elDrawerContent.querySelector('[data-expert-reply-action="' + detId + '"]');
        const st = elDrawerContent.querySelector('[data-expert-reply-status="' + detId + '"]');
        const text = textEl instanceof HTMLTextAreaElement ? textEl.value : '';
        const act = actEl instanceof HTMLSelectElement ? actEl.value : '';
        await saveExpertResponse(detId, text, act, st);
      }
      return;
    }

    const mapFieldBtn = t.closest('[data-analytics-map-field]');
    if (mapFieldBtn) {
      const fid = mapFieldBtn.getAttribute('data-analytics-map-field');
      if (fid) {
        mapViewState.scope = 'field:' + fid;
        syncMapScopeTriggerLabel();
        rebuildMapLayers(true);
        closeDrawer();
      }
      return;
    }

    const showDetMap = t.closest('[data-drawer-show-det-on-map]');
    if (showDetMap) {
      const detId = showDetMap.getAttribute('data-drawer-show-det-on-map');
      if (detId) {
        focusDetectionOnMap(detId);
      }
      return;
    }

    const placeDet = t.closest('[data-drawer-place-det-in-field]');
    if (placeDet) {
      const detId = placeDet.getAttribute('data-drawer-place-det-in-field');
      if (detId) {
        void placeDetectionInAssignedField(detId, placeDet instanceof HTMLButtonElement ? placeDet : null);
      }
      return;
    }

    const boundaryField = t.closest('[data-drawer-boundary-field]');
    if (boundaryField) {
      const bfid = boundaryField.getAttribute('data-drawer-boundary-field');
      if (bfid) {
        void focusFieldBoundaryOnMap(bfid);
      }
      return;
    }

    const saveF = t.closest('[data-drawer-save-field]');
    if (saveF) {
      const fid = saveF.getAttribute('data-drawer-save-field');
      const row = saveF.closest('tr');
      if (!fid || !row) return;
      const nameIn = row.querySelector('[data-field-edit-name="' + fid + '"]');
      const addrIn = row.querySelector('[data-field-edit-address="' + fid + '"]');
      if (!(nameIn instanceof HTMLInputElement) || !(addrIn instanceof HTMLInputElement)) return;
      const name = nameIn.value.trim();
      if (!name) {
        toast('Field name is required.', true);
        return;
      }
      const address = addrIn.value.trim();
      saveF.disabled = true;
      try {
        const { error } = await supabase
          .from('fields')
          .update({
            name: name,
            address: address,
            updated_at: new Date().toISOString(),
          })
          .eq('id', fid);
        if (error) throw error;
        for (let i = 0; i < cacheFields.length; i++) {
          if (String(cacheFields[i].id) === fid) {
            cacheFields[i].name = name;
            cacheFields[i].address = address;
            cacheFields[i].updated_at = new Date().toISOString();
            break;
          }
        }
        drawerEditingFieldId = null;
        toast('Field updated.');
        await loadDashboard();
        openDrawer('fields');
      } catch (e) {
        toast(e && e.message ? e.message : 'Save failed', true);
      } finally {
        saveF.disabled = false;
      }
      return;
    }

    if (t.closest('[data-drawer-cancel-field-edit]')) {
      drawerEditingFieldId = null;
      renderDrawer();
      return;
    }

    const editB = t.closest('[data-drawer-edit-field]');
    if (editB) {
      const fid = editB.getAttribute('data-drawer-edit-field');
      if (fid) {
        drawerEditingFieldId = fid;
        renderDrawer();
      }
      return;
    }

    const del = t.closest('[data-drawer-delete-field]');
    if (del) {
      const fid = del.getAttribute('data-drawer-delete-field');
      if (!fid || !confirm('Delete this field from the database?')) return;
      try {
        const { error } = await supabase.from('fields').delete().eq('id', fid);
        if (error) throw error;
        toast('Field deleted.');
        await loadDashboard();
        openDrawer('fields');
      } catch (e) {
        toast(e && e.message ? e.message : 'Delete failed', true);
      }
      return;
    }

    const saveProf = t.closest('[data-drawer-save-profile]');
    if (saveProf) {
      const pid = saveProf.getAttribute('data-drawer-save-profile');
      const row = saveProf.closest('tr');
      if (!pid || !row) return;
      const nameIn = row.querySelector('[data-profile-edit-name="' + pid + '"]');
      const emailIn = row.querySelector('[data-profile-edit-email="' + pid + '"]');
      if (!(nameIn instanceof HTMLInputElement) || !(emailIn instanceof HTMLInputElement)) return;
      const email = emailIn.value.trim();
      if (!email) {
        toast('Email is required.', true);
        return;
      }
      const display_name = nameIn.value.trim() || null;
      saveProf.disabled = true;
      try {
        const url = updateUserProfileFunctionUrlResolved();
        if (!url || url.indexOf('http') !== 0) {
          toast('Missing supabaseUrl in config.', true);
          return;
        }
        const {
          data: { session },
        } = await supabase.auth.getSession();
        if (!session) {
          toast('Not signed in.', true);
          return;
        }
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer ' + session.access_token,
            apikey: cfg.supabaseAnonKey,
          },
          body: JSON.stringify({
            user_id: pid,
            email: email,
            display_name: display_name,
          }),
        });
        const j = await res.json().catch(function () {
          return {};
        });
        if (!res.ok) {
          throw new Error(j.error || 'Request failed');
        }
        const savedEmail = j.email || email.trim().toLowerCase();
        const nowIso = new Date().toISOString();
        for (let i = 0; i < cacheProfiles.length; i++) {
          if (String(cacheProfiles[i].id) === pid) {
            cacheProfiles[i].display_name = display_name;
            cacheProfiles[i].email = savedEmail;
            cacheProfiles[i].updated_at = nowIso;
            break;
          }
        }
        drawerEditingProfileId = null;
        toast('Profile and sign-in email updated.');
        populateMapScopeUi();
        rebuildMapLayers();
        renderDrawer();
      } catch (e) {
        toast(e && e.message ? e.message : 'Save failed', true);
      } finally {
        saveProf.disabled = false;
      }
      return;
    }

    if (t.closest('[data-drawer-cancel-profile-edit]')) {
      drawerEditingProfileId = null;
      renderDrawer();
      return;
    }

    const editProf = t.closest('[data-drawer-edit-profile]');
    if (editProf) {
      const pid = editProf.getAttribute('data-drawer-edit-profile');
      if (pid) {
        drawerEditingProfileId = pid;
        renderDrawer();
      }
      return;
    }

    const daApprove = t.closest('[data-da-request-approve]');
    if (daApprove) {
      const rid = daApprove.getAttribute('data-da-request-approve');
      if (!rid) return;
      const prof = cacheDaRequests.find(function (x) {
        return String(x.id) === rid;
      });
      const uid = prof ? prof.user_id : null;
      const label = uid ? profileDisplayName(uid) : 'this user';
      if (
        !confirm(
          'Approve DA access for ' +
            label +
            '?\n\nThey will need to sign out and sign in again on mobile and web.'
        )
      ) {
        return;
      }
      daApprove.disabled = true;
      await reviewDaAccessRequest(rid, 'approve');
      daApprove.disabled = false;
      return;
    }

    const daReject = t.closest('[data-da-request-reject]');
    if (daReject) {
      const rid = daReject.getAttribute('data-da-request-reject');
      if (!rid) return;
      if (!confirm('Reject this DA access request?')) {
        return;
      }
      daReject.disabled = true;
      await reviewDaAccessRequest(rid, 'reject');
      daReject.disabled = false;
      return;
    }

    const deleteProf = t.closest('[data-drawer-delete-profile]');
    if (deleteProf) {
      const pid = deleteProf.getAttribute('data-drawer-delete-profile');
      if (!pid) return;
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (session && session.user && session.user.id === pid) {
        toast('You cannot delete the account you are signed in as.', true);
        return;
      }
      const prof = cacheProfiles.find(function (x) {
        return String(x.id) === pid;
      });
      const label = prof
        ? profileDisplayName(pid) + (prof.email ? ' (' + prof.email + ')' : '')
        : pid;
      if (
        !confirm(
          'Permanently delete user ' +
            label +
            '?\n\nThis removes their Auth account, profile, fields, and captures (per database cascade). This cannot be undone.'
        )
      ) {
        return;
      }
      const url = deleteUserFunctionUrlResolved();
      if (!url || url.indexOf('http') !== 0) {
        toast('Missing supabaseUrl in config.', true);
        return;
      }
      if (!session) {
        toast('Not signed in.', true);
        return;
      }
      deleteProf.disabled = true;
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: 'Bearer ' + session.access_token,
            apikey: cfg.supabaseAnonKey,
          },
          body: JSON.stringify({ user_id: pid }),
        });
        const j = await res.json().catch(function () {
          return {};
        });
        if (!res.ok) {
          throw new Error(j.error || 'Request failed');
        }
        if (drawerEditingProfileId === pid) {
          drawerEditingProfileId = null;
        }
        toast('User deleted.');
        await loadDashboard();
        openDrawer('users');
      } catch (e) {
        toast(e && e.message ? e.message : 'Delete failed', true);
      } finally {
        deleteProf.disabled = false;
      }
      return;
    }
  });

  elDrawerContent.addEventListener('change', async function (ev) {
    const t = ev.target;
    if (!(t instanceof HTMLSelectElement)) return;
    if (!t.hasAttribute('data-drawer-assign-field')) return;
    if (!elDrawerContent.contains(t)) return;
    const fid = t.getAttribute('data-drawer-assign-field');
    if (!fid) return;
    try {
      const { error } = await supabase
        .from('fields')
        .update({ user_id: t.value, updated_at: new Date().toISOString() })
        .eq('id', fid);
      if (error) throw error;
      for (let i = 0; i < cacheFields.length; i++) {
        if (cacheFields[i].id === fid) {
          cacheFields[i].user_id = t.value;
          cacheFields[i].updated_at = new Date().toISOString();
          break;
        }
      }
      rebuildMapLayers();
      populateMapScopeUi();
      toast('Owner updated.');
    } catch (e) {
      toast(e && e.message ? e.message : 'Save failed', true);
    }
  });

  elDrawerContent.addEventListener('input', function (ev) {
    const t = ev.target;
    if (!(t instanceof HTMLInputElement)) return;
    if (!t.matches('[data-det-field], [data-det-lat], [data-det-lng]')) return;
    const detId =
      t.getAttribute('data-det-field') ||
      t.getAttribute('data-det-lat') ||
      t.getAttribute('data-det-lng');
    if (detId) {
      schedulePersistDetectionRow(detId);
    }
  });

  elDrawerContent.addEventListener(
    'blur',
    function (ev) {
      const t = ev.target;
      if (!(t instanceof HTMLInputElement)) return;
      if (!t.matches('[data-det-field], [data-det-lat], [data-det-lng]')) return;
      const detId =
        t.getAttribute('data-det-field') ||
        t.getAttribute('data-det-lat') ||
        t.getAttribute('data-det-lng');
      if (!detId) return;
      clearTimeout(detRowPersistTimers[detId]);
      delete detRowPersistTimers[detId];
      void persistDetectionDrawerRow(detId);
    },
    true
  );

  document.addEventListener('click', async function (ev) {
    const t = ev.target;
    if (!(t instanceof Element)) return;
    const replySave = t.closest('[data-expert-reply-save]');
    if (!replySave) return;
    const popup = replySave.closest('.leaflet-popup-content');
    if (!popup) return;
    const detId = replySave.getAttribute('data-expert-reply-save');
    if (!detId) return;
    const textEl = popup.querySelector('[data-expert-reply-text="' + detId + '"]');
    const actEl = popup.querySelector('[data-expert-reply-action="' + detId + '"]');
    const st = popup.querySelector('[data-expert-reply-status="' + detId + '"]');
    const text = textEl instanceof HTMLTextAreaElement ? textEl.value : '';
    const act = actEl instanceof HTMLSelectElement ? actEl.value : '';
    await saveExpertResponse(detId, text, act, st);
  });

  document.addEventListener('change', function (ev) {
    if (bulkFieldSilent) return;
    const t = ev.target;
    if (t instanceof HTMLSelectElement && t.id === 'capture-bulk-field' && selectedDetIds.size > 0) {
      updateBulkBar();
      return;
    }
    if (
      t instanceof HTMLSelectElement &&
      t.hasAttribute('data-map-det-field') &&
      t.closest('.leaflet-popup-content')
    ) {
      const detId = t.getAttribute('data-map-det-field');
      if (detId) {
        schedulePersistCapture(detId);
      }
      return;
    }
    if (
      t instanceof HTMLSelectElement &&
      t.hasAttribute('data-field-popup-owner') &&
      t.closest('.leaflet-popup-content')
    ) {
      const fid = t.getAttribute('data-field-popup-owner');
      if (fid) {
        void persistFieldOwnerFromPopup(fid, t.value);
      }
      return;
    }
    if (
      t instanceof HTMLInputElement &&
      t.type === 'file' &&
      t.hasAttribute('data-field-preview-file')
    ) {
      const popup = t.closest('.leaflet-popup-content');
      const fid = t.getAttribute('data-field-preview-file');
      if (fid && popup) {
        void runFieldPreviewUpload(fid, popup);
      }
    }
  });

  async function loadDashboard() {
    show(elDashError, false);
    show(elDashBody, true);
    show(elDashLoading, true);
    if (elDashError) elDashError.textContent = '';

    if (ensureMap()) {
      rebuildMapLayers();
    }

    try {
      const [profilesRes, fieldsRes, detRes, expertRes, farmInsightRes, daReqRes] =
        await Promise.all([
        supabase.from('profiles').select('*').order('created_at', { ascending: false }),
        supabase.from('fields').select('*').order('created_at', { ascending: false }),
        supabase
          .from('detections')
          .select(
            'id, user_id, field_id, image_url, latitude, longitude, count, confidence, has_mealybugs, created_at'
          )
          .order('created_at', { ascending: false })
          .limit(DETECTIONS_LIMIT),
        supabase.from('expert_responses').select('*'),
        supabase.from('farm_insights').select('*').order('created_at', { ascending: false }),
        sessionIsFullAdmin
          ? supabase
              .from('da_access_requests')
              .select('*')
              .order('created_at', { ascending: false })
          : Promise.resolve({ data: [], error: null }),
      ]);

      if (profilesRes.error) throw profilesRes.error;
      if (fieldsRes.error) throw fieldsRes.error;
      if (detRes.error) throw detRes.error;
      if (expertRes.error && expertRes.error.code !== '42P01') {
        throw expertRes.error;
      }
      if (farmInsightRes.error && farmInsightRes.error.code !== '42P01') {
        throw farmInsightRes.error;
      }
      if (daReqRes.error && daReqRes.error.code !== '42P01') {
        throw daReqRes.error;
      }

      cacheProfiles = profilesRes.data || [];
      cacheFields = fieldsRes.data || [];
      cacheDetections = detRes.data || [];
      cacheExpertResponses = expertRes.error ? [] : expertRes.data || [];
      cacheFarmInsights = farmInsightRes.error ? [] : farmInsightRes.data || [];
      cacheDaRequests = daReqRes.error ? [] : daReqRes.data || [];

      elStatAccounts.textContent = String(cacheProfiles.length);
      elStatFields.textContent = String(cacheFields.length);
      const posCount = positiveDetections(cacheDetections).length;
      elStatDetections.textContent = String(posCount) + ' pos / ' + String(cacheDetections.length) + ' total';

      show(elDashLoading, false);

      syncRoleUi();

      if (!ensureMap()) return;
      populateMapScopeUi();
      rebuildMapLayers();
      if (drawerSection) {
        renderDrawer();
      }
    } catch (e) {
      console.error(e);
      if (elDashError) {
        elDashError.textContent =
          e && e.message
            ? e.message
            : 'Load failed. Check admin RLS and app_metadata.admin.';
      }
      show(elDashLoading, false);
      show(elDashError, true);
    }
  }

  async function refreshSessionUi() {
    let { data } = await supabase.auth.getSession();
    let session = data.session;
    let user = session && session.user ? session.user : null;

    if (!user) {
      if (elSignedInLabel) {
        elSignedInLabel.textContent = '';
        elSignedInLabel.title = '';
      }
      setView('login');
      return;
    }

    // app_metadata in the JWT is fixed at token issue time. After you set staff flags in SQL,
    // a stale session still has the old claims until refresh or sign-in again.
    if (!isStaffUser(user)) {
      try {
        const { data: ref, error: refErr } = await supabase.auth.refreshSession();
        if (!refErr && ref.session && ref.session.user) {
          session = ref.session;
          user = ref.session.user;
        }
      } catch (_) {
        /* ignore */
      }
    }

    const roles = readJwtRoles(user);
    sessionUser = user;
    sessionIsFullAdmin = roles.fullAdmin;
    sessionIsDa = roles.da;

    const label = formatSessionUserLabel(user);
    if (elSignedInLabel) {
      elSignedInLabel.textContent = label;
      elSignedInLabel.title = label || '';
    }

    if (!isStaffUser(user)) {
      if (elNotAdminEmail) {
        elNotAdminEmail.textContent = label || 'this account';
      }
      setView('not_admin');
      return;
    }

    setView('dashboard');
    syncRoleUi();
    await loadDashboard();
  }

  document.querySelectorAll('[data-open-drawer]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      const s = btn.getAttribute('data-open-drawer');
      if (s === 'users' || s === 'fields' || s === 'captures' || s === 'analytics') {
        openDrawer(s);
      }
    });
  });

  const drawerClose = $('drawer-close');
  if (drawerClose) {
    drawerClose.addEventListener('click', closeDrawer);
  }

  if (elSignOutBtn) {
    elSignOutBtn.addEventListener('click', async function () {
      await supabase.auth.signOut();
      await refreshSessionUi();
    });
  }
  if (elNotAdminSignOut) {
    elNotAdminSignOut.addEventListener('click', async function () {
      await supabase.auth.signOut();
      await refreshSessionUi();
    });
  }

  elLoginForm.addEventListener('submit', async function (ev) {
    ev.preventDefault();
    elLoginError.hidden = true;
    elLoginError.textContent = '';
    const email = $('email').value.trim();
    const password = $('password').value;
    elLoginSubmit.disabled = true;
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      await refreshSessionUi();
    } catch (e) {
      elLoginError.textContent = e && e.message ? e.message : 'Sign-in failed';
      elLoginError.hidden = false;
    } finally {
      elLoginSubmit.disabled = false;
    }
  });

  supabase.auth.onAuthStateChange(function () {
    refreshSessionUi();
  });

  refreshSessionUi();
})();
