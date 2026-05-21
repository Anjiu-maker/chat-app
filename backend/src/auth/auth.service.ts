import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { RedisService } from '../redis/redis.service';
import { User } from '../users/entities/user.entity';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly config: ConfigService,
    private readonly jwtService: JwtService,
    private readonly redisService: RedisService,
    private readonly usersService: UsersService,
  ) {}

  async sendCode(phone: string, scene: 'register' | 'login') {
    const code = this.createCode();
    const ttl = this.config.get<number>('OTP_TTL_SECONDS', 300);

    // 当前阶段先落 Redis，正式接短信服务时只需要替换发送通道，不改变验证逻辑。
    await this.redisService.setOtp(phone, scene, code, ttl);

    return {
      sent: true,
      ttl,
      devCode:
        this.config.get<string>('NODE_ENV', 'development') === 'production'
          ? undefined
          : code,
    };
  }

  async register(params: {
    phone: string;
    code: string;
    nickname: string;
    password: string;
  }) {
    await this.verifyCode(params.phone, 'register', params.code);
    const passwordHash = await bcrypt.hash(params.password, 12);
    const user = await this.usersService.create({
      phone: params.phone,
      nickname: params.nickname,
      passwordHash,
    });

    await this.redisService.deleteOtp(params.phone, 'register');
    return this.createAuthPayload(user);
  }

  async login(phone: string, password: string) {
    const user = await this.usersService.findByPhoneWithPassword(phone);
    if (!user) {
      throw new UnauthorizedException('手机号或密码错误');
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('手机号或密码错误');
    }

    return this.createAuthPayload(user);
  }

  async loginByCode(phone: string, code: string) {
    await this.verifyCode(phone, 'login', code);
    const user = await this.usersService.findByPhone(phone);
    if (!user) {
      throw new NotFoundException('手机号尚未注册');
    }

    await this.redisService.deleteOtp(phone, 'login');
    return this.createAuthPayload(user);
  }

  private async verifyCode(
    phone: string,
    scene: 'register' | 'login',
    code: string,
  ) {
    const expected = await this.redisService.getOtp(phone, scene);
    if (!expected || expected !== code) {
      throw new BadRequestException('验证码错误或已过期');
    }
  }

  private async createAuthPayload(user: User) {
    const publicUser = this.usersService.toPublicUser(user);
    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      phone: user.phone,
    });

    return { accessToken, user: publicUser };
  }

  private createCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }
}
