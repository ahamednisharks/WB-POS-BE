import { Injectable } from '@nestjs/common';
import { DeleteResult, PagedData, WriteResult } from '../../../common/utils/api-result';
import { filterValue, pageArgs, searchOf, sortOf } from '../../../common/utils/query.util';
import { firstRow, mapRows, Row, totalOf } from '../../../common/utils/to-camel';
import { DbService } from '../../../database/db.service';
import { EmployeeListQueryDto, EmployeeStatus } from './dto/employee.dto';

/** Employee row exactly as the SPs return it (encrypted columns included). */
export interface EmployeeRow {
  id: string;
  empCode: string;
  photo: string | null;
  fullName: string;
  employeeTypeId: string;
  employeeTypeName: string;
  canLogin: boolean;
  mobile: string;
  altMobile: string;
  email: string;
  gender: 'MALE' | 'FEMALE' | 'OTHER';
  dob: string | null;
  joiningDate: string;
  address: string;
  aadhaarLast4: string | null;
  aadhaarEnc: string | null;
  idProofUrl: string | null;
  idProofName: string | null;
  emergencyName: string;
  emergencyMobile: string;
  bankAccountEnc: string | null;
  ifsc: string;
  status: EmployeeStatus;
  resignDate: string | null;
  loginId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface EmployeeOption {
  id: string;
  empCode: string;
  fullName: string;
  employeeTypeName: string;
  canLogin: boolean;
  mobile: string;
}

/** Values the service prepares (encryption, uploaded files) before calling sp_employee_save. */
export interface EmployeeSaveParams {
  photoUrl: string | null;
  fullName: string;
  employeeTypeId: number;
  mobile: string;
  altMobile: string | null;
  email: string | null;
  gender: string;
  dob: string | null;
  joiningDate: string;
  address: string;
  aadhaarEnc: string | null;
  aadhaarLast4: string | null;
  aadhaarHash: string | null;
  idProofUrl: string | null;
  idProofName: string | null;
  emergencyName: string | null;
  emergencyMobile: string | null;
  bankAccountEnc: string | null;
  ifsc: string | null;
  status: EmployeeStatus;
  resignDate: string | null;
}

export interface EmployeeProfileSets {
  employee: EmployeeRow;
  salarySetups: Row[];
  payments: Row[];
  login: Row | null;
  advances: Row | null;
}

@Injectable()
export class EmployeeRepository {
  constructor(private readonly db: DbService) {}

  async list(q: EmployeeListQueryDto): Promise<PagedData<EmployeeRow>> {
    const { sortBy, sortDir } = sortOf(q);
    const [rows, count] = await this.db.call<Row>('sp_employee_list', [
      searchOf(q),
      q.employeeTypeId ?? null,
      filterValue(q.empStatus ?? q.status),
      sortBy,
      sortDir,
      ...pageArgs(q),
    ]);
    return { data: mapRows<EmployeeRow>(rows), total: totalOf(count) };
  }

  async get(id: number): Promise<EmployeeRow> {
    const [rows] = await this.db.call<Row>('sp_employee_get', [id]);
    return firstRow<EmployeeRow>(rows)!;
  }

  async save(id: number, p: EmployeeSaveParams, userId: number): Promise<WriteResult> {
    const [rows] = await this.db.call<Row>('sp_employee_save', [
      id,
      p.photoUrl,
      p.fullName,
      p.employeeTypeId,
      p.mobile,
      p.altMobile,
      p.email,
      p.gender,
      p.dob,
      p.joiningDate,
      p.address,
      p.aadhaarEnc,
      p.aadhaarLast4,
      p.aadhaarHash,
      p.idProofUrl,
      p.idProofName,
      p.emergencyName,
      p.emergencyMobile,
      p.bankAccountEnc,
      p.ifsc,
      p.status,
      p.resignDate,
      userId,
    ]);
    return firstRow<WriteResult>(rows)!;
  }

  async delete(id: number, userId: number): Promise<DeleteResult> {
    const [rows] = await this.db.call<Row>('sp_employee_delete', [id, userId]);
    return firstRow<DeleteResult>(rows)!;
  }

  async dropdown(): Promise<EmployeeOption[]> {
    const [rows] = await this.db.call<Row>('sp_employee_dropdown');
    return mapRows<EmployeeOption>(rows);
  }

  async profile(id: number): Promise<EmployeeProfileSets> {
    const [employee, setups, payments, login, advances] = await this.db.call<Row>('sp_employee_profile', [id]);
    return {
      employee: firstRow<EmployeeRow>(employee)!,
      salarySetups: mapRows(setups),
      payments: mapRows(payments),
      login: firstRow(login),
      advances: firstRow(advances),
    };
  }
}
