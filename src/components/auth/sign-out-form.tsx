import { signOut } from "@/modules/auth/actions";

export function SignOutForm() {
  return (
    <form action={signOut}>
      <button
        className="rounded-full border border-[var(--border)] px-4 py-2 text-sm font-semibold"
        type="submit"
      >
        登出
      </button>
    </form>
  );
}
