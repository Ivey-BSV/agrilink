"use client";

import { useEffect, useId, useRef, useState } from "react";

type SectionInfoButtonProps = {
  text: string;
  label?: string;
};

/** Compact “i” control that reveals section help text in a popover. */
export function SectionInfoButton({ text, label }: SectionInfoButtonProps) {
  const [open, setOpen] = useState(false);
  const popoverId = useId();
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div className="section-info-wrap" ref={wrapRef}>
      <button
        type="button"
        className="section-info-btn"
        aria-label={label ?? "Section information"}
        aria-expanded={open}
        aria-controls={popoverId}
        onClick={() => setOpen((value) => !value)}
      >
        <span aria-hidden>i</span>
      </button>
      {open ? (
        <div id={popoverId} role="tooltip" className="section-info-popover">
          {text}
        </div>
      ) : null}
    </div>
  );
}
