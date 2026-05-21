import { IsPhoneNumber, IsString, Length } from 'class-validator';

export class LoginDto {
  @IsPhoneNumber('CN')
  phone!: string;

  @IsString()
  @Length(8, 64)
  password!: string;
}
