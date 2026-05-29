"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { supabase } from "@/lib/supabase";
import {
  deleteFarmDetails,
  emptyFarmDetailsDraft,
  farmDetailsRowToDraft,
  formatFarmLabel,
  loadFarmDetailsFull,
  saveFarmDetailsFull,
  type FarmDetailsDraft,
} from "@/lib/farm-details";
import {
  AGRITOURISM_OFFERINGS,
  AVAILABLE_CROPS,
  AVAILABLE_LIVESTOCK,
  CERTIFICATIONS,
  FARM_ACTIVITIES,
  FARM_GOALS,
  FARM_SCALES,
  FARM_SIZE_UNITS,
  FARM_TYPES,
  FARMING_METHODS,
  IRRIGATION_METHODS,
  SOIL_TYPES,
  SPECIALIZATIONS,
  VALUE_ADDED_PRODUCTS,
} from "@/lib/farm-details-options";
import { OptionChipPicker } from "@/components/option-chip-picker";

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="farm-edit-section content-card stack">
      <h2 className="farm-edit-section-title">{title}</h2>
      {children}
    </section>
  );
}

function SelectField({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: readonly string[];
  onChange: (value: string) => void;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      <select className="input" value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Not specified</option>
        {options.map((opt) => (
          <option key={opt} value={opt}>
            {formatFarmLabel(opt)}
          </option>
        ))}
      </select>
    </div>
  );
}

