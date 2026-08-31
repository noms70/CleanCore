import { useEffect, useRef, useCallback } from "react";
import { signOut } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";
import { auth, db } from "@/firebase";
import { useAuth } from "@/context/AuthContext";

/**
 * Tracks user activity (mouse, keyboard, touch, scroll) and signs
 * the user out after `timeoutMinutes` of inactivity.
 *
 * The timeout is only active when the `sessionTimeout` flag in
 * Firestore `settings/main → security.sessionTimeout` is **true**.
 *
 * Default timeout: 30 minutes.
 */
const ACTIVITY_EVENTS: (keyof WindowEventMap)[] = [
  "mousemove",
  "mousedown",
  "keydown",
  "touchstart",
  "scroll",
  "click",
];

export function useInactivityTimeout(timeoutMinutes = 30) {
  const { currentUser } = useAuth();
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const enabledRef = useRef(true); // tracks live Firestore value

  // ── Sign the user out and redirect ──────────────────────────────────────
  const handleTimeout = useCallback(() => {
    if (!currentUser) return;
    console.warn("[Session] Inactivity timeout — signing out.");
    signOut(auth).then(() => {
      // navigate is handled by ProtectedRoute seeing currentUser === null
      window.location.href = "/admin/login";
    });
  }, [currentUser]);

  // ── Reset the idle timer ────────────────────────────────────────────────
  const resetTimer = useCallback(() => {
    if (!enabledRef.current) return;
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(handleTimeout, timeoutMinutes * 60 * 1000);
  }, [handleTimeout, timeoutMinutes]);

  // ── Listen to the Firestore setting ─────────────────────────────────────
  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, "settings", "main"),
      (snap) => {
        const data = snap.data?.();
        const enabled = data?.security?.sessionTimeout ?? true;
        enabledRef.current = enabled;

        if (enabled) {
          resetTimer(); // start or restart the timer
        } else if (timerRef.current) {
          clearTimeout(timerRef.current); // setting disabled → cancel timer
        }
      },
      () => {
        // Firestore error (e.g. doc doesn't exist yet) — keep default: on
        enabledRef.current = true;
        resetTimer();
      }
    );
    return () => unsub();
  }, [resetTimer]);

  // ── Attach/detach activity listeners ────────────────────────────────────
  useEffect(() => {
    if (!currentUser) return;

    const onActivity = () => resetTimer();

    ACTIVITY_EVENTS.forEach((evt) =>
      window.addEventListener(evt, onActivity, { passive: true })
    );

    // Start the initial timer
    resetTimer();

    return () => {
      ACTIVITY_EVENTS.forEach((evt) =>
        window.removeEventListener(evt, onActivity)
      );
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [currentUser, resetTimer]);
}
