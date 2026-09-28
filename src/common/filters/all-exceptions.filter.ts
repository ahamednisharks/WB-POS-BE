import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Request, Response } from 'express';
import { SpError } from '../../database/db.service';

/** Business SQLSTATEs raised by the stored procedures (SIGNAL) -> HTTP status. */
export const SQLSTATE_HTTP: Record<string, number> = {
  '45000': HttpStatus.BAD_REQUEST,
  '45401': HttpStatus.UNAUTHORIZED,
  '45403': HttpStatus.FORBIDDEN,
  '45404': HttpStatus.NOT_FOUND,
  '45409': HttpStatus.CONFLICT,
  '45423': HttpStatus.LOCKED,
};

export interface ErrorBody {
  success: false;
  statusCode: number;
  message: string;
  field?: string;
}

function isSpError(e: unknown): e is SpError {
  return e instanceof Error && ('sqlState' in e || 'errno' in e);
}

/**
 * SP messages may name the offending form field as `field::message`
 * (e.g. 'name::Category name already exists') so the frontend can show it under the input.
 */
export function splitFieldMessage(text: string): { field?: string; message: string } {
  const m = /^([A-Za-z][A-Za-z0-9.]*)::(.+)$/s.exec(text);
  return m ? { field: m[1], message: m[2] } : { message: text };
}

export function mapException(exception: unknown): ErrorBody {
  if (exception instanceof HttpException) {
    const status = exception.getStatus();
    const res = exception.getResponse();
    let message = exception.message;
    let field: string | undefined;
    if (typeof res === 'string') message = res;
    else if (res && typeof res === 'object') {
      const body = res as { message?: unknown; field?: unknown };
      if (Array.isArray(body.message)) message = body.message.join(', ');
      else if (typeof body.message === 'string') message = body.message;
      if (typeof body.field === 'string') field = body.field;
    }
    return { success: false, statusCode: status, message, ...(field ? { field } : {}) };
  }

  if (isSpError(exception)) {
    const state = exception.sqlState ?? '';
    if (state.startsWith('45')) {
      const { field, message } = splitFieldMessage(exception.sqlMessage ?? exception.message);
      const statusCode = SQLSTATE_HTTP[state] ?? HttpStatus.BAD_REQUEST;
      return { success: false, statusCode, message, ...(field ? { field } : {}) };
    }
    if (exception.errno === 1062) return { success: false, statusCode: HttpStatus.CONFLICT, message: 'Duplicate value' };
    if (exception.errno === 1451) return { success: false, statusCode: HttpStatus.CONFLICT, message: 'Record is in use' };
  }

  return { success: false, statusCode: HttpStatus.INTERNAL_SERVER_ERROR, message: 'Something went wrong' };
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request & { id?: string }>();
    const body = mapException(exception);

    if (body.statusCode >= 500) {
      const err = exception as SpError;
      this.logger.error(
        {
          reqId: req.id,
          method: req.method,
          url: req.originalUrl,
          procName: err?.procName,
          sqlState: err?.sqlState,
          errno: err?.errno,
          err: exception instanceof Error ? { message: exception.message, stack: exception.stack } : exception,
        },
        'Unhandled error',
      );
    }

    if (res.headersSent) return;
    res.status(body.statusCode).json(body);
  }
}