export function FarmDetailsEditPage() {
  const router = useRouter();
  const [draft, setDraft] = useState<FarmDetailsDraft>(emptyFarmDetailsDraft);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const patch = (partial: Partial<FarmDetailsDraft>) => {
    setDraft((prev) => ({ ...prev, ...partial }));
  };

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        if (!cancelled) {
          setError("Sign in to edit farm details.");
          setLoading(false);
        }
        return;
      }
      if (!cancelled) setUserId(user.id);

      const { row, error: loadErr } = await loadFarmDetailsFull(user.id);
      if (!cancelled) {
        if (loadErr) setError(loadErr);
        else setDraft(farmDetailsRowToDraft(row));
        setLoading(false);
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  const save = async (e: FormEvent) => {
    e.preventDefault();
    if (!userId) return;
    setSaving(true);
    setError(null);
    setSuccess(null);

    const { error: saveErr } = await saveFarmDetailsFull(userId, draft);
    if (saveErr) {
      setError(saveErr);
      setSaving(false);
      return;
    }

    setSuccess("Farm details saved.");
    setSaving(false);
    router.push("/platform/profile");
  };

  const removeAll = async () => {
    if (!userId) return;
    if (!confirm("Delete all farm details? This cannot be undone.")) return;
    setSaving(true);
    setError(null);
    const { error: delErr } = await deleteFarmDetails(userId);
    setSaving(false);
    if (delErr) {
      setError(delErr);
      return;
    }
    setDraft(emptyFarmDetailsDraft());
    setSuccess("Farm details deleted.");
  };

  if (loading) {
    return (
      <motion.div className="content-card">
        <p className="subtle">Loading farm details…</p>
      </motion.div>
    );
  }

  return (
    <motion.div className="stack farm-edit-page" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
      <div className="farm-edit-toolbar">
        <Link href="/platform/profile" className="btn btn-secondary">
          Back to profile
        </Link>
        <button type="submit" form="farm-details-form" className="btn btn-primary" disabled={saving}>
          {saving ? "Saving…" : "Save"}
        </button>
      </div>

      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      <form id="farm-details-form" className="stack farm-edit-form" onSubmit={save}>
        <Section title="Basic information">
          <div className="field">
            <label>Farm overview</label>
            <textarea
              rows={6}
              value={draft.farm_overview}
              onChange={(e) => patch({ farm_overview: e.target.value })}
              placeholder="Region, land, story—anything that helps others understand your farm."
            />
          </div>
          <div className="field">
            <label>Farm name</label>
            <input
              value={draft.farm_name}
              onChange={(e) => patch({ farm_name: e.target.value })}
              placeholder="Optional display name"
            />
          </div>
          <div className="farm-edit-row-2">
            <div className="field">
              <label>Farm size</label>
              <input
                type="number"
                min={0}
                step={1}
                value={draft.farm_size}
                onChange={(e) => patch({ farm_size: e.target.value })}
                placeholder="0"
              />
            </div>
            <SelectField
              label="Unit"
              value={draft.farm_size_unit}
              options={FARM_SIZE_UNITS}
              onChange={(farm_size_unit) => patch({ farm_size_unit })}
            />
          </div>
          <div className="field">
            <label>Established date</label>
            <input
              type="date"
              value={draft.established_date}
              onChange={(e) => patch({ established_date: e.target.value })}
            />
          </div>
        </Section>

        <Section title="Farming practices">
          <SelectField
            label="Farming method"
            value={draft.farming_method}
            options={FARMING_METHODS}
            onChange={(farming_method) => patch({ farming_method })}
          />
          <SelectField
            label="Soil type"
            value={draft.soil_type}
            options={SOIL_TYPES}
            onChange={(soil_type) => patch({ soil_type })}
          />
          <SelectField
            label="Irrigation"
            value={draft.irrigation_method}
            options={IRRIGATION_METHODS}
            onChange={(irrigation_method) => patch({ irrigation_method })}
          />
          <SelectField
            label="Certification"
            value={draft.certification}
            options={CERTIFICATIONS}
            onChange={(certification) => patch({ certification })}
          />
        </Section>

        <Section title="Crops">
          <OptionChipPicker
            label="Primary crops"
            options={AVAILABLE_CROPS}
            selected={draft.crops}
            onChange={(crops) => patch({ crops })}
            maxSelections={10}
            formatOption={(v) => v.charAt(0).toUpperCase() + v.slice(1)}
          />
        </Section>

        <Section title="Livestock">
          <OptionChipPicker
            label="Livestock"
            options={AVAILABLE_LIVESTOCK}
            selected={draft.livestock}
            onChange={(livestock) => patch({ livestock })}
            maxSelections={8}
            formatOption={(v) => v.charAt(0).toUpperCase() + v.slice(1)}
          />
        </Section>

        <Section title="Farm type & scale">
          <OptionChipPicker
            label="Farm type"
            options={FARM_TYPES}
            selected={draft.farm_type}
            onChange={(farm_type) => patch({ farm_type })}
            maxSelections={3}
          />
          <SelectField
            label="Farm scale"
            value={draft.farm_scale}
            options={FARM_SCALES}
            onChange={(farm_scale) => patch({ farm_scale })}
          />
        </Section>

        <Section title="Activities">
          <OptionChipPicker
            label="Activities"
            options={FARM_ACTIVITIES}
            selected={draft.activities}
            onChange={(activities) => patch({ activities })}
            maxSelections={5}
          />
        </Section>

        <Section title="Specializations">
          <OptionChipPicker
            label="Specializations"
            options={SPECIALIZATIONS}
            selected={draft.specializations}
            onChange={(specializations) => patch({ specializations })}
            maxSelections={6}
          />
        </Section>

        <Section title="Farm goals">
          <OptionChipPicker label="Goals" options={FARM_GOALS} selected={draft.farm_goals} onChange={(farm_goals) => patch({ farm_goals })} maxSelections={5} />
        </Section>

        <Section title="Value-added products">
          <OptionChipPicker
            label="Products"
            options={VALUE_ADDED_PRODUCTS}
            selected={draft.value_added_products}
            onChange={(value_added_products) => patch({ value_added_products })}
            maxSelections={6}
          />
        </Section>

        <Section title="Farm accessibility & agritourism">
          <label className="farm-edit-checkbox">
            <input
              type="checkbox"
              checked={draft.is_open_farm}
              onChange={(e) => patch({ is_open_farm: e.target.checked })}
            />
            <span>Open farm (visitors welcome)</span>
          </label>
          {draft.is_open_farm ? (
            <>
              <div className="field">
                <label>Visitor guidelines</label>
                <textarea
                  rows={3}
                  value={draft.visitor_guidelines}
                  onChange={(e) => patch({ visitor_guidelines: e.target.value })}
                />
              </div>
              <div className="field">
                <label>Accessibility info</label>
                <textarea
                  rows={2}
                  value={draft.farm_accessibility}
                  onChange={(e) => patch({ farm_accessibility: e.target.value })}
                />
              </div>
              <OptionChipPicker
                label="Agritourism offerings"
                options={AGRITOURISM_OFFERINGS}
                selected={draft.agritourism_offerings}
                onChange={(agritourism_offerings) => patch({ agritourism_offerings })}
                maxSelections={5}
              />
            </>
          ) : null}
        </Section>

        <Section title="Directions & signage">
          <div className="field">
            <label>Highway exit</label>
            <input value={draft.highway_exit} onChange={(e) => patch({ highway_exit: e.target.value })} />
          </div>
          <div className="field">
            <label>Highway directions</label>
            <textarea rows={3} value={draft.highway_directions} onChange={(e) => patch({ highway_directions: e.target.value })} />
          </div>
          <div className="field">
            <label>Signage information</label>
            <textarea rows={2} value={draft.signage_info} onChange={(e) => patch({ signage_info: e.target.value })} />
          </div>
        </Section>

        <div className="farm-edit-footer-actions">
          <button type="submit" className="btn btn-primary" disabled={saving}>
            {saving ? "Saving…" : "Save farm details"}
          </button>
          <button type="button" className="btn btn-danger" disabled={saving} onClick={() => void removeAll()}>
            Delete farm details
          </button>
        </div>
      </form>
    </motion.div>
  );
}
