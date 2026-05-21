import { IsPhoneNumber, IsString, Length } from 'class-validator';

export class CodeLoginDto {
  @IsPhoneNumber('CN')
  phone!: string;

  @IsString()
  @Length(4, 8)
  code!: string;
}
