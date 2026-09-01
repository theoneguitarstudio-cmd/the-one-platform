import Link from "next/link";

import { adminCancelBooking, adminCreateFlexibleBooking, adminRescheduleBooking, adminSetSeriesStatus } from "@/modules/scheduling/actions";
import { listAdminSchedule } from "@/modules/scheduling/data";
import { formatSchedulingInstant } from "@/modules/scheduling/timezone";

type Props = { searchParams: Promise<{ from?: string; to?: string }> };

export default async function AdminSchedulePage({ searchParams }: Props) {
  const query = await searchParams;
  const from = query.from ?? "";
  const to = query.to ?? "";
  const bookings = from && to ? await listAdminSchedule(from, to) : [];
  return <main className="mx-auto max-w-6xl px-5 py-10">
    <Link href="/admin">← 返回管理區</Link>
    <h1 className="mt-5 text-3xl font-semibold">Schedule operations</h1>
    <p className="mt-2 text-sm text-[var(--text-secondary)]">營運視圖顯示 Booking、Lesson、Fixed source 與 credit reservation reference；高風險 mutation 必須走授權 RPC 並附理由。</p>
    <form className="mt-6 flex gap-3" method="get"><input className="rounded-xl border px-3 py-2" name="from" defaultValue={from} /><input className="rounded-xl border px-3 py-2" name="to" defaultValue={to} /><button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2">查詢</button></form>
    <section className="mt-8 rounded-2xl bg-[var(--surface)] p-5">
      <h2 className="text-xl font-semibold">Admin 代建 Flexible booking</h2>
      <form action={adminCreateFlexibleBooking} className="mt-4 grid gap-3 md:grid-cols-3">
        <input className="rounded-xl border bg-white px-3 py-2" name="studentUserId" placeholder="Student User ID" required /><input className="rounded-xl border bg-white px-3 py-2" name="teacherUserId" placeholder="Teacher User ID" required /><input className="rounded-xl border bg-white px-3 py-2" name="relationshipId" placeholder="Relationship ID" required />
        <input className="rounded-xl border bg-white px-3 py-2" name="entitlementId" placeholder="Entitlement ID" required /><input className="rounded-xl border bg-white px-3 py-2" name="startsAt" placeholder="開始 ISO instant" required /><input className="rounded-xl border bg-white px-3 py-2" name="timezone" defaultValue="Asia/Taipei" required />
        <input name="idempotencyKey" type="hidden" value={crypto.randomUUID()} /><input className="rounded-xl border bg-white px-3 py-2 md:col-span-2" name="reason" placeholder="Admin override reason" required /><button className="rounded-xl bg-[var(--brand-yellow)] px-4 py-2 font-semibold">建立</button>
      </form>
    </section>
    <section className="mt-8 rounded-2xl border p-5">
      <h2 className="text-xl font-semibold">Fixed series override</h2>
      <form action={adminSetSeriesStatus} className="mt-4 grid gap-3 md:grid-cols-4"><input className="rounded-xl border px-3 py-2" name="seriesId" placeholder="Recurring Series ID" required /><select className="rounded-xl border px-3 py-2" name="status" defaultValue="paused"><option value="active">resume</option><option value="paused">pause</option><option value="ended">end</option></select><input className="rounded-xl border px-3 py-2" name="reason" placeholder="Admin reason" required /><button className="rounded-xl border px-4 py-2">更新 series</button></form>
    </section>
    <div className="mt-8 space-y-4">{bookings.length === 0 ? <p>此範圍沒有 Bookings。</p> : bookings.map((booking) => <article className="rounded-2xl border p-5" key={booking.booking_id}>
      <p className="font-semibold">{booking.source} · {booking.status}</p>
      <p className="mt-1">{formatSchedulingInstant(booking.starts_at, "Asia/Taipei")}（Asia/Taipei operational view）</p>
      <p className="mt-1 text-sm text-[var(--text-secondary)]">Student {booking.student_user_id} · Teacher {booking.teacher_user_id}</p>
      <p className="mt-1 text-xs">Booking {booking.booking_id} · Lesson {booking.lesson_id ?? "pending"} · Reservation {booking.credit_reservation_id ?? "none"}</p>
      {booking.status === "confirmed" || booking.status === "rescheduled" ? <div className="mt-4 grid gap-3 lg:grid-cols-2">
        <form action={adminRescheduleBooking} className="grid gap-2"><input name="bookingId" type="hidden" value={booking.booking_id} /><input className="rounded-xl border px-3 py-2" name="newStartsAt" placeholder="新 ISO instant" required /><input className="rounded-xl border px-3 py-2" name="timezone" defaultValue="Asia/Taipei" required /><input className="rounded-xl border px-3 py-2" name="reason" placeholder="Admin 改期原因" required /><button className="rounded-xl border px-4 py-2">原子改期</button></form>
        <form action={adminCancelBooking} className="grid gap-2"><input name="bookingId" type="hidden" value={booking.booking_id} /><select className="rounded-xl border px-3 py-2" name="creditOutcome" defaultValue="manual_review_required"><option value="released">release credit</option><option value="consumed">consume credit</option><option value="unchanged">unchanged</option><option value="manual_review_required">manual review</option></select><input className="rounded-xl border px-3 py-2" name="earningOutcome" defaultValue="future_integration" placeholder="Earning outcome" required /><input className="rounded-xl border px-3 py-2" name="reason" placeholder="Admin 取消原因" required /><button className="rounded-xl border px-4 py-2">取消</button></form>
      </div> : null}
    </article>)}</div>
  </main>;
}
