import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateContactDto {
  @IsString()
  @IsOptional()
  @MaxLength(80)
  remark?: string;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  tag?: string;
}
