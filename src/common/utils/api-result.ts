/**
 * What controllers return. The ResponseInterceptor turns it into the standard envelope:
 *   { success: true, message?, data }                 single object
 *   { success: true, data: [...], total, ...extra }   list
 */
export class ApiResult<T> {
  constructor(
    readonly data: T,
    readonly message?: string,
    readonly total?: number,
    readonly extra?: Record<string, unknown>,
  ) {}
}

export function ok<T>(data: T, message?: string): ApiResult<T> {
  return new ApiResult(data, message);
}

export function paged<T>(data: T[], total: number, extra?: Record<string, unknown>): ApiResult<T[]> {
  return new ApiResult(data, undefined, total, extra);
}

/** Result row every write SP ends with. */
export interface WriteResult {
  id: string;
  message: string;
}

/** DELETE endpoints: deleted = false when the record was only marked inactive (in use). */
export interface DeleteResult {
  deleted: boolean;
  message: string;
}

export interface PagedData<T> {
  data: T[];
  total: number;
}
