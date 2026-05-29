"use client";

import Link from "next/link";
import {
  buildFarmDetailEntries,
  formatFarmLabel,
  hasFarmDetailsContent,
  type FarmDetailsRow,
} from "@/lib/farm-details";

type FarmDetailsModalProps = {
  open: boolean;
  onClose: () => void;
  farm: FarmDetailsRow | null;
  isOwnProfile: boolean;
};

function FarmDetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="farm-details-row">
      <div className="farm-details-row-label">{label}</div>
      <div className="farm-details-row-value">{value}</div>
    </div>
  );
}

export function FarmDetailsModal({ open, onClose, farm, isOwnProfile }: FarmDetailsModalProps) {
  if (!open) return null;

  const hasContent = hasFarmDetailsContent(farm);
  const entries = farm ? buildFarmDetailEntries(farm) : [];
  const scaleBadge = farm?.farm_scale?.trim() ? formatFarmLabel(farm.farm_scale) : null;
  const certBadge = farm?.certification?.trim() ? formatFarmLabel(farm.certification) : null;
  const showBadges = Boolean(scaleBadge || certBadge);

  return (
    <div
      className="backdrop active farm-details-backdrop"
      role="dialog"
      aria-modal="true"
      aria-label="Farm details"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="farm-details-sheet">
        <div className="farm-details-handle" aria-hidden />

        <div className="farm-details-scroll">
          <h2 className="farm-details-title">Farm Details</h2>

          {!hasContent ? (
            <p className="farm-details-empty">No farm details available.</p>
          ) : (
            <>
              {showBadges ? (
                <div className="farm-details-badges">
                  {scaleBadge ? (
                    <span className="farm-details-badge farm-details-badge--scale">{scaleBadge}</span>
                  ) : null}
                  {certBadge ? (
                    <span className="farm-details-badge farm-details-badge--cert">
                      <span className="farm-details-badge-icon" aria-hidden>
                        ✓
                      </span>
                      {certBadge}
                    </span>
                  ) : null}
                </div>
              ) : null}

              <div className="farm-details-rows">
                {entries.map((entry) => (
                  <FarmDetailRow key={entry.label} label={entry.label} value={entry.value} />
                ))}
              </div>
            </>
          )}
        </div>

        <div className="farm-details-footer">
          {isOwnProfile ? (
            <div className="farm-details-footer-actions">
              <Link
                href="/platform/profile/farm-details"
                className="btn btn-secondary farm-details-footer-btn"
                onClick={onClose}
              >
                Edit
              </Link>
              <button type="button" className="btn btn-primary farm-details-footer-btn" onClick={onClose}>
                Close
              </button>
            </div>
          ) : (
            <button type="button" className="btn btn-primary farm-details-footer-btn farm-details-footer-btn--full" onClick={onClose}>
              Close
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
