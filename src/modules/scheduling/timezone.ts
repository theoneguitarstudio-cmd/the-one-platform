const LOCAL_DATE_TIME_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;

type LocalParts = {
  day: number;
  hour: number;
  minute: number;
  month: number;
  year: number;
};

function partsInTimezone(date: Date, timeZone: string): LocalParts {
  const parts = new Intl.DateTimeFormat("en-CA", {
    day: "2-digit",
    hour: "2-digit",
    hour12: false,
    hourCycle: "h23",
    minute: "2-digit",
    month: "2-digit",
    timeZone,
    year: "numeric",
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value);
  return {
    day: value("day"),
    hour: value("hour"),
    minute: value("minute"),
    month: value("month"),
    year: value("year"),
  };
}

function sameParts(left: LocalParts, right: LocalParts) {
  return left.year === right.year && left.month === right.month &&
    left.day === right.day && left.hour === right.hour &&
    left.minute === right.minute;
}

export function isValidSchedulingTimezone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en", { timeZone }).format();
    return timeZone === "UTC" || timeZone.includes("/");
  } catch {
    return false;
  }
}

export function resolveSchedulingLocalDateTime(
  localDateTime: string,
  timeZone: string,
): string {
  const match = LOCAL_DATE_TIME_PATTERN.exec(localDateTime);
  if (!match || !isValidSchedulingTimezone(timeZone)) {
    throw new Error("INVALID_SCHEDULING_TIMEZONE");
  }
  const desired: LocalParts = {
    day: Number(match[3]),
    hour: Number(match[4]),
    minute: Number(match[5]),
    month: Number(match[2]),
    year: Number(match[1]),
  };
  const center = Date.UTC(
    desired.year,
    desired.month - 1,
    desired.day,
    desired.hour,
    desired.minute,
  );
  const matches: number[] = [];
  for (let offsetMinutes = -14 * 60; offsetMinutes <= 14 * 60; offsetMinutes += 15) {
    const candidate = center + offsetMinutes * 60_000;
    if (sameParts(partsInTimezone(new Date(candidate), timeZone), desired)) {
      matches.push(candidate);
    }
  }
  if (matches.length === 0) throw new Error("NONEXISTENT_LOCAL_TIME");
  if (matches.length > 1) throw new Error("AMBIGUOUS_LOCAL_TIME");
  return new Date(matches[0]).toISOString();
}

export function formatSchedulingInstant(iso: string, timeZone: string) {
  return new Intl.DateTimeFormat("zh-TW", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone,
  }).format(new Date(iso));
}

export function weeklyOccurrenceDates(
  effectiveFrom: string,
  weekday: number,
  throughDate: string,
  limit = 60,
) {
  const current = new Date(effectiveFrom + "T00:00:00.000Z");
  const through = new Date(throughDate + "T00:00:00.000Z");
  const dates: string[] = [];
  while (current <= through && dates.length < limit) {
    if (current.getUTCDay() === weekday) dates.push(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}
