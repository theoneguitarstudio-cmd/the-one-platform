import type { ReactNode } from "react";

/** Visual content of the approved six-lesson slice. Business state lives in the mock module. */
export const lessonVisuals = [
  { id: "l1", title: "先找到穩定的拍子", hero: ["從穩定的", "拍子開始。"], module: 0, note: "找到自己的節拍", style: "beat" },
  { id: "l2", title: "認識切音與休止", hero: ["讓聲音停下，", "節拍不停。"], module: 0, note: "聽見聲音的留白", style: "pause" },
  { id: "l3", title: "把切音放進伴奏", hero: ["讓伴奏，", "有呼吸。"], module: 0, note: "把切音放回音樂", style: "breath" },
  { id: "l4", title: "練習不同的伴奏表情", hero: ["同一個和弦，", "不同的表情。"], module: 1, note: "把動作連接起來", style: "texture" },
  { id: "l5", title: "跟著伴奏試一次", hero: ["把練習，", "放進音樂。"], module: 1, note: "從練習走進音樂", style: "jam" },
  { id: "l6", title: "回顧這一站的練習", hero: ["停下來，", "聽見進步。"], module: 1, note: "回頭聽聽自己的演奏", style: "listen" },
];
export const modules = ["右手節奏與切音", "放進歌曲裡"];
export const studentNav = [["today", "home", "今日學習"], ["courses", "courses", "我的課程"], ["map", "map", "學習地圖"], ["practice", "practice", "我的練習"], ["private", "calendar", "私人課"], ["feedback", "chat", "師生回饋"]];
export const studentHref = (route = "today") => `/ux-prototype/student${route === "today" ? "" : `/${route}`}`;
export const lessonHref = (id = "l3", activity = "learn") => `/ux-prototype/student/courses/c1/lessons/${id}?activity=${activity}`;

const symbols: Record<string, ReactNode> = {
  home: <path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z" />,
  courses: <><path d="M5 4h14v16H5z" /><path d="M8 2H3v16M9 8h6M9 12h6M9 16h3" /></>,
  map: <path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2ZM9 3v16M15 5v16" />,
  practice: <><path d="M6 20 10 4h4l4 16Z" /><path d="m12 14 7-9M7 20h10" /><circle cx="12" cy="14" r="1.4" /></>,
  calendar: <><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M7 3v4M17 3v4M3 10h18M7 14h3M14 14h3M7 17h3" /></>,
  chat: <><path d="M21 11a8.5 8.5 0 0 1-9 8H6l-4 3 1-7a8 8 0 0 1-1-4 9 9 0 0 1 19 0Z" /><path d="M7 10h10M7 14h6" /></>,
  settings: <><path d="m9 3 1-1h4l1 3 3 1 2-1 2 4-2 2v3l2 2-2 4-3-1-2 1-1 3h-4l-1-3-3-1-2 1-2-4 2-2v-3L2 9l2-4 3 1 2-1Z" transform="translate(1 0) scale(.9)" /><circle cx="12" cy="12" r="3" /></>,
  expand: <><rect x="3" y="4" width="18" height="16" rx="1.5" /><path d="M8 4v16m4-11 3 3-3 3" /></>,
  collapse: <path d="m13 7-5 5 5 5m6-10-5 5 5 5" />,
  outline: <><rect x="3" y="4" width="18" height="16" rx="1.5" /><path d="M9 4v16M13 9h4M13 13h4" /></>,
  arrowUpRight: <path d="M7 17 17 7M7 7h10v10" />,
  arrow: <path d="M4 12h16m-6-6 6 6-6 6" />,
  down: <path d="m6 9 6 6 6-6" />,
  play: <path d="m7 4 14 8-14 8Z" />,
  playOutline: <><circle cx="12" cy="12" r="9" /><path d="m10 8 6 4-6 4Z" /></>,
  check: <path d="m6 12 4 4 8-9" />,
  circle: <circle cx="12" cy="12" r="8" />,
  lock: <><rect x="5" y="10" width="14" height="11" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" /></>,
  more: <><circle cx="5" cy="12" r=".7" /><circle cx="12" cy="12" r=".7" /><circle cx="19" cy="12" r=".7" /></>,
  volume: <path d="M3 9h4l5-4v14l-5-4H3ZM16 8a5 5 0 0 1 0 8M19 5a9 9 0 0 1 0 14" />,
  captions: <><rect x="2" y="5" width="20" height="14" rx="2" /><path d="M10 9H6v6h4m8-6h-4v6h4" /></>,
  fullscreen: <path d="M3 9V3h6m6 0h6v6M3 15v6h6m6 0h6v-6" />,
  file: <path d="M5 3h9l5 5v13H5ZM14 3v6h5M9 13h6M9 17h6" />,
  audio: <><path d="M9 17V5l12-2v12M9 8l12-2" /><ellipse cx="6" cy="18" rx="3" ry="2" /><ellipse cx="18" cy="16" rx="3" ry="2" /></>,
  left: <path d="m14 6-6 6 6 6" />,
  right: <path d="m10 6 6 6-6 6" />,
  close: <path d="m6 6 12 12M6 18 18 6" />,
  search: <><circle cx="10.5" cy="10.5" r="7" /><path d="m16 16 5 5" /></>,
  menu: <path d="M4 6h16M4 12h16M4 18h16" />,
  moon: <path d="M20 14a8 8 0 0 1-10-10 8.5 8.5 0 1 0 10 10Z" />,
  sun: <><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1 1M18 18l1 1M5 19l1-1M18 6l1-1" /></>,
  quote: <path d="M5 6h5v8H5V9m9-3h5v8h-5V9M10 14c0 3-2 5-5 5m14-5c0 3-2 5-5 5" />,
  flag: <path d="M5 22V3m0 0c5-4 9 4 14 0v11c-5 4-9-4-14 0" />,
  globe: <><circle cx="12" cy="12" r="9" /><ellipse cx="12" cy="12" rx="4" ry="9" /><path d="M3 12h18" /></>,
};
export function Icon({ name, className = "" }: { name: string; className?: string }) {
  return <svg className={className} viewBox="0 0 24 24" aria-hidden="true">{symbols[name] || symbols.circle}</svg>;
}
