import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../../common/decorators/current-user.decorator';
import { Roles } from '../../../common/decorators/roles.decorator';
import { ListQueryDto } from '../../../common/dto/list-query.dto';
import { AuthUser } from '../../../common/types/auth-user';
import { ApiResult, DeleteResult } from '../../../common/utils/api-result';
import { Category, CategoryOption } from './category.repository';
import { CategoryService } from './category.service';
import { CategorySaveDto } from './dto/category.dto';

@ApiTags('Master - Categories')
@Controller('categories')
@Roles('ADMIN')
export class CategoryController {
  constructor(private readonly service: CategoryService) {}

  @Get()
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'List categories (sp_category_list)' })
  list(@Query() q: ListQueryDto): Promise<ApiResult<Category[]>> {
    return this.service.list(q);
  }

  @Get('dropdown')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Active categories (sp_category_dropdown)' })
  dropdown(): Promise<CategoryOption[]> {
    return this.service.dropdown();
  }

  @Get(':id')
  @Roles('ADMIN', 'CASHIER')
  @ApiOperation({ summary: 'Get category (sp_category_get)' })
  get(@Param('id', ParseIntPipe) id: number): Promise<Category> {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create category (sp_category_save, id = 0)' })
  create(@Body() dto: CategorySaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Category>> {
    return this.service.save(0, dto, user.id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update category (sp_category_save)' })
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: CategorySaveDto, @CurrentUser() user: AuthUser): Promise<ApiResult<Category>> {
    return this.service.save(id, dto, user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete category, or mark inactive when in use (sp_category_delete)' })
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser): Promise<ApiResult<DeleteResult>> {
    return this.service.remove(id, user.id);
  }
}
