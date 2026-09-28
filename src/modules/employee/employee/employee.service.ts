import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppConfig } from '../../../config/configuration';
import { ApiResult, DeleteResult, ok, paged } from '../../../common/utils/api-result';
import { decrypt, encrypt, keyedHash, maskTail } from '../../../common/utils/crypto.util';
import { Row } from '../../../common/utils/to-camel';
import { FileStorageService, UploadedFileInfo } from '../../uploads/file-storage.service';
import { EmployeeListQueryDto, EmployeeSaveDto, EmployeeStatus, isMasked } from './dto/employee.dto';
import { EmployeeOption, EmployeeRepository, EmployeeRow } from './employee.repository';

/** Employee as the API exposes it (frontend `Employee` model). */
export interface Employee {
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
  aadhaar: string;
  idProof: UploadedFileInfo | null;
  emergencyName: string;
  emergencyMobile: string;
  bankAccount: string;
  ifsc: string;
  status: EmployeeStatus;
  resignDate: string | null;
  loginId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface EmployeeProfile {
  employee: Employee;
  salarySetups: Row[];
  payments: Row[];
  login: Row | null;
  advances: Row | null;
}

@Injectable()
export class EmployeeService {
  private readonly key: string;

  constructor(
    private readonly repo: EmployeeRepository,
    private readonly files: FileStorageService,
    config: ConfigService<AppConfig, true>,
  ) {
    this.key = config.get('aesKey', { infer: true });
  }

  private reveal(enc: string | null): string {
    if (!enc) return '';
    try {
      return decrypt(enc, this.key);
    } catch {
      return '';
    }
  }

  /** full = decrypted sensitive fields (edit form, ADMIN only); otherwise masked. */
  private view(row: EmployeeRow, full: boolean): Employee {
    const { aadhaarEnc, aadhaarLast4, bankAccountEnc, idProofUrl, idProofName, ...rest } = row;
    const bank = this.reveal(bankAccountEnc);
    return {
      ...rest,
      photo: this.files.publicLink(row.photo),
      aadhaar: full ? this.reveal(aadhaarEnc) : aadhaarLast4 ? `XXXXXXXX${aadhaarLast4}` : '',
      bankAccount: full ? bank : maskTail(bank),
      idProof: this.files.fileInfo(idProofUrl, idProofName),
    };
  }

  async list(q: EmployeeListQueryDto): Promise<ApiResult<Employee[]>> {
    const r = await this.repo.list(q);
    return paged(r.data.map((e) => this.view(e, false)), r.total);
  }

  async get(id: number): Promise<Employee> {
    return this.view(await this.repo.get(id), true);
  }

  async save(id: number, dto: EmployeeSaveDto, userId: number): Promise<ApiResult<Employee>> {
    const existing = id > 0 && (isMasked(dto.aadhaar) || isMasked(dto.bankAccount)) ? await this.repo.get(id) : null;

    let aadhaarEnc: string | null = null;
    let aadhaarLast4: string | null = null;
    let aadhaarHash: string | null = null;
    if (isMasked(dto.aadhaar) && existing) {
      aadhaarEnc = existing.aadhaarEnc;
      aadhaarLast4 = existing.aadhaarLast4;
      aadhaarHash = aadhaarEnc ? keyedHash(this.reveal(aadhaarEnc), this.key) : null;
    } else if (dto.aadhaar) {
      aadhaarEnc = encrypt(dto.aadhaar, this.key);
      aadhaarLast4 = dto.aadhaar.slice(-4);
      aadhaarHash = keyedHash(dto.aadhaar, this.key);
    }

    let bankAccountEnc: string | null = null;
    if (isMasked(dto.bankAccount) && existing) bankAccountEnc = existing.bankAccountEnc;
    else if (dto.bankAccount) bankAccountEnc = encrypt(dto.bankAccount, this.key);

    const photoUrl = await this.files.resolveImage(dto.photo, 'photo');
    const idProof = await this.files.resolveFile(dto.idProof, 'document', 'idProof');

    const res = await this.repo.save(
      id,
      {
        photoUrl,
        fullName: dto.fullName.trim(),
        employeeTypeId: dto.employeeTypeId,
        mobile: dto.mobile,
        altMobile: dto.altMobile ?? null,
        email: dto.email ?? null,
        gender: dto.gender,
        dob: dto.dob ?? null,
        joiningDate: dto.joiningDate,
        address: dto.address,
        aadhaarEnc,
        aadhaarLast4,
        aadhaarHash,
        idProofUrl: idProof?.url ?? null,
        idProofName: idProof?.name ?? null,
        emergencyName: dto.emergencyName ?? null,
        emergencyMobile: dto.emergencyMobile ?? null,
        bankAccountEnc,
        ifsc: dto.ifsc ?? null,
        status: dto.status ?? 'ACTIVE',
        resignDate: dto.resignDate ?? null,
      },
      userId,
    );
    return ok(await this.get(Number(res.id)), res.message);
  }

  async remove(id: number, userId: number): Promise<ApiResult<DeleteResult>> {
    const res = await this.repo.delete(id, userId);
    return ok({ deleted: res.deleted, message: res.message }, res.message);
  }

  dropdown(): Promise<EmployeeOption[]> {
    return this.repo.dropdown();
  }

  async profile(id: number): Promise<EmployeeProfile> {
    const p = await this.repo.profile(id);
    return { ...p, employee: this.view(p.employee, false) };
  }
}
