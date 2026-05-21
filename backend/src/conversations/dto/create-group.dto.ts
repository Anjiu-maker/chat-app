import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CreateGroupDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @IsUUID('4', { each: true })
  memberIds!: string[];

  @IsString()
  @IsOptional()
  @MaxLength(500)
  announcement?: string;
}
