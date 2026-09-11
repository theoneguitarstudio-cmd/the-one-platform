"use client";

import { createContext, useCallback, useContext, useMemo, useRef, useState, useSyncExternalStore, type ReactNode } from "react";
import { createFixtures } from "./fixtures";
import { executeCommand, type Actor, type Command, type CommandResult, type PrototypeState, type Theme } from "./model";

const themeKey = "the-one-ux-prototype-theme";
const themeEvent = "the-one-ux-theme-change";
let memoryTheme: Theme = "dark";
function readTheme(): Theme {
  if (typeof window === "undefined") return "dark";
  try { const value = window.localStorage.getItem(themeKey); return value === "light" || value === "system" || value === "dark" ? value : memoryTheme; } catch { return memoryTheme; }
}
function subscribeTheme(listener: () => void) {
  window.addEventListener("storage", listener); window.addEventListener(themeEvent, listener);
  return () => { window.removeEventListener("storage", listener); window.removeEventListener(themeEvent, listener); };
}
type PrototypeContextValue = {
  state: PrototypeState; dispatch: (command: Command) => CommandResult; reset: () => void;
  actor: Actor; setActor: (actor: Actor) => void; studentId: string; setStudentId: (id: string) => void;
  theme: Theme; setTheme: (theme: Theme) => void;
  timeZone: string; setTimeZone: (timeZone: string) => void;
};
const PrototypeContext = createContext<PrototypeContextValue | null>(null);
export function PrototypeProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(createFixtures);
  const stateRef = useRef(state);
  const [actor, setActorState] = useState<Actor>({ role: "student", id: "s1" });
  const actorRef = useRef(actor);
  const [studentId, setStudentIdState] = useState("s1");
  const [timeZone, setTimeZone] = useState("Asia/Taipei");
  const theme = useSyncExternalStore(subscribeTheme, readTheme, () => "dark" as Theme);
  const dispatch = useCallback((command: Command) => {
    const outcome = executeCommand(stateRef.current, actorRef.current, command);
    if (outcome.result.ok) { stateRef.current = outcome.state; setState(outcome.state); }
    return outcome.result;
  }, []);
  const setActor = useCallback((next: Actor) => {
    if (actorRef.current.role === next.role && actorRef.current.id === next.id && actorRef.current.capability === next.capability) return;
    // A changed role never inherits an already-unmasked sensitive thread.
    if (stateRef.current.oversightAccess.length) { const clean = { ...stateRef.current, oversightAccess: [] }; stateRef.current = clean; setState(clean); }
    actorRef.current = next; setActorState(next);
  }, []);
  const setStudentId = useCallback((next: string) => {
    if (!stateRef.current.students.some((student) => student.id === next)) return;
    setStudentIdState(next);
    if (actorRef.current.role === "student") { const studentActor: Actor = { role: "student", id: next }; actorRef.current = studentActor; setActorState(studentActor); }
  }, []);
  const reset = useCallback(() => { const seed = createFixtures(); stateRef.current = seed; setState(seed); }, []);
  const setTheme = useCallback((next: Theme) => {
    memoryTheme = next;
    try { window.localStorage.setItem(themeKey, next); } catch { /* Appearance remains usable when storage is blocked. */ }
    window.dispatchEvent(new Event(themeEvent));
  }, []);
  const value = useMemo(() => ({ state, dispatch, reset, actor, setActor, studentId, setStudentId, theme, setTheme, timeZone, setTimeZone }), [state, dispatch, reset, actor, setActor, studentId, setStudentId, theme, setTheme, timeZone]);
  return <PrototypeContext.Provider value={value}>{children}</PrototypeContext.Provider>;
}
export function usePrototype() {
  const value = useContext(PrototypeContext);
  if (!value) throw new Error("UX prototype pages require PrototypeProvider.");
  return value;
}
