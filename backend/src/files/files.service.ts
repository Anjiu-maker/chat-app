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

  async upload(
    uploaderId: string,
    file?: Express.Multer.File,
    options: {
      folder?: string;
      maxSizeMb?: number;
      allowedMimePattern?: RegExp;
      allowedExtensions?: string[];
    } = {},
  ) {
    if (!file) {
      throw new BadRequestException('请选择要上传的文件');
    }

    const extension = extname(file.originalname || '').toLowerCase();
    const hasAllowedMime =
      !options.allowedMimePattern ||
      options.allowedMimePattern.test(file.mimetype);
    const hasAllowedExtension =
      options.allowedExtensions?.includes(extension) ?? false;
    if (!hasAllowedMime && !hasAllowedExtension) {
      throw new BadRequestException('请上传正确的文件类型');
    }

    const contentType = this.resolveContentType(file.mimetype, extension);

    const maxSizeMb =
      options.maxSizeMb ?? this.config.get<number>('FILE_MAX_SIZE_MB', 20);
    if (file.size > maxSizeMb * 1024 * 1024) {
      throw new BadRequestException(`文件不能超过 ${maxSizeMb}MB`);
    }

    const key = this.createObjectKey(file.originalname, options.folder);
    const stored = await this.storageService.uploadObject(
      key,
      file.buffer,
      contentType,
    );

    return this.files.save(
      this.files.create({
        uploaderId,
        originalName: file.originalname,
        mimeType: contentType,
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

  private createObjectKey(filename: string, folder = 'uploads') {
    const ext = extname(filename || '').slice(0, 20);
    const day = new Date().toISOString().slice(0, 10);
    return `${folder}/${day}/${randomUUID()}${ext}`;
  }

  private resolveContentType(mimetype: string, extension: string) {
    if (mimetype && mimetype !== 'application/octet-stream') {
      return mimetype;
    }
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return mimetype || 'application/octet-stream';
    }
  }
}
