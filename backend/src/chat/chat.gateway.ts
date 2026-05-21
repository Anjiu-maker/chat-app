import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { JwtService } from '@nestjs/jwt';
import { plainToInstance } from 'class-transformer';
import { validateOrReject } from 'class-validator';
import { Server, Socket } from 'socket.io';
import { JwtUser } from '../common/interfaces/jwt-user.interface';
import { ConversationsService } from '../conversations/conversations.service';
import { RedisService } from '../redis/redis.service';
import { UsersService } from '../users/users.service';
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';

@WebSocketGateway({
  cors: {
    origin: true,
    credentials: true,
  },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly chatService: ChatService,
    private readonly conversationsService: ConversationsService,
    private readonly jwtService: JwtService,
    private readonly redisService: RedisService,
    private readonly usersService: UsersService,
  ) {}

  async handleConnection(client: Socket) {
    const user = await this.authenticate(client);
    if (!user) {
      client.emit('auth:error', { message: '请先登录' });
      client.disconnect(true);
      return;
    }

    client.data.user = user;
    await client.join(this.userRoom(user.id));
    await this.redisService.setSocketOnline(client.id);
    await this.redisService.setUserOnline(user.id, client.id);
    client.emit('connected', { socketId: client.id, userId: user.id });
  }

  async handleDisconnect(client: Socket) {
    const user = client.data.user as JwtUser | undefined;
    await this.redisService.setSocketOffline(client.id);
    if (user) {
      await this.redisService.setUserOffline(user.id, client.id);
      await this.usersService.touchLastSeen(user.id);
    }
  }

  @SubscribeMessage('conversation:join')
  async joinConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { conversationId: string; afterSeq?: number },
  ) {
    const user = this.getSocketUser(client);
    await this.conversationsService.assertMember(user.id, body.conversationId);
    await client.join(body.conversationId);

    const recent =
      body.afterSeq != null
        ? await this.chatService.getMessagesAfter(
            user.id,
            body.conversationId,
            body.afterSeq,
          )
        : await this.chatService.getRecentMessages(
            user.id,
            body.conversationId,
          );
    client.emit(
      'conversation:history',
      body.afterSeq != null ? recent : recent.reverse(),
    );
    client.to(body.conversationId).emit('conversation:user_joined', {
      userId: user.id,
      socketId: client.id,
    });
  }

  @SubscribeMessage('conversation:leave')
  async leaveConversation(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { conversationId: string },
  ) {
    const user = this.getSocketUser(client);
    await client.leave(body.conversationId);
    client.to(body.conversationId).emit('conversation:user_left', {
      userId: user.id,
      socketId: client.id,
    });
  }

  @SubscribeMessage('message:send')
  async sendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: unknown,
  ) {
    const user = this.getSocketUser(client);
    const dto = plainToInstance(SendMessageDto, body);
    await validateOrReject(dto);

    const message = await this.chatService.createMessage(user.id, dto);
    this.server.to(dto.conversationId).emit('message:new', {
      ...message,
      clientId: dto.clientId, // echo back for offline-queue matching
    });
    const members = await this.conversationsService.listMembers(
      dto.conversationId,
    );
    for (const member of members) {
      const unreadCount =
        await this.conversationsService.unreadCountForMember(member);
      this.server
        .to(this.userRoom(member.userId))
        .emit('conversation:updated', {
          conversationId: dto.conversationId,
          messageId: message.id,
          message,
          lastMessagePreview: message.content,
          lastMessageAt: message.createdAt,
          unreadCount,
          senderId: user.id,
        });
    }
    return message;
  }

  @SubscribeMessage('message:read')
  async markRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { conversationId: string },
  ) {
    const user = this.getSocketUser(client);
    const result = await this.conversationsService.markRead(
      user.id,
      body.conversationId,
    );
    client.to(body.conversationId).emit('message:read', {
      conversationId: body.conversationId,
      userId: user.id,
      lastReadAt: result.lastReadAt,
    });
    this.server.to(this.userRoom(user.id)).emit('conversation:updated', {
      conversationId: body.conversationId,
      read: true,
      lastReadAt: result.lastReadAt,
      unreadCount: 0,
      userId: user.id,
    });
    return result;
  }

  private async authenticate(client: Socket): Promise<JwtUser | null> {
    const rawToken =
      client.handshake.auth?.token ||
      client.handshake.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!rawToken || typeof rawToken !== 'string') {
      return null;
    }

    try {
      const payload = await this.jwtService.verifyAsync<
        JwtUser & { sub: string }
      >(rawToken);
      return { id: payload.sub || payload.id, phone: payload.phone };
    } catch {
      // Socket 握手阶段不抛详细错误，避免向客户端暴露 token 解析细节。
      return null;
    }
  }

  private getSocketUser(client: Socket) {
    const user = client.data.user as JwtUser | undefined;
    if (!user) {
      throw new WsException('请先登录');
    }
    return user;
  }

  private userRoom(userId: string) {
    return `user:${userId}`;
  }
}
