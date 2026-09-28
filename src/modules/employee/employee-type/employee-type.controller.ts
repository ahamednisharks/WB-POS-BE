import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { EmployeeTypeListQueryDto, EmployeeTypeSaveDto } from './dto/employee-type.dto';
import { EmployeeType, EmployeeTypeOption } from './employee-type.repository';
import { EmployeeTypeService } from './employee-type.service';

@ApiTags('Employee - Types')
@Controller('employee-types')
@Roles('ADMIN')
export class EmployeeTypeController {
  constructor(private readonly service: EmployeeTypeService) {}

  @Get()
  @ApiOperation({ summary: 'List employee types (sp_employee_type_list). Filter: canLogin' })
  list(@Query() q: EmployeeTypeListQueryDto): Promise<ApiResult<EmployeeType[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @ApiOperation({ summary: 'Active employee types (sp_employee_type_dropdown)' })
  dropdown(): Promise<EmployeeTypeOption[]> {
    return this.service.dropdown();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get employee type (sp_employee_type_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<EmployeeType> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create employee type (sp_employee_type_save)' })
  create(@Body() dto: EmployeeTypeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<EmployeeType>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update employee type (sp_employee_type_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: EmployeeTypeSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<EmployeeType>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete employee type, or mark inactive when in use (sp_employee_type_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
