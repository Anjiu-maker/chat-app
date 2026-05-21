import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, MoreThan, Repository } from 'typeorm';
import { ConversationsService } from '../conversations/conversations.service';
import { SendMessageDto } from './dto/send-message.dto';
import { Message, MessageType } from './entities/message.entity';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Message)
    private readonly messages: Repository<Message>,
    private readonly conversationsService: ConversationsService,
  ) {}

  async createMessage(senderId: string, payload: SendMessageDto) {
    await this.conversationsService.assertMember(
      senderId,
      payload.conversationId,
    );
    const message = await this.messages.save(
      this.messages.create({
        conversationId: payload.conversationId,
        senderId,
        type: (payload.type ?? MessageType.Text) as MessageType,
        content: payload.content,
        fileId: payload.fileId,
      }),
    );

    // 会话列表只需要轻量预览，文件消息展示成占位文案，避免列表泄露过多附件信息。
    await this.conversationsService.updateLastMessage(
      payload.conversationId,
      message.type === MessageType.Text ? message.content : `[${message.type}]`,
    );

    return this.messages.findOneOrFail({ where: { id: message.id } });
  }

  async getRecentMessages(userId: string, conversationId: string, limit = 50) {
    await this.conversationsService.assertMember(userId, conversationId);
    return this.messages.find({
      where: { conversationId, deletedAt: IsNull() },
      order: { createdAt: 'DESC' },
      take: Math.min(limit, 100),
    });
  }

  async getMessagesAfter(
    userId: string,
    conversationId: string,
    afterSeq: number,
  ) {
    await this.conversationsService.assertMember(userId, conversationId);
    return this.messages.find({
      where: {
        conversationId,
        serverSeq: MoreThan(afterSeq),
        deletedAt: IsNull(),
      },
      order: { serverSeq: 'ASC' },
      take: 100,
    });
  }
}
