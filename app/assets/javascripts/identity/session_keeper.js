// Shared browser-session keep-alive and recovery for ETM client apps.
//
// The shared access cookie is short-lived and HttpOnly, so this times off the companion
// non-HttpOnly expiry hint cookie instead of reading the token: it refreshes ~60s before
// expiry via MyETM and, if that succeeds, reschedules. When the hint cookie is absent — the access
// cookie lapsed while the 24h refresh cookie may still be valid — it attempts a single guarded
// recovery and reloads, so a returning user is re-authenticated instead of being treated as a guest.
// Both decisions are re-made whenever the tab becomes visible again, so a machine that slept through
// its own timer recovers on wake.
//
// Framework-agnostic on purpose: wrap it in a Stimulus controller (importmap apps), call it from a
// bundled entrypoint, or mirror it in another stack. startSessionKeeper returns a teardown function.
const RECOVERY_KEY = "etm-session-recovery";

// Deployments sharing a cookie domain suffix their cookie names to tell their sessions apart, so
// the hint cookie's name is passed in rather than assumed. Bare name where nothing is suffixed.
const DEFAULT_EXP_COOKIE = "etm_session_exp";

// Expiry (ms) of the shared session cookie, read from the non-HttpOnly hint cookie.
const readExpiryMs = (expCookieName) => {
  const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${expCookieName}=([^;]+)`));
  const exp = match ? parseInt(decodeURIComponent(match[1]), 10) : NaN;
  return Number.isFinite(exp) ? exp * 1000 : null;
};

// credentials:"include" so the cross-subdomain POST carries MyETM's host-only etm_refresh cookie.
const refresh = (idpUrl) =>
  fetch(`${idpUrl}/session/refresh`, { method: "POST", credentials: "include" })
    .then((response) => response.ok)
    .catch(() => false);

// Attempts to slide a lapsed session back into life, once, and reloads if it worked.
//
// The access cookie has gone but the 24h refresh cookie may still be valid, so one refresh can turn
// "you were signed out" into a seamless return. Guarded by sessionStorage because a failed recovery
// followed by a reload is a redirect loop: a genuine guest, or someone whose refresh token was
// revoked by single-logout, gets a 401 here and must be left alone.
//
// Exported so the provider's own sign-in page can run it too — a visitor bounced to that page has
// no other chance to recover, and it must not drift from the keeper's copy of this logic.
export function recoverSession(idpUrl) {
  if (window.sessionStorage.getItem(RECOVERY_KEY)) return Promise.resolve(false);

  window.sessionStorage.setItem(RECOVERY_KEY, "1");

  return refresh(idpUrl).then((ok) => {
    if (ok) {
      window.sessionStorage.removeItem(RECOVERY_KEY);
      window.location.reload();
    }
    return ok;
  });
}

export function startSessionKeeper({ idpUrl, expCookieName = DEFAULT_EXP_COOKIE }) {
  let timer;

  const schedule = () => {
    window.clearTimeout(timer);
    const expiryMs = readExpiryMs(expCookieName);

    if (expiryMs) {
      window.sessionStorage.removeItem(RECOVERY_KEY);

      // Refresh a minute before expiry, or halfway through the remaining life when the session is
      // shorter than that — a minute's lead on a 30-second ACCESS_TTL (what the manual test
      // instructions ask for) would otherwise mean refreshing on a zero delay, forever.
      //
      // Plus 0-10s of jitter: without it every open tab, in every ETM app, refreshes on the same
      // tick, and the ones whose request was already in flight when the winner rotated the refresh
      // token present a token that has just been revoked.
      const remaining = expiryMs - Date.now();
      const lead = Math.min(60_000, Math.max(remaining / 2, 0));
      const delay = Math.max(remaining - lead + Math.random() * 10_000, 0);
      timer = window.setTimeout(() => {
        refresh(idpUrl).then((ok) => ok && schedule());
      }, delay);
    } else {
      recoverSession(idpUrl);
    }
  };

  // A sleeping machine does not run timers, and a backgrounded tab may have its own frozen or
  // dropped outright. Re-deciding whenever the tab becomes visible is what makes closing the laptop
  // lid for twenty minutes recover, rather than waiting for a tick that is never coming.
  const onVisible = () => document.visibilityState === "visible" && schedule();

  schedule();
  document.addEventListener("visibilitychange", onVisible);

  return () => {
    window.clearTimeout(timer);
    document.removeEventListener("visibilitychange", onVisible);
  };
}
