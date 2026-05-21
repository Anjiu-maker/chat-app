import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class SendMessageDto {
  @IsUUID()
  conversationId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  content!: string;

  @IsString()
  @IsOptional()
  @IsIn(['text', 'image', 'file', 'system'])
  type?: 'text' | 'image' | 'file' | 'system';

  @IsUUID()
  @IsOptional()
  fileId?: string;

  @IsString()
  @IsOptional()
  clientId?: string;
}
