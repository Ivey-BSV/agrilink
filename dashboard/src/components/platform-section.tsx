"use client";

import { motion, type HTMLMotionProps } from "framer-motion";
import type { HTMLAttributes, ReactNode } from "react";

const PAGE_MOTION = {
  initial: { opacity: 0, y: 6 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.2 },
} as const;

type PlatformPageShellProps = HTMLMotionProps<"div"> & {
  variant?: "card" | "stack";
  children: ReactNode;
};

/** Standard page wrapper — single card for list pages, stacked cards for detail flows. */
export function PlatformPageShell({ variant = "card", className, children, ...rest }: PlatformPageShellProps) {
  const base = variant === "card" ? "content-card stack platform-page-card" : "stack platform-page-shell";
  return (
    <motion.div className={`${base}${className ? ` ${className}` : ""}`} {...PAGE_MOTION} {...rest}>
      {children}
    </motion.div>
  );
}

type PlatformSectionCardProps = HTMLAttributes<HTMLDivElement> & {
  children: ReactNode;
};

export function PlatformSectionCard({ className, children, ...rest }: PlatformSectionCardProps) {
  return (
    <div className={`content-card stack platform-section-card${className ? ` ${className}` : ""}`} {...rest}>
      {children}
    </div>
  );
}

type PlatformSectionIntroProps = {
  title: string;
  description?: string;
  titleAs?: "h2" | "h3";
  action?: ReactNode;
};

/** Section title + helper text — matches poll detail card intros. */
export function PlatformSectionIntro({ title, description, titleAs = "h3", action }: PlatformSectionIntroProps) {
  const Tag = titleAs;
  return (
    <div className={`platform-section-intro${action ? " platform-section-intro--split" : ""}`}>
      <div className="platform-section-intro-main">
        <Tag className="section-title platform-section-intro-title">{title}</Tag>
        {description ? <p className="subtle platform-section-intro-desc">{description}</p> : null}
      </div>
      {action ? <div className="platform-section-intro-action">{action}</div> : null}
    </div>
  );
}

export function PlatformMetaRow({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={`platform-meta-row${className ? ` ${className}` : ""}`}>{children}</div>;
}
