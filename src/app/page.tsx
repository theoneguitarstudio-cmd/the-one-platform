export default function Home() {
  return (
    <main className="flex flex-1 items-center justify-center px-6 py-16 sm:px-10">
      <section className="w-full max-w-2xl rounded-2xl border border-[var(--border)] bg-white p-8 shadow-sm sm:p-12">
        <p className="mb-5 inline-flex rounded-full bg-[var(--brand-yellow)] px-3 py-1 text-sm font-semibold text-[var(--text-primary)]">
          Platform Foundation
        </p>
        <h1 className="text-4xl font-semibold tracking-tight text-[var(--text-primary)] sm:text-5xl">
          The One 樂玩吉他 2.0
        </h1>
        <p className="mt-6 text-base text-[var(--text-secondary)]">
          Environment / Build 正常。
        </p>
      </section>
    </main>
  );
}
