export const WORKSHOP_OPTIONS = [
  { id: "1", label: "Social Event 1" },
  { id: "2", label: "Workshop 1 - Connectivity and Reciprocity" },
  { id: "3", label: "Workshop 2 - Learning Through Stories" },
  { id: "4", label: "Workshop 3 - Systems Problems to Tackle Together" },
  { id: "5", label: "Tentative Social Event #2 - Farm Bus Tour" },
  { id: "6", label: "Workshop 4 - Toward Systems Solutions to Build Together" },
  { id: "7", label: "Workshop 5 & Social Event 2 - Connectivity with Value Chain" },
  { id: "8", label: "Workshop 6 - Strengthening Solutions" },
  { id: "9", label: "Workshop 7 - Planning and Enabling Collective Action" },
  { id: "10", label: "Workshops 8 & 9 - Act, Pivot and Make Progress" },
] as const;

export function workshopShortLabel(workshopId: string): string {
  const o = WORKSHOP_OPTIONS.find((w) => w.id === workshopId);
  return o ? `${o.id} · ${o.label}` : workshopId;
}
