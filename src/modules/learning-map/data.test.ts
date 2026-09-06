import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ guard: vi.fn(), rpc: vi.fn(), client: vi.fn() }));
vi.mock("server-only", () => ({}));
vi.mock("@/modules/auth/server-authorization", () => ({ requireAreaAccess: mocks.guard }));
vi.mock("@/lib/supabase/server", () => ({ createServerSupabaseClient: mocks.client }));
import { getOwnLearningActivity, inspectLearningVersion, setOwnLearningActivity } from "./data";
const uuid = "97000000-0000-4000-8000-000000000001";
const command = { versionId: uuid, nodeId: uuid, requestId: uuid, expectedRevision: 0, patch: { opened: true } };
describe("server learning boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks(); mocks.guard.mockResolvedValue({ userId: uuid });
    mocks.client.mockResolvedValue({ rpc: mocks.rpc }); mocks.rpc.mockResolvedValue({ data: 1, error: null });
  });
  it("re-authorizes every call before database access", async () => {
    mocks.guard.mockRejectedValue(new Error("Denied"));
    await expect(setOwnLearningActivity(command)).rejects.toThrow("Denied");
    await expect(getOwnLearningActivity({ versionId: uuid, nodeId: uuid })).rejects.toThrow("Denied");
    await expect(inspectLearningVersion(uuid)).rejects.toThrow("Denied");
    expect(mocks.client).not.toHaveBeenCalled();
  });
  it("sends a narrow owner-inferred RPC payload", async () => {
    expect(await setOwnLearningActivity(command)).toBe(1);
    expect(mocks.guard).toHaveBeenCalledWith("student");
    expect(mocks.rpc).toHaveBeenCalledWith("learning_set_activity", { p_version: uuid, p_node: uuid, p_key: uuid, p_expected: 0, p_patch: { opened: true } });
  });
  it("rejects forged fields before invoking the RPC", async () => {
    await expect(setOwnLearningActivity({ ...command, subjectId: uuid })).rejects.toThrow();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it("does not convert unavailable authority into empty personal state", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "private database detail" } });
    await expect(getOwnLearningActivity({ versionId: uuid, nodeId: uuid })).rejects.toThrow("Learning activity is unavailable.");
  });
  it("uses Admin authorization for inspection and preserves absence", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: null });
    expect(await inspectLearningVersion(uuid)).toBeNull();
    expect(mocks.guard).toHaveBeenCalledWith("admin");
  });
});
