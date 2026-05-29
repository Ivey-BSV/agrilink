"use client";

import { FarmDetailsRow, formatFarmLabel } from "@/lib/farm-details";

type FarmDetailsModalProps = {
  open: boolean;
  onClose: () => void;
  farm: FarmDetailsRow | null;
  isOwnProfile: boolean;
};

function hasFarmContent(farm: FarmDetailsRow | null): boolean {
  if (!farm) return false;
  return Boolean(
    farm.farm_overview?.trim() ||
      farm.farm_name?.trim() ||
      farm.farm_size ||
      (farm.crops?.length ?? 0) > 0 ||
      (farm.livestock?.length ?? 0) > 0 ||
      farm.farming_method ||
      farm.soil_type ||
      farm.irrigation_method ||
      farm.certification ||
      farm.established_date
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="farm-details-field">
      <div className="farm-details-label">{label}</div>
      <div>{value}</div>
    </div>
  );
}

function ListField({ label, items }: { label: string; items: string[] }) {
  if (items.length === 0) return null;
  return <Field label={label} value={items.map(formatFarmLabel).join(", ")} />;
}

export function FarmDetailsModal({ open, onClose, farm, isOwnProfile }: FarmDetailsModalProps) {
  if (!open) return null;

  const empty = !hasFarmContent(farm);

  return (
    <div className="backdrop active" role="dialog" aria-modal="true" aria-label="Farm details">
      <div className="absolute inset-0" onClick={onClose} />
      <div className="modal-content platform-create-modal farm-details-modal" style={{ opacity: 1, transform: "none" }}>
        <div className="stack" style={{ gap: 14 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10 }}>
            <h3 className="section-title" style={{ fontSize: "1.15rem", margin: 0 }}>
              Farm details
            </h3>
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Close
            </button>
          </div>

          {empty ? (
            <p className="subtle" style={{ margin: 0 }}>
              {isOwnProfile
                ? "No farm details yet. Add them from My profile → About."
                : "This member has not shared farm details yet."}
            </p>
          ) : (
            <div className="stack farm-details-body" style={{ gap: 12 }}>
              {farm?.farm_name?.trim() ? <Field label="Farm name" value={farm.farm_name.trim()} /> : null}
              {farm?.farm_overview?.trim() ? <Field label="Overview" value={farm.farm_overview.trim()} /> : null}
              {farm?.farm_size ? (
                <Field
                  label="Farm size"
                  value={`${farm.farm_size} ${formatFarmLabel(farm.farm_size_unit ?? "acres")}`}
                />
              ) : null}
              {farm?.crops ? <ListField label="Crops" items={farm.crops} /> : null}
              {farm?.livestock ? <ListField label="Livestock" items={farm.livestock} /> : null}
              {farm?.farming_method ? <Field label="Farming method" value={formatFarmLabel(farm.farming_method)} /> : null}
              {farm?.soil_type ? <Field label="Soil type" value={formatFarmLabel(farm.soil_type)} /> : null}
              {farm?.irrigation_method ? (
                <Field label="Irrigation" value={formatFarmLabel(farm.irrigation_method)} />
              ) : null}
              {farm?.certification ? <Field label="Certification" value={formatFarmLabel(farm.certification)} /> : null}
              {farm?.established_date ? <Field label="Established" value={farm.established_date} /> : null}
              {farm?.farm_scale ? <Field label="Farm scale" value={formatFarmLabel(farm.farm_scale)} /> : null}
              {farm?.farm_type && farm.farm_type.length > 0 ? (
                <ListField label="Farm types" items={farm.farm_type} />
              ) : null}
              {farm?.activities && farm.activities.length > 0 ? (
                <ListField label="Activities" items={farm.activities} />
              ) : null}
              {farm?.specializations && farm.specializations.length > 0 ? (
                <ListField label="Specializations" items={farm.specializations} />
              ) : null}
              {farm?.is_open_farm ? <Field label="Open farm" value="Yes — visitors welcome" /> : null}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
