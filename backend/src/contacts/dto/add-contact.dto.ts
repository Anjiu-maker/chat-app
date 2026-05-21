import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class AddContactDto {
  @IsUUID()
  contactUserId!: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  remark?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  tag?: string;
}
