import Link from "next/link";

import {
  cancelTeacherBooking,
  completeTeacherBooking,
  createTeacherAvailabilityException,
  createTeacherAvailabilityRule,
  createTeacherRecurringSeries,
  materializeTeacherOccurrence,
  rescheduleTeacherBooking,
  setTeacherSeriesException,
  setTeacherSchedulingSettings,
  setTeacherSeriesStatus,
} from "@/modules/scheduling/actions";
import {
  getTeacherAvailabilityConfiguration,
  listTeacherRecurringSeries,
  listTeacherSchedulingBookings,
} from "@/modules/scheduling/data";
import { formatSchedulingInstant } from "@/modules/scheduling/timezone";

export default async function TeacherSchedulePage() {
  const [configuration, bookings, series] = await Promise.all([
    getTeacherAvailabilityConfiguration(),
    listTeacherSchedulingBookings(),
    listTeacherRecurringSeries(),
  ]);
  const settings = configuration[0];
  return <main className="mx-auto max-w-6xl px-5 py-10">
    <Link href="/teacher">← 返回老師區</Link>
    <h1 className="mt-5 text-3xl font-semibold">Availability 與固定課表</h1>

    <section className="mt-8 grid gap-5 lg:grid-cols-2">
      <form action={setTeacherSchedulingSettings} className="grid gap-3 rounded-2xl bg-[var(--surface)] p-5">
        <h2 className="text-xl font-semibold">排程設定</h2>
        <input className="rounded-xl border bg-white px-3 py-2" name="timezone" defaultValue={settings?.setting_timezone ?? "Asia/Taipei"} required />
        <label className="text-sm">最少提前分鐘<input className="mt-1 w-full rounded-xl border bg-white px-3 py-2" name="minimumBookingNoticeMinutes" type="number" defaultValue={settings?.minimum_booking_notice_minutes ?? 1440} /></label>
        <label className="text-sm">Booking horizon 天數<input className="mt-1 w-full rounded-xl border bg-white px-3 py-2" name="bookingHorizonDays" type="number" defaultValue={settings?.booking_horizon_days ?? 60} /></label>
        <label className="text-sm">Slot 間隔分鐘<input className="mt-1 w-full rounded-xl border bg-white px-3 py-2" name="slotIntervalMinutes" type="number" defaultValue={settings?.slot_interval_minutes ?? 10} /></label>
        <input className="rounded-xl border bg-white px-3 py-2" name="reason" placeholder="設定原因" required />
        <button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold">儲存設定</button>
      </form>
      <form action={createTeacherAvailabilityRule} className="grid gap-3 rounded-2xl border p-5">
        <h2 className="text-xl font-semibold">新增 recurring availability</h2>
        <input className="rounded-xl border px-3 py-2" name="weekday" type="number" min="0" max="6" placeholder="Weekday 0–6" required />
        <div className="grid grid-cols-2 gap-2"><input className="rounded-xl border px-3 py-2" name="localStartTime" type="time" required /><input className="rounded-xl border px-3 py-2" name="localEndTime" type="time" required /></div>
        <input className="rounded-xl border px-3 py-2" name="timezone" defaultValue={settings?.setting_timezone ?? "Asia/Taipei"} required />
        <div className="grid grid-cols-2 gap-2"><input className="rounded-xl border px-3 py-2" name="effectiveFrom" type="date" required /><input className="rounded-xl border px-3 py-2" name="effectiveUntil" type="date" /></div>
        <input className="rounded-xl border px-3 py-2" name="reason" placeholder="Availability 原因" required />
        <button className="rounded-xl border px-4 py-2 font-semibold">新增可預約時段</button>
      </form>
    </section>

    <section className="mt-10 rounded-2xl border p-5">
      <h2 className="text-xl font-semibold">單次 availability exception</h2>
      <form action={createTeacherAvailabilityException} className="mt-4 grid gap-3 md:grid-cols-3">
        <select className="rounded-xl border px-3 py-2" name="exceptionKind" defaultValue="unavailable"><option value="unavailable">unavailable / 假期</option><option value="opening">temporary opening</option></select>
        <input className="rounded-xl border px-3 py-2" name="startsAt" placeholder="開始 ISO instant" required />
        <input className="rounded-xl border px-3 py-2" name="endsAt" placeholder="結束 ISO instant" required />
        <input className="rounded-xl border px-3 py-2 md:col-span-2" name="reason" placeholder="例外原因（private）" required />
        <button className="rounded-xl border px-4 py-2 font-semibold">建立例外</button>
      </form>
    </section>

    <section className="mt-10"><h2 className="text-xl font-semibold">Weekly availability</h2>
      <div className="mt-4 grid gap-3 md:grid-cols-3">{configuration.filter((row) => row.rule_id).map((rule) =>
        <article className="rounded-xl border p-4" key={rule.rule_id}><p>週 {rule.weekday} · {rule.local_start_time}–{rule.local_end_time}</p><p className="text-sm text-[var(--text-secondary)]">{rule.setting_timezone}</p></article>)}</div>
    </section>

    <section className="mt-10 rounded-2xl bg-[var(--surface)] p-5"><h2 className="text-xl font-semibold">建立 Fixed recurring arrangement</h2>
      <form action={createTeacherRecurringSeries} className="mt-4 grid gap-3 md:grid-cols-3">
        <input className="rounded-xl border bg-white px-3 py-2" name="studentUserId" placeholder="Student User ID" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="relationshipId" placeholder="Relationship ID" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="preferredEntitlementId" placeholder="Preferred Entitlement ID（可空白）" />
        <input className="rounded-xl border bg-white px-3 py-2" name="weekday" type="number" min="0" max="6" placeholder="Weekday" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="localStartTime" type="time" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="durationMinutes" type="number" defaultValue="50" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="timezone" defaultValue={settings?.setting_timezone ?? "Asia/Taipei"} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="effectiveFrom" type="date" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="effectiveUntil" type="date" />
        <input className="rounded-xl border bg-white px-3 py-2" name="reason" placeholder="建立原因" required />
        <button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold">建立 Fixed series</button>
      </form>
    </section>

    <section className="mt-10"><h2 className="text-xl font-semibold">Fixed students / series</h2>
      <div className="mt-4 space-y-4">{series.map((item) => <article className="rounded-2xl border p-5" key={item.id}>
        <p className="font-semibold">Student {item.student_user_id} · 每週 {item.weekday} {item.local_start_time}</p>
        <p className="text-sm">{item.timezone} · {item.duration_minutes} 分鐘 · {item.status}</p>
        {item.status !== "ended" ? <form action={setTeacherSeriesStatus} className="mt-3 flex gap-2">
          <input name="seriesId" type="hidden" value={item.id} /><input className="rounded-xl border px-3 py-2" name="reason" placeholder="原因" required />
          <select className="rounded-xl border px-3 py-2" name="status" defaultValue={item.status === "paused" ? "active" : "paused"}><option value="active">resume</option><option value="paused">pause</option><option value="ended">end</option></select>
          <button className="rounded-xl border px-4 py-2">更新</button>
        </form> : null}
        {item.status === "active" ? <form action={materializeTeacherOccurrence} className="mt-3 grid gap-2 md:grid-cols-4">
          <input name="seriesId" type="hidden" value={item.id} />
          <input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
          <input className="rounded-xl border px-3 py-2" name="occurrenceDate" type="date" required />
          <input className="rounded-xl border px-3 py-2 md:col-span-2" name="entitlementId" placeholder="此 occurrence 使用的 Entitlement ID" required />
          <button className="rounded-xl border px-4 py-2">建立本次 Lesson</button>
        </form> : null}
        {item.status !== "ended" ? <form action={setTeacherSeriesException} className="mt-3 grid gap-2 md:grid-cols-4">
          <input name="seriesId" type="hidden" value={item.id} /><input name="exceptionKind" type="hidden" value="release" /><input name="releaseThisOccurrence" type="hidden" value="true" /><input name="replacementStartsAt" type="hidden" value="" /><input name="replacementEndsAt" type="hidden" value="" />
          <input className="rounded-xl border px-3 py-2" name="occurrenceDate" type="date" required /><input className="rounded-xl border px-3 py-2 md:col-span-2" name="reason" placeholder="單次請假／釋放原因" required /><button className="rounded-xl border px-4 py-2">釋放本次固定時段</button>
        </form> : null}
      </article>)}</div>
    </section>

    <section className="mt-10"><h2 className="text-xl font-semibold">Upcoming lessons</h2>
      <div className="mt-4 grid gap-4 md:grid-cols-2">{bookings.map((booking) => <article className="rounded-2xl border p-5" key={booking.id}>
        <p className="font-semibold">{booking.source} · {booking.status}</p><p>{formatSchedulingInstant(booking.starts_at, booking.timezone_anchor)}（{booking.timezone_anchor}）</p><p className="text-sm">Student {booking.student_user_id}</p>
        {booking.status === "confirmed" || booking.status === "rescheduled" ? <div className="mt-4 grid gap-3">
          <form action={rescheduleTeacherBooking} className="grid gap-2 md:grid-cols-3"><input name="bookingId" type="hidden" value={booking.id} /><input className="rounded-xl border px-3 py-2" name="newStartsAt" placeholder="新 ISO instant" required /><input className="rounded-xl border px-3 py-2" name="timezone" defaultValue={booking.timezone_anchor} required /><input className="rounded-xl border px-3 py-2" name="reason" placeholder="改期原因" required /><button className="rounded-xl border px-4 py-2">改期</button></form>
          <form action={cancelTeacherBooking} className="flex gap-2"><input name="bookingId" type="hidden" value={booking.id} /><input className="min-w-0 flex-1 rounded-xl border px-3 py-2" name="reason" placeholder="取消原因" required /><button className="rounded-xl border px-4 py-2">取消並釋放點數</button></form>
          <form action={completeTeacherBooking} className="grid gap-2"><input name="bookingId" type="hidden" value={booking.id} /><input className="rounded-xl border px-3 py-2" name="studentVisibleNotes" placeholder="學生可見筆記" /><input className="rounded-xl border px-3 py-2" name="privateTeacherNotes" placeholder="老師私人筆記" /><input className="rounded-xl border px-3 py-2" name="performanceSummary" placeholder="表現摘要" /><input className="rounded-xl border px-3 py-2" name="nextGoal" placeholder="下一目標" /><input className="rounded-xl border px-3 py-2" name="homework" placeholder="作業" /><button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold">完成 Lesson 並 consume credit</button></form>
        </div> : null}
      </article>)}</div>
    </section>
  </main>;
}
