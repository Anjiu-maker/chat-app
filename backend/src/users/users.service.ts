import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { Like, Repository } from 'typeorm';
import { FilesService } from '../files/files.service';
import { User } from './entities/user.entity';

export interface PublicUser {
  id: string;
  phone: string;
  nickname: string;
  avatarUrl?: string | null;
  bio?: string | null;
  lastSeenAt?: Date | null;
  createdAt: Date;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly users: Repository<User>,
    private readonly filesService: FilesService,
  ) {}

  toPublicUser(user: User): PublicUser {
    return {
      id: user.id,
      phone: user.phone,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      lastSeenAt: user.lastSeenAt,
      createdAt: user.createdAt,
    };
  }

  async create(params: {
    phone: string;
    nickname: string;
    passwordHash: string;
  }): Promise<User> {
    const existed = await this.findByPhone(params.phone);
    if (existed) {
      throw new ConflictException('手机号已注册');
    }

    return this.users.save(this.users.create(params));
  }

  findByPhone(phone: string) {
    return this.users.findOne({ where: { phone } });
  }

  findByPhoneWithPassword(phone: string) {
    return this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.phone = :phone', { phone })
      .getOne();
  }

  async findByIdOrThrow(id: string) {
    const user = await this.users.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException('用户不存在');
    }
    return user;
  }

  async findByIdWithPasswordOrThrow(id: string) {
    const user = await this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.id = :id', { id })
      .getOne();

    if (!user) {
      throw new NotFoundException('用户不存在');
    }

    return user;
  }

  async updateMe(
    userId: string,
    patch: { nickname?: string; avatarUrl?: string; bio?: string },
  ) {
    const user = await this.findByIdOrThrow(userId);

    if (patch.nickname !== undefined) {
      const nickname = patch.nickname.trim();
      if (!nickname) {
        throw new BadRequestException('昵称不能为空');
      }
      user.nickname = nickname;
    }

    if (patch.avatarUrl !== undefined) {
      user.avatarUrl = patch.avatarUrl || null;
    }

    if (patch.bio !== undefined) {
      user.bio = patch.bio.trim() || null;
    }

    return this.toPublicUser(await this.users.save(user));
  }

  async updateAvatar(userId: string, file?: Express.Multer.File) {
    const stored = await this.filesService.upload(userId, file, {
      folder: 'avatars',
      maxSizeMb: 5,
      allowedMimePattern: /^image\/(png|jpe?g|webp|gif)$/i,
      allowedExtensions: ['.png', '.jpg', '.jpeg', '.webp', '.gif'],
    });

    return this.updateMe(userId, { avatarUrl: stored.url });
  }

  async changePassword(
    userId: string,
    params: { currentPassword: string; newPassword: string },
  ) {
    const user = await this.findByIdWithPasswordOrThrow(userId);
    const ok = await bcrypt.compare(params.currentPassword, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('当前密码错误');
    }

    user.passwordHash = await bcrypt.hash(params.newPassword, 12);
    await this.users.save(user);

    return { changed: true };
  }

  async touchLastSeen(userId: string) {
    await this.users.update(userId, { lastSeenAt: new Date() });
  }

  async search(keyword = '') {
    const q = keyword.trim();
    const users = await this.users.find({
      where: q
        ? [{ nickname: Like(`%${q}%`) }, { phone: Like(`%${q}%`) }]
        : undefined,
      order: { updatedAt: 'DESC' },
      take: 30,
    });
    return users.map((user) => this.toPublicUser(user));
  }
}
