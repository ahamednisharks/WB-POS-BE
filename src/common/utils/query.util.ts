import { ListQueryDto } from '../dto/list-query.dto';

export interface SortSpec {
  sortBy: string | null;
  sortDir: 'asc' | 'desc';
}

/**
 * Accepts both styles: `sort=-name` (frontend) or `sortBy=name&sortDir=desc`.
 * The SPs whitelist sortBy with CASE, unknown keys fall back to their default order.
 */
export function sortOf(q: ListQueryDto, fallbackDir: 'asc' | 'desc' = 'desc'): SortSpec {
  if (q.sort) {
    const desc = q.sort.startsWith('-');
    return { sortBy: q.sort.replace(/^-/, ''), sortDir: desc ? 'desc' : 'asc' };
  }
  return { sortBy: q.sortBy ?? null, sortDir: q.sortDir ?? fallbackDir };
}

/** 'ACTIVE' -> 1, 'INACTIVE' -> 0, anything else (ALL / empty) -> NULL = no filter. */
export function activeFlag(status: string | undefined): number | null {
  if (status === 'ACTIVE') return 1;
  if (status === 'INACTIVE') return 0;
  return null;
}

/** Filter values: '' / 'ALL' mean "no filter". */
export function filterValue<T>(value: T | undefined | null): T | null {
  if (value === undefined || value === null) return null;
  if (typeof value === 'string' && (value === '' || value.toUpperCase() === 'ALL')) return null;
  return value;
}

export function boolFlag(value: boolean | undefined | null): number | null {
  if (value === undefined || value === null) return null;
  return value ? 1 : 0;
}

export function pageArgs(q: ListQueryDto): [number, number] {
  return [q.page ?? 1, q.limit ?? 10];
}

export function searchOf(q: ListQueryDto): string | null {
  const s = q.search?.trim();
  return s ? s : null;
}
