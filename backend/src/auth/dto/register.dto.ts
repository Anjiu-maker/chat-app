import {
  IsNotEmpty,
  IsPhoneNumber,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

export class RegisterDto {
  @IsPhoneNumber('CN')
  phone!: string;

  @IsString()
  @Length(4, 8)
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  nickname!: string;

  @IsString()
  @Length(8, 64)
  password!: string;
}
