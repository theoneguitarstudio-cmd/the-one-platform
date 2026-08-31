const LOCAL_DATE_TIME_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/;

function partsInTimezone(date: Date, timeZone: string) {
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

export function isValidIanaTimezone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en", { timeZone }).format();
    return timeZone === "UTC" || timeZone.includes("/");
  } catch {
    return false;
  }
}

export function zonedLocalDateTimeToUtc(
  localDateTime: string,
  timeZone: string,
): string {
  const match = LOCAL_DATE_TIME_PATTERN.exec(localDateTime);
  if (!match || !isValidIanaTimezone(timeZone)) {
    throw new Error("Invalid IANA local date time.");
  }
  const [, year, month, day, hour, minute] = match;
  const desired = Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour),
    Number(minute),
  );
  let candidate = desired;
  for (let iteration = 0; iteration < 3; iteration += 1) {
    const actual = partsInTimezone(new Date(candidate), timeZone);
    const actualAsUtc = Date.UTC(
      actual.year,
      actual.month - 1,
      actual.day,
      actual.hour,
      actual.minute,
    );
    candidate += desired - actualAsUtc;
  }
  const verified = partsInTimezone(new Date(candidate), timeZone);
  if (
    verified.year !== Number(year) ||
    verified.month !== Number(month) ||
    verified.day !== Number(day) ||
    verified.hour !== Number(hour) ||
    verified.minute !== Number(minute)
  ) {
    throw new Error("The selected local time does not exist in this timezone.");
  }
  return new Date(candidate).toISOString();
}

export function formatInTimezone(
  isoDateTime: string,
  timeZone: string,
): string {
  return new Intl.DateTimeFormat("zh-TW", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone,
  }).format(new Date(isoDateTime));
}
