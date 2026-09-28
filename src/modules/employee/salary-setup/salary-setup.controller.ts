import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { SalarySetupCurrentQueryDto, SalarySetupListQueryDto, SalarySetupSaveDto } from './dto/salary-setup.dto';
import { SalarySetup } from './salary-setup.repository';
import { SalarySetupService } from './salary-setup.service';

@ApiTags('Employee - Salary setups')
@Controller('salary-setups')
@Roles('ADMIN')
export class SalarySetupController {
  constructor(private readonly service: SalarySetupService) {}

  @Get()
  @ApiOperation({ summary: 'List salary setups (sp_salary_setup_list). Filters: employeeId, salaryType' })
  list(@Query() q: SalarySetupListQueryDto): Promise<ApiResult<SalarySetup[]>> {
    return this.service.list(q);
  }

  @Get('current/:employeeId')
  @ApiOperation({ summary: 'Setup in force for a month (sp_salary_setup_current); data is null when none' })
  current(@Param('employeeId', ParseIntPipe) employeeId: number, @Query() q: SalarySetupCurrentQueryDto): Promise<(SalarySetup & { month: string }) | null> {
    return this.service.current(employeeId, q.month);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get salary setup (sp_salary_setup_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<SalarySetup> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create salary setup (sp_salary_setup_save)' })
  create(@Body() dto: SalarySetupSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<SalarySetup>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update salary setup (sp_salary_setup_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: SalarySetupSaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<SalarySetup>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete salary setup (sp_salary_setup_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
