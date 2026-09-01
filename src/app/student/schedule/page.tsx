import Link from "next/link";

import { createFlexibleBooking, cancelOwnBooking, rescheduleOwnBooking } from "@/modules/scheduling/actions";
import { findFlexibleSlots, listOwnRecurringSeries, listOwnSchedulingBookings } from "@/modules/scheduling/data";
import { formatSchedulingInstant } from "@/modules/scheduling/timezone";

type Props = {
  searchParams: Promise<{
    entitlementId?: string;
    from?: string;
    relationshipId?: string;
    teacherId?: string;
    timezone?: string;
    to?: string;
  }>;
};

export default async function StudentSchedulePage({ searchParams }: Props) {
  const query = await searchParams;
  const bookingsPromise = listOwnSchedulingBookings();
  const seriesPromise = listOwnRecurringSeries();
  const canSearch = query.teacherId && query.entitlementId && query.from && query.to;
  const slotsPromise = canSearch ? findFlexibleSlots({
    entitlementId: query.entitlementId!,
    from: query.from!,
    teacherUserId: query.teacherId!,
    to: query.to!,
  }) : Promise.resolve([]);
  const [bookings, series, slots] = await Promise.all([bookingsPromise, seriesPromise, slotsPromise]);
  const timezone = query.timezone || "Asia/Taipei";

  return <main className="mx-auto max-w-6xl px-5 py-10">
    <Link href="/student">← 返回學生區</Link>
    <h1 className="mt-5 text-3xl font-semibold">課程與預約</h1>
    <p className="mt-2 text-sm text-[var(--text-secondary)]">Flexible 預約與 Fixed 固定課都使用同一套 Lesson Credits。所有時間均顯示 timezone。</p>

    <section className="mt-8 rounded-2xl bg-[var(--surface)] p-5">
      <h2 className="text-xl font-semibold">查詢 Flexible 可預約時段</h2>
      <form className="mt-4 grid gap-3 md:grid-cols-3" method="get">
        <input className="rounded-xl border bg-white px-3 py-2" name="teacherId" placeholder="Teacher User ID" defaultValue={query.teacherId} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="relationshipId" placeholder="Relationship ID" defaultValue={query.relationshipId} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="entitlementId" placeholder="Entitlement ID" defaultValue={query.entitlementId} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="from" placeholder="From ISO instant" defaultValue={query.from} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="to" placeholder="To ISO instant" defaultValue={query.to} required />
        <input className="rounded-xl border bg-white px-3 py-2" name="timezone" defaultValue={timezone} required />
        <button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold" type="submit">查詢安全 slots</button>
      </form>
      <div className="mt-5 grid gap-3 md:grid-cols-2">{slots.map((slot) =>
        <form action={createFlexibleBooking} className="rounded-xl border bg-white p-4" key={slot.starts_at}>
          <input name="teacherUserId" type="hidden" value={query.teacherId} />
          <input name="relationshipId" type="hidden" value={query.relationshipId} />
          <input name="entitlementId" type="hidden" value={query.entitlementId} />
          <input name="startsAt" type="hidden" value={slot.starts_at} />
          <input name="timezone" type="hidden" value={timezone} />
          <input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} />
          <p className="font-semibold">{formatSchedulingInstant(slot.starts_at, timezone)}</p>
          <p className="text-sm text-[var(--text-secondary)]">老師時間：{formatSchedulingInstant(slot.starts_at, slot.teacher_timezone)}（{slot.teacher_timezone}） · {slot.lesson_duration_minutes} 分鐘</p>
          <button className="mt-3 rounded-xl border px-4 py-2 font-semibold" type="submit">確認預約</button>
        </form>)}</div>
    </section>

    <section className="mt-10"><h2 className="text-xl font-semibold">我的 Lessons / Bookings</h2>
      <div className="mt-4 space-y-4">{bookings.length === 0 ? <p>目前沒有預約。</p> : bookings.map((booking) =>
        <article className="rounded-2xl border p-5" key={booking.id}>
          <p className="font-semibold">{booking.source} · {booking.status}</p>
          <p className="mt-1">{formatSchedulingInstant(booking.starts_at, booking.timezone_anchor)}（{booking.timezone_anchor}）</p>
          {booking.status === "confirmed" || booking.status === "rescheduled" ? <div className="mt-4 grid gap-3 lg:grid-cols-2">
            <form action={cancelOwnBooking} className="flex gap-2">
              <input name="bookingId" type="hidden" value={booking.id} />
              <input name="creditOutcome" type="hidden" value="released" />
              <input className="min-w-0 flex-1 rounded-xl border px-3 py-2" name="reason" placeholder="取消原因" required />
              <button className="rounded-xl border px-4 py-2" type="submit">取消並釋放點數</button>
            </form>
            <form action={rescheduleOwnBooking} className="grid grid-cols-2 gap-2">
              <input name="bookingId" type="hidden" value={booking.id} />
              <input className="rounded-xl border px-3 py-2" name="newStartsAt" placeholder="新 UTC/ISO 時間" required />
              <input className="rounded-xl border px-3 py-2" name="timezone" value={booking.timezone_anchor} readOnly />
              <input className="rounded-xl border px-3 py-2" name="reason" placeholder="改期原因" required />
              <button className="rounded-xl border px-4 py-2" type="submit">原子改期</button>
            </form>
          </div> : null}
        </article>)}</div>
    </section>

    <section className="mt-10"><h2 className="text-xl font-semibold">Fixed 固定安排</h2>
      <div className="mt-4 grid gap-4 md:grid-cols-2">{series.length === 0 ? <p>目前沒有固定安排。</p> : series.map((item) =>
        <article className="rounded-2xl border p-5" key={item.id}>
          <p className="font-semibold">每週 {item.weekday} · {item.local_start_time}</p>
          <p className="mt-1 text-sm">{item.timezone} · {item.duration_minutes} 分鐘 · {item.status}</p>
          <p className="mt-1 text-sm">{item.effective_from} 起，方案到期不會刪除此安排。</p>
        </article>)}</div>
    </section>
  </main>;
}
