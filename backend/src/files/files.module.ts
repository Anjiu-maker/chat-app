import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StorageModule } from '../storage/storage.module';
import { FileObject } from './entities/file-object.entity';
import { FilesController } from './files.controller';
import { FilesService } from './files.service';

@Module({
  imports: [TypeOrmModule.forFeature([FileObject]), StorageModule],
  controllers: [FilesController],
  providers: [FilesService],
  exports: [FilesService, TypeOrmModule],
})
export class FilesModule {}
