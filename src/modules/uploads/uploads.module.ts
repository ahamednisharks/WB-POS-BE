import { Global, Module } from '@nestjs/common';
import { FileStorageService } from './file-storage.service';
import { UploadsController } from './uploads.controller';

@Global()
@Module({
  controllers: [UploadsController],
  providers: [FileStorageService],
  exports: [FileStorageService],
})
export class UploadsModule {}
