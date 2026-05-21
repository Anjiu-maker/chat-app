import { IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

export class UpdateMeDto {
  @IsString()
  @IsOptional()
  @MaxLength(80)
  nickname?: string;

  @IsUrl({ require_tld: false })
  @IsOptional()
  @MaxLength(255)
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  bio?: string;
}
