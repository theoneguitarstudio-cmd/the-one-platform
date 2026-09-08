import { describe, expect, it, vi } from "vitest";
vi.mock("next/navigation",()=>({notFound:()=>{throw Error("NOT_FOUND");}}));
vi.mock("./mode",()=>({isMockDataMode:vi.fn()}));
vi.mock("@/components/learning/lesson-workspace",()=>({LessonWorkspace:()=>null}));
vi.mock("@/components/learning/stage-explorer",()=>({LearningStageExplorer:()=>null}));
import { isMockDataMode } from "./mode";
import LessonPage from "@/app/student/learn/[lessonId]/page";
import MapPage from "@/app/student/map/page";
describe("learning UX preview route boundary",()=>{
 it("refuses map and lesson outside mock",async()=>{
  vi.mocked(isMockDataMode).mockReturnValue(false);
  expect(()=>MapPage()).toThrow("NOT_FOUND");
  await expect(LessonPage({params:Promise.resolve({lessonId:"pulse"})})).rejects.toThrow("NOT_FOUND");
 });
 it.each(["song","unknown"])("does not open locked or unknown lesson %s",async lessonId=>{
  vi.mocked(isMockDataMode).mockReturnValue(true);
  await expect(LessonPage({params:Promise.resolve({lessonId})})).rejects.toThrow("NOT_FOUND");
 });
 it("opens known preview lesson without data service",async()=>{
  vi.mocked(isMockDataMode).mockReturnValue(true);
  expect(await LessonPage({params:Promise.resolve({lessonId:"pulse"})})).toBeTruthy();
  expect(MapPage()).toBeTruthy();
 });
});
