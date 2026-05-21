import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtUser } from '../../common/interfaces/jwt-user.interface';
import { UsersService } from '../../users/users.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET', 'dev-chat-secret'),
    });
  }

  async validate(payload: JwtUser & { sub: string }): Promise<JwtUser> {
    const userId = payload.sub || payload.id;
    const user = await this.usersService.findByIdOrThrow(userId);
    if (!user) {
      throw new UnauthorizedException('登录状态已失效');
    }

    return { id: user.id, phone: user.phone };
  }
}
