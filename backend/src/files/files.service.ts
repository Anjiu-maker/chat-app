import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { Repository } from 'typeorm';
import { StorageService } from '../storage/storage.service';
import { FileObject } from './entities/file-object.entity';

@Injectable()
export class FilesService {
  constructor(
    private readonly config: ConfigService,
    private readonly storageService: StorageService,
    @InjectRepository(FileObject)
    private readonly files: Repository<FileObject>,
  ) {}

  async upload(uploaderId: string, file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('请选择要上传的文件');
    }

    const maxSizeMb = this.config.get<number>('FILE_MAX_SIZE_MB', 20);
    if (file.size > maxSizeMb * 1024 * 1024) {
      throw new BadRequestException(`文件不能超过 ${maxSizeMb}MB`);
    }

    const key = this.createObjectKey(file.originalname);
    const stored = await this.storageService.uploadObject(
      key,
      file.buffer,
      file.mimetype,
    );

    // 先保存对象存储 key，下载鉴权和签名 URL 可以在后续文件模块里继续扩展。
    return this.files.save(
      this.files.create({
        uploaderId,
        originalName: file.originalname,
        mimeType: file.mimetype,
        size: file.size,
        bucket: stored.bucket,
        objectKey: stored.key,
        url: this.storageService.publicUrl(stored.key),
      }),
    );
  }

  findById(id: string) {
    return this.files.findOne({ where: { id } });
  }

  private createObjectKey(filename: string) {
    const ext = extname(filename || '').slice(0, 20);
    const day = new Date().toISOString().slice(0, 10);
    return `uploads/${day}/${randomUUID()}${ext}`;
  }
}
