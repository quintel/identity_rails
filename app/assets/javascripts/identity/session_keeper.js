// Shared browser-session keep-alive and recovery for ETM client apps.
//
// The shared access cookie (etm_session) is short-lived and HttpOnly, so this times off the
// non-HttpOnly etm_session_exp hint cookie instead of reading the token: it refreshes ~60s before
// expiry via MyETM and, if that succeeds, reschedules. When the hint cookie is absent — the access
// cookie lapsed while the 24h refresh cookie may still be valid — it attempts a single guarded
// recovery and reloads, so a returning user is re-authenticated instead of being treated as a guest.
// Both decisions are re-made whenever the tab becomes visible again, so a machine that slept through
// its own timer recovers on wake.
//
// Framework-agnostic on purpose: wrap it in a Stimulus controller (importmap apps), call it from a
// bundled entrypoint, or mirror it in another stack. startSessionKeeper returns a teardown function.
const RECOVERY_KEY = "etm-session-recovery";

// Expiry (ms) of the shared session cookie, read from the non-HttpOnly etm_session_exp hint cookie.
const readExpiryMs = () => {
  const match = document.cookie.match(/(?:^|;\s*)etm_session_exp=([^;]+)/);
  const exp = match ? parseInt(decodeURIComponent(match[1]), 10) : NaN;
  return Number.isFinite(exp) ? exp * 1000 : null;
};

// credentials:"include" so the cross-subdomain POST carries MyETM's host-only etm_refresh cookie.
const refresh = (idpUrl) =>
  fetch(`${idpUrl}/session/refresh`, { method: "POST", credentials: "include" })
    .then((response) => response.ok)
    .catch(() => false);

export function startSessionKeeper({ idpUrl }) {
  let timer;

  const schedule = () => {
    window.clearTimeout(timer);
    const expiryMs = readExpiryMs();

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
    } else if (!window.sessionStorage.getItem(RECOVERY_KEY)) {
      window.sessionStorage.setItem(RECOVERY_KEY, "1");
      refresh(idpUrl).then((ok) => {
        if (ok) {
          window.sessionStorage.removeItem(RECOVERY_KEY);
          window.location.reload();
        }
      });
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
