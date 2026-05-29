"use client";

import { formatFarmLabel } from "@/lib/farm-details";

type OptionChipPickerProps = {
  label: string;
  options: readonly string[];
  selected: string[];
  onChange: (next: string[]) => void;
  maxSelections?: number;
  formatOption?: (value: string) => string;
};

export function OptionChipPicker({
  label,
  options,
  selected,
  onChange,
  maxSelections,
  formatOption = formatFarmLabel,
}: OptionChipPickerProps) {
  const set = new Set(selected);

  const toggle = (value: string) => {
    const next = new Set(selected);
    if (next.has(value)) {
      next.delete(value);
    } else {
      if (maxSelections != null && next.size >= maxSelections) return;
      next.add(value);
    }
    onChange([...next]);
  };

  return (
    <div className="field option-chip-picker">
      <div className="option-chip-picker-head">
        <label>{label}</label>
        {maxSelections != null ? (
          <span className="subtle" style={{ fontSize: "0.8rem" }}>
            {selected.length}/{maxSelections}
          </span>
        ) : null}
      </div>
      <div className="option-chip-picker-wrap">
        {options.map((opt) => {
          const on = set.has(opt);
          const disabled = !on && maxSelections != null && selected.length >= maxSelections;
          return (
            <button
              key={opt}
              type="button"
              className={`option-chip${on ? " option-chip--on" : ""}`}
              disabled={disabled}
              aria-pressed={on}
              onClick={() => toggle(opt)}
            >
              {formatOption(opt)}
            </button>
          );
        })}
      </div>
    </div>
  );
}
