import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { CodeLoginDto } from './dto/code-login.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { SendCodeDto } from './dto/send-code.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('send-code')
  sendCode(@Body() body: SendCodeDto) {
    return this.authService.sendCode(body.phone, body.scene);
  }

  @Post('register')
  register(@Body() body: RegisterDto) {
    return this.authService.register(body);
  }

  @Post('login')
  login(@Body() body: LoginDto) {
    return this.authService.login(body.phone, body.password);
  }

  @Post('login/code')
  loginByCode(@Body() body: CodeLoginDto) {
    return this.authService.loginByCode(body.phone, body.code);
  }
}
