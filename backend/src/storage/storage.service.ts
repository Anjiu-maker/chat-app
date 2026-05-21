import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client, S3ClientConfig } from '@aws-sdk/client-s3';

@Injectable()
export class StorageService {
  private readonly bucket: string;
  private readonly client: S3Client;
  private readonly publicBaseUrl?: string;

  constructor(config: ConfigService) {
    this.bucket = config.get<string>('STORAGE_BUCKET', 'chat-files');
    this.publicBaseUrl = config.get<string>('STORAGE_PUBLIC_BASE_URL');

    const clientConfig: S3ClientConfig = {
      region: config.get<string>('STORAGE_REGION', 'us-east-1'),
      endpoint: config.get<string>('STORAGE_ENDPOINT'),
      forcePathStyle:
        config.get<string>('STORAGE_FORCE_PATH_STYLE', 'true') === 'true',
      credentials: {
        accessKeyId: config.get<string>('STORAGE_ACCESS_KEY', 'minioadmin'),
        secretAccessKey: config.get<string>('STORAGE_SECRET_KEY', 'minioadmin'),
      },
    };

    this.client = new S3Client(clientConfig);
  }

  async uploadObject(key: string, body: Buffer, contentType: string) {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      }),
    );

    return {
      bucket: this.bucket,
      key,
    };
  }

  publicUrl(key: string) {
    if (!this.publicBaseUrl) {
      return `s3://${this.bucket}/${key}`;
    }

    return `${this.publicBaseUrl.replace(/\/$/, '')}/${key}`;
  }
}
