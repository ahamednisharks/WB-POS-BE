/** Round to paise without binary float drift. Totals are computed by the SPs; this is for display/export only. */
export function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function round3(value: number): number {
  return Math.round((value + Number.EPSILON) * 1000) / 1000;
}

const inr = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export function formatInr(value: number | null | undefined): string {
  return inr.format(value ?? 0);
}
