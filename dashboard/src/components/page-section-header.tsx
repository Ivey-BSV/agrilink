"use client";

import type { CSSProperties, ReactNode } from "react";
import { SectionInfoButton } from "@/components/section-info-button";

type PageSectionHeaderProps = {
  title: string;
  description: string;
  infoLabel?: string;
  action?: ReactNode;
  titleStyle?: CSSProperties;
};

type SectionTitleWithInfoProps = {
  title: string;
  description: string;
  infoLabel?: string;
  titleStyle?: CSSProperties;
  className?: string;
};

/** Title + info button only (e.g. below a back link on settings subpages). */
export function SectionTitleWithInfo({ title, description, infoLabel, titleStyle, className }: SectionTitleWithInfoProps) {
  return (
    <div className={`page-section-title-row${className ? ` ${className}` : ""}`}>
      <h2 className="section-title" style={{ margin: 0, ...titleStyle }}>
        {title}
      </h2>
      <SectionInfoButton text={description} label={infoLabel ?? `About ${title}`} />
    </div>
  );
}

/** Section title with an info (“i”) button instead of a visible description paragraph. */
export function PageSectionHeader({ title, description, infoLabel, action, titleStyle }: PageSectionHeaderProps) {
  return (
    <div className="page-section-header-row">
      <div className="page-section-header-main">
        <div className="page-section-title-row">
          <h2 className="section-title" style={{ margin: 0, ...titleStyle }}>
            {title}
          </h2>
          <SectionInfoButton text={description} label={infoLabel ?? `About ${title}`} />
        </div>
      </div>
      {action ? <div className="page-section-header-action">{action}</div> : null}
    </div>
  );
}
