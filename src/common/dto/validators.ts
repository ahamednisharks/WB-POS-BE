import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsIn, IsNumber, IsOptional, Matches, Min, ValidateIf } from 'class-validator';

export const PATTERNS = {
  mobile: /^[6-9]\d{9}$/,
  gstin: /^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/,
  hsn: /^\d{4,8}$/,
  aadhaar: /^\d{12}$/,
  ifsc: /^[A-Z]{4}0[A-Z0-9]{6}$/,
  bankAccount: /^\d{9,18}$/,
  username: /^\S{3,30}$/,
  date: /^\d{4}-\d{2}-\d{2}$/,
  month: /^\d{4}-(0[1-9]|1[0-2])$/,
  email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
};

export const GST_RATES = [0, 5, 12, 18, 28];

/** Reads the raw value so '"false"' does not become true through implicit conversion. */
export const ToBoolean = (): PropertyDecorator =>
  Transform(({ obj, key }: { obj: Record<string, unknown>; key: string }) => {
    const v = obj[key];
    if (v === undefined || v === null || v === '') return undefined;
    return v === true || v === 'true' || v === 1 || v === '1';
  });

/** Trims strings; empty string becomes null so optional fields can be cleared. */
export const TrimToNull = (): PropertyDecorator =>
  Transform(({ value }: { value: unknown }) => {
    if (typeof value !== 'string') return value;
    const t = value.trim();
    return t === '' ? null : t;
  });

export const UpperTrim = (): PropertyDecorator =>
  Transform(({ value }: { value: unknown }) => {
    if (typeof value !== 'string') return value;
    const t = value.trim().toUpperCase();
    return t === '' ? null : t;
  });

/** Optional that also skips validation for null (cleared field). */
export const OptionalNullable = (): PropertyDecorator => ValidateIf((_o, v) => v !== null && v !== undefined);

export const IsMoney = (): PropertyDecorator =>
  applyDecorators(IsNumber({ maxDecimalPlaces: 2 }, { message: '$property must be an amount with at most 2 decimals' }), Min(0));

export const IsQty = (): PropertyDecorator =>
  applyDecorators(IsNumber({ maxDecimalPlaces: 3 }, { message: '$property must be a quantity with at most 3 decimals' }), Min(0.001));

export const IsGst = (): PropertyDecorator => IsIn(GST_RATES, { message: 'GST % must be one of 0, 5, 12, 18, 28' });

export const IsDateOnly = (): PropertyDecorator => Matches(PATTERNS.date, { message: '$property must be YYYY-MM-DD' });

export const IsMonth = (): PropertyDecorator => Matches(PATTERNS.month, { message: '$property must be YYYY-MM' });

export const IsMobile = (): PropertyDecorator =>
  Matches(PATTERNS.mobile, { message: '$property must be a valid 10-digit mobile number' });

export { IsOptional };
