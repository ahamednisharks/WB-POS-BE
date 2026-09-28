import { BadRequestException, Body, Controller, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiProperty, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { memoryStorage } from 'multer';
import { Roles } from '../../common/decorators/roles.decorator';
import { ApiResult, ok } from '../../common/utils/api-result';
import { FileStorageService } from './file-storage.service';

class UploadDto {
  @ApiProperty({ enum: ['image', 'document'], default: 'image' })
  @IsOptional()
  @IsIn(['image', 'document'])
  type?: 'image' | 'document';
}

@ApiTags('Uploads')
@Controller('uploads')
@Roles('ADMIN')
export class UploadsController {
  constructor(private readonly files: FileStorageService) {}

  @Post()
  @ApiOperation({ summary: 'Upload an image (JPG/PNG <= MAX_IMAGE_MB) or document (PDF/JPG <= MAX_DOC_MB)' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' }, type: { type: 'string', enum: ['image', 'document'] } },
      required: ['file'],
    },
  })
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } }))
  async upload(@UploadedFile() file: Express.Multer.File | undefined, @Body() dto: UploadDto): Promise<ApiResult<{ url: string; path: string }>> {
    if (!file) throw new BadRequestException({ message: 'File is required', field: 'file' });
    const path = await this.files.saveBuffer(file.buffer, file.mimetype, dto.type ?? 'image');
    return ok({ url: this.files.publicLink(path)!, path }, 'File uploaded');
  }
}
