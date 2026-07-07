// Shared browser-session keep-alive and recovery for ETM client apps.
//
// The shared access cookie (etm_session) is short-lived and HttpOnly, so this times off the
// non-HttpOnly etm_session_exp hint cookie instead of reading the token: it refreshes ~60s before
// expiry via MyETM and, if that succeeds, reschedules. When the hint cookie is absent on load — the
// access cookie lapsed while the 24h refresh cookie may still be valid — it attempts a single guarded
// recovery and reloads, so a returning user is re-authenticated instead of being treated as a guest.
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
    const expiryMs = readExpiryMs();

    if (expiryMs) {
      window.sessionStorage.removeItem(RECOVERY_KEY);
      const delay = Math.max(expiryMs - Date.now() - 60_000, 0);
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

  schedule();
  return () => window.clearTimeout(timer);
}
