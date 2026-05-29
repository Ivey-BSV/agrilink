"use client";

import Link from "next/link";
import { UserAvatar } from "@/components/user-avatar";
import {
  directoryCertificationLine,
  directoryFarmDetailLines,
  directoryFarmStatsLine,
  directoryProfileSubtitle,
  type DirectoryEntry,
} from "@/lib/farm-directory";
import { formatFarmLabel } from "@/lib/farm-details";

type FarmDirectoryCardProps = {
  entry: DirectoryEntry;
};

export function FarmDirectoryCard({ entry }: FarmDirectoryCardProps) {
  const { profile, farm } = entry;
  const displayName = profile.full_name?.trim() || profile.username || "Farmer";
  const subtitle = directoryProfileSubtitle(profile);
  const farmName = farm?.farm_name?.trim();
  const statsLine = directoryFarmStatsLine(farm);
  const certLine = directoryCertificationLine(farm);
  const detailLines = directoryFarmDetailLines(farm);
  const overview = farm?.farm_overview?.trim() || profile.bio?.trim() || null;

  const profileFarmType = profile.farm_type?.trim();
  const experience = profile.experience_level?.trim();
  const showPills = Boolean(profileFarmType || experience);

  const hasFarmBlock = Boolean(
    farmName ||
      statsLine ||
      showPills ||
      certLine ||
      detailLines.length > 0 ||
      overview,
  );

  return (
    <Link href={`/platform/user/${profile.id}`} className="feed-author-row platform-directory-card-link farm-directory-card-inner">
      <UserAvatar url={profile.avatar_url} name={displayName} size={54} />
      <div className="farm-directory-card-body stack" style={{ gap: 6 }}>
        <div className="workshop-line-title">{displayName}</div>
        {subtitle ? <div className="workshop-line-meta">{subtitle}</div> : null}

        {hasFarmBlock ? (
          <div className="farm-directory-card-details stack" style={{ gap: 8 }}>
            {farmName ? <div className="farm-directory-farm-name">{farmName}</div> : null}
            {statsLine ? <div className="farm-directory-stats-line">{statsLine}</div> : null}
            {showPills ? (
              <div className="farm-directory-pill-row">
                {profileFarmType ? (
                  <span className="farm-directory-pill farm-directory-pill--type">{formatFarmLabel(profileFarmType)}</span>
                ) : null}
                {experience ? (
                  <span className="farm-directory-pill farm-directory-pill--experience">{formatFarmLabel(experience)}</span>
                ) : null}
              </div>
            ) : null}
            {certLine ? <div className="farm-directory-stats-line">{certLine}</div> : null}
            {detailLines.length > 0 ? (
              <ul className="farm-directory-detail-list">
                {detailLines.map((line) => (
                  <li key={line.label} className="farm-directory-detail-line">
                    <span className="farm-directory-detail-label">{line.label}</span>
                    <span className="farm-directory-detail-value">{line.value}</span>
                  </li>
                ))}
              </ul>
            ) : null}
            {overview ? <p className="farm-directory-overview subtle">{overview}</p> : null}
          </div>
        ) : (
          <p className="subtle" style={{ margin: 0 }}>
            No farm details added yet.
          </p>
        )}
      </div>
    </Link>
  );
}
