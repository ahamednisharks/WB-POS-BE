import { CallHandler, ExecutionContext, Injectable, NestInterceptor, StreamableFile } from '@nestjs/common';
import { map, Observable } from 'rxjs';
import { ApiResult } from '../utils/api-result';

export interface SuccessEnvelope {
  success: true;
  message?: string;
  data: unknown;
  total?: number;
  [extra: string]: unknown;
}

/** Wraps every successful response in the standard envelope (files are streamed untouched). */
@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      map((result: unknown): unknown => {
        if (result instanceof StreamableFile) return result;
        if (result instanceof ApiResult) {
          if (result.total !== undefined) {
            return { success: true, data: result.data, total: result.total, ...(result.extra ?? {}) } satisfies SuccessEnvelope;
          }
          return { success: true, ...(result.message ? { message: result.message } : {}), data: result.data } satisfies SuccessEnvelope;
        }
        return { success: true, data: result ?? null } satisfies SuccessEnvelope;
      }),
    );
  }
}
