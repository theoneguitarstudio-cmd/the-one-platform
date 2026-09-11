import Image from "next/image";
import styles from "./brand-logo.module.css";

/** OWNER's original asset. Compact mode only clips its circular mark in CSS. */
export function BrandLogo({ compact = false, size = "normal" }: { compact?: boolean; size?: "small" | "normal" | "large" }) {
  return <span className={`${styles.logo} ${styles[size]} ${compact ? styles.compact : ""}`} data-brand-logo={compact ? "compact" : "full"}>
    <Image src="/brand/the-one-logo.png" alt="The One 樂玩吉他" width={2667} height={765} unoptimized className={styles.image} />
  </span>;
}
