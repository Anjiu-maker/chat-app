import { IsPhoneNumber, IsString, Matches } from 'class-validator';

export class SendCodeDto {
  @IsPhoneNumber('CN')
  phone!: string;

  @IsString()
  @Matches(/^(register|login)$/)
  scene!: 'register' | 'login';
}
