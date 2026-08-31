import Image from "next/image";

type TeacherAvatarProps = {
  alt: string;
  name: string;
  size?: "card" | "detail";
  src: string | null;
};

export function TeacherAvatar({
  alt,
  name,
  size = "card",
  src,
}: TeacherAvatarProps) {
  const dimensions = size === "detail" ? 192 : 96;

  if (!src) {
    return (
      <div
        aria-label={alt}
        className={
          size === "detail"
            ? "flex h-48 w-48 items-center justify-center rounded-2xl bg-[var(--surface)] text-5xl font-semibold"
            : "flex h-24 w-24 items-center justify-center rounded-2xl bg-[var(--surface)] text-2xl font-semibold"
        }
        role="img"
      >
        {name.slice(0, 1)}
      </div>
    );
  }

  return (
    <Image
      alt={alt}
      className={
        size === "detail"
          ? "h-48 w-48 rounded-2xl object-cover"
          : "h-24 w-24 rounded-2xl object-cover"
      }
      height={dimensions}
      src={src}
      unoptimized
      width={dimensions}
    />
  );
}
