export type Row = Record<string, unknown>;

/** Columns that MySQL returns as 0/1 but the API exposes as booleans. */
const BOOLEAN_KEYS = new Set([
  'allowDecimal',
  'priceIncludesGst',
  'canLogin',
  'isInterState',
  'deleted',
  'isDuplicate',
  'allowNegativeStock',
  'isLocked',
  'isActive',
]);

/** 'YYYY-MM-DD HH:mm:ss[.ffffff]' as produced by dateStrings / JSON_OBJECT (IST wall clock). */
const DATETIME_RE = /^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})(?:\.\d+)?$/;

export function camelKey(key: string): string {
  return key.replace(/_([a-z0-9])/g, (_m, c: string) => c.toUpperCase());
}

function isPlainObject(value: unknown): value is Row {
  return typeof value === 'object' && value !== null && !Array.isArray(value) && !(value instanceof Date) && !Buffer.isBuffer(value);
}

function convertValue(key: string, value: unknown): unknown {
  if (value === undefined || value === null) return null;
  if (BOOLEAN_KEYS.has(key)) return value === 1 || value === true || value === '1';
  // Ids travel as strings (the frontend models use string ids).
  if ((key === 'id' || key.endsWith('Id')) && typeof value === 'number') return String(value);
  if (typeof value === 'string') {
    const m = DATETIME_RE.exec(value);
    return m ? `${m[1]}T${m[2]}+05:30` : value;
  }
  if (Array.isArray(value)) return value.map((v) => (isPlainObject(v) ? toCamel(v) : v));
  if (isPlainObject(value)) return toCamel(value);
  return value;
}

/**
 * Converts one SP row to the API shape: snake_case -> camelCase keys, numeric ids -> strings,
 * 0/1 flags -> booleans, DATETIME strings -> ISO 8601 with the +05:30 offset. Nested JSON is converted too.
 */
export function toCamel<T = Row>(row: Row): T {
  const out: Row = {};
  for (const [key, value] of Object.entries(row)) {
    const k = camelKey(key);
    out[k] = convertValue(k, value);
  }
  return out as T;
}

export function mapRows<T = Row>(rows: Row[] | undefined): T[] {
  return (rows ?? []).map((r) => toCamel<T>(r));
}

export function firstRow<T = Row>(rows: Row[] | undefined): T | null {
  const r = rows?.[0];
  return r ? toCamel<T>(r) : null;
}

/** Reads the `SELECT COUNT(*) AS total` result set of a list SP. */
export function totalOf(rows: Row[] | undefined): number {
  return Number(rows?.[0]?.['total'] ?? 0);
}
