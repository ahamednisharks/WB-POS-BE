export type Role = 'ADMIN' | 'CASHIER';

/** What the JWT strategy puts on req.user. */
export interface AuthUser {
  id: number;
  username: string;
  role: Role;
  employeeId: number | null;
  name: string;
}

export interface JwtPayload {
  sub: number;
  username: string;
  role: Role;
  employeeId: number | null;
}
