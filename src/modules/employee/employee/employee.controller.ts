import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { EmployeeListQueryDto, EmployeeSaveDto } from './dto/employee.dto';
import { EmployeeOption } from './employee.repository';
import { Employee, EmployeeProfile, EmployeeService } from './employee.service';

@ApiTags('Employee - Employees')
@Controller('employees')
@Roles('ADMIN')
export class EmployeeController {
  constructor(private readonly service: EmployeeService) {}

  @Get()
  @ApiOperation({ summary: 'List employees; Aadhaar / bank are masked (sp_employee_list). Filters: employeeTypeId, status' })
  list(@Query() q: EmployeeListQueryDto): Promise<ApiResult<Employee[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @ApiOperation({ summary: 'Active employees (sp_employee_dropdown)' })
  dropdown(): Promise<EmployeeOption[]> {
    return this.service.dropdown();
  }

  @Get(':id/profile')
  @ApiOperation({ summary: 'Profile: details, salary setups, last 12 payments, login (sp_employee_profile)' })
  profile(@Param('id', ParseIntPipe) id: number): Promise<EmployeeProfile> {
    return this.service.profile(id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get employee for editing; sensitive fields decrypted (sp_employee_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Employee> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create employee; EMP001 code generated (sp_employee_save)' })
  create(@Body() dto: EmployeeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Employee>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update employee; RESIGNED blocks the login (sp_employee_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: EmployeeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Employee>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete employee, or mark resigned when they have records (sp_employee_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
