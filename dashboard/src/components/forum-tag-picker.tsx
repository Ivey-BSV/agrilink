"use client";

import { FORUM_TAG_CATEGORIES } from "@/lib/forum-tag-categories";

type ForumTagPickerProps = {
  selected: string[];
  onChange: (next: string[]) => void;
};

export function ForumTagPicker({ selected, onChange }: ForumTagPickerProps) {
  const set = new Set(selected);

  const toggle = (tag: string) => {
    const next = new Set(selected);
    if (next.has(tag)) next.delete(tag);
    else next.add(tag);
    onChange([...next]);
  };

  return (
    <div className="forum-tag-picker stack" style={{ gap: 18 }}>
      {Object.entries(FORUM_TAG_CATEGORIES).map(([category, tags]) => (
        <div key={category} className="stack" style={{ gap: 10 }}>
          <div style={{ fontWeight: 700, fontSize: "0.95rem", color: "var(--text)" }}>{category}</div>
          <div className="forum-tag-picker-wrap">
            {tags.map((tag) => {
              const on = set.has(tag);
              return (
                <button
                  key={tag}
                  type="button"
                  className={`forum-tag-chip${on ? " forum-tag-chip--on" : ""}`}
                  onClick={() => toggle(tag)}
                  aria-pressed={on}
                >
                  {tag}
                </button>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
