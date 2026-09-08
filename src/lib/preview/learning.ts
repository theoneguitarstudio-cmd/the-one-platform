// UX-only synthetic examples. Not curriculum, enrollment or verified achievement.
export const learningPreview = {
  student: "小宇", stage: 1, progress: 38, course: "The One Guitar Roadmap 2.0",
  lessons: [
    { id: "listen", title: "先聽見歌曲的脈動", objective: "跟著音樂，穩定地數出四拍。", minutes: 6, state: "completed" },
    { id: "pulse", title: "讓你的右手，找到穩定節奏", objective: "讓右手持續擺動，用四分音符穩定伴奏。", minutes: 12, state: "current" },
    { id: "chords", title: "把和弦接成一句音樂", objective: "在不打斷節拍的情況下，練習兩個和弦的轉換。", minutes: 10, state: "upcoming" },
    { id: "song", title: "用一首歌，留下今天的進步", objective: "把節奏與和弦放回歌曲，完整演奏一段。", minutes: 15, state: "locked" },
  ],
  stages: [
    "我可以把一首歌完整彈完", "我的伴奏不再只有一種", "我開始知道自己在彈什麼",
    "我可以慢慢離開樂譜", "我可以自己改歌、加旋律、加 Solo", "我可以自己處理一首陌生歌曲",
  ],
} as const;
