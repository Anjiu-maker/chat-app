import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly client: Redis;

  constructor(config: ConfigService) {
    this.client = new Redis({
      host: config.get<string>('REDIS_HOST', '127.0.0.1'),
      port: config.get<number>('REDIS_PORT', 6379),
      password: config.get<string>('REDIS_PASSWORD') || undefined,
      lazyConnect: true,
      maxRetriesPerRequest: 2,
    });
  }

  async setSocketOnline(socketId: string) {
    await this.ensureConnected();
    await this.client.sadd('chat:online_sockets', socketId);
  }

  async setUserOnline(userId: string, socketId: string) {
    await this.ensureConnected();
    await this.client.sadd(this.onlineUserKey(userId), socketId);
    await this.client.set(`chat:presence:${userId}`, 'online', 'EX', 120);
  }

  async setSocketOffline(socketId: string) {
    await this.ensureConnected();
    await this.client.srem('chat:online_sockets', socketId);
  }

  async setUserOffline(userId: string, socketId: string) {
    await this.ensureConnected();
    await this.client.srem(this.onlineUserKey(userId), socketId);
    const remain = await this.client.scard(this.onlineUserKey(userId));
    if (remain === 0) {
      await this.client.del(`chat:presence:${userId}`);
    }
  }

  async setOtp(
    phone: string,
    scene: 'register' | 'login',
    code: string,
    ttlSeconds: number,
  ) {
    await this.ensureConnected();
    await this.client.set(this.otpKey(phone, scene), code, 'EX', ttlSeconds);
  }

  async getOtp(phone: string, scene: 'register' | 'login') {
    await this.ensureConnected();
    return this.client.get(this.otpKey(phone, scene));
  }

  async deleteOtp(phone: string, scene: 'register' | 'login') {
    await this.ensureConnected();
    await this.client.del(this.otpKey(phone, scene));
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  private async ensureConnected() {
    if (this.client.status === 'wait' || this.client.status === 'end') {
      await this.client.connect();
    }
  }

  private otpKey(phone: string, scene: 'register' | 'login') {
    // 验证码按手机号和场景隔离，避免注册码被误用于登录等跨场景复用。
    return `chat:otp:${scene}:${phone}`;
  }

  private onlineUserKey(userId: string) {
    return `chat:online_user:${userId}`;
  }
}
