import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, MoreThan, Not, Repository } from 'typeorm';
import { Message } from '../chat/entities/message.entity';
import { ContactsService } from '../contacts/contacts.service';
import { UsersService } from '../users/users.service';
import {
  ConversationMember,
  ConversationMemberRole,
} from './entities/conversation-member.entity';
import { Conversation, ConversationType } from './entities/conversation.entity';
import { GroupProfile } from './entities/group-profile.entity';

@Injectable()
export class ConversationsService {
  constructor(
    @InjectRepository(Conversation)
    private readonly conversations: Repository<Conversation>,
    @InjectRepository(ConversationMember)
    private readonly members: Repository<ConversationMember>,
    @InjectRepository(GroupProfile)
    private readonly groupProfiles: Repository<GroupProfile>,
    @InjectRepository(Message)
    private readonly messages: Repository<Message>,
    private readonly contactsService: ContactsService,
    private readonly usersService: UsersService,
  ) {}

  async listForUser(userId: string) {
    const memberships = await this.members.find({
      where: { userId },
      order: { conversation: { lastMessageAt: 'DESC' }, updatedAt: 'DESC' },
    });

    return Promise.all(
      memberships.map((membership) =>
        this.decorateConversation(membership.conversation, membership),
      ),
    );
  }

  async getDetail(userId: string, conversationId: string) {
    const membership = await this.assertMember(userId, conversationId);
    return this.decorateConversation(membership.conversation, membership, true);
  }

  async createDirect(ownerId: string, targetUserId: string) {
    if (ownerId === targetUserId) {
      throw new BadRequestException('不能和自己创建单聊');
    }
    await this.usersService.findByIdOrThrow(targetUserId);
    if (!(await this.contactsService.areContacts(ownerId, targetUserId))) {
      throw new ForbiddenException('请先添加对方为好友，再发起单聊');
    }

    const existing = await this.findExistingDirect(ownerId, targetUserId);
    if (existing) {
      return this.getDetail(ownerId, existing);
    }

    const conversation = await this.conversations.save(
      this.conversations.create({ type: ConversationType.Direct }),
    );
    const now = new Date();
    await this.members.save([
      this.members.create({
        conversationId: conversation.id,
        userId: ownerId,
        joinedAt: now,
      }),
      this.members.create({
        conversationId: conversation.id,
        userId: targetUserId,
        joinedAt: now,
      }),
    ]);

    return this.getDetail(ownerId, conversation.id);
  }

  async createGroup(
    ownerId: string,
    params: { name: string; memberIds: string[]; announcement?: string },
  ) {
    const uniqueMemberIds = Array.from(new Set([ownerId, ...params.memberIds]));
    await Promise.all(
      uniqueMemberIds.map((id) => this.usersService.findByIdOrThrow(id)),
    );

    const conversation = await this.conversations.save(
      this.conversations.create({
        type: ConversationType.Group,
        title: params.name,
      }),
    );
    await this.groupProfiles.save(
      this.groupProfiles.create({
        conversationId: conversation.id,
        groupNo: this.createGroupNo(),
        ownerId,
        announcement: params.announcement,
        announcementUpdatedAt: params.announcement ? new Date() : null,
      }),
    );

    const now = new Date();
    await this.members.save(
      uniqueMemberIds.map((userId) =>
        this.members.create({
          conversationId: conversation.id,
          userId,
          joinedAt: now,
          role:
            userId === ownerId
              ? ConversationMemberRole.Owner
              : ConversationMemberRole.Member,
        }),
      ),
    );

    return this.getDetail(ownerId, conversation.id);
  }

  async listGroupsForUser(userId: string) {
    const conversations = await this.listForUser(userId);
    return conversations.filter(
      (conversation) => conversation.type === ConversationType.Group,
    );
  }

  async updateSettings(
    userId: string,
    conversationId: string,
    patch: { muted?: boolean; pinned?: boolean; savedToContacts?: boolean },
  ) {
    const membership = await this.assertMember(userId, conversationId);
    Object.assign(membership, patch);
    await this.members.save(membership);
    return this.getDetail(userId, conversationId);
  }

  async markRead(userId: string, conversationId: string) {
    const membership = await this.assertMember(userId, conversationId);
    membership.lastReadAt = new Date();
    await this.members.save(membership);
    return { read: true, lastReadAt: membership.lastReadAt };
  }

  async updateLastMessage(conversationId: string, preview: string) {
    await this.conversations.update(conversationId, {
      lastMessagePreview: preview.slice(0, 500),
      lastMessageAt: new Date(),
    });
  }

  async assertMember(userId: string, conversationId: string) {
    const membership = await this.members.findOne({
      where: { userId, conversationId },
    });
    if (!membership) {
      throw new ForbiddenException('你不在该会话中');
    }
    return membership;
  }

  async listMembers(conversationId: string) {
    return this.members.find({
      where: { conversationId },
      order: { role: 'ASC', createdAt: 'ASC' },
    });
  }

  private async decorateConversation(
    conversation: Conversation,
    membership: ConversationMember,
    withMembers = false,
  ) {
    const memberCount = await this.members.count({
      where: { conversationId: conversation.id },
    });
    const shouldIncludeMembers =
      withMembers || conversation.type === ConversationType.Direct;
    const groupProfile =
      conversation.type === ConversationType.Group
        ? await this.groupProfiles.findOne({
            where: { conversationId: conversation.id },
          })
        : null;
    const members = shouldIncludeMembers
      ? await this.members.find({ where: { conversationId: conversation.id } })
      : [];
    const unreadSince =
      membership.lastReadAt ?? membership.joinedAt ?? conversation.createdAt;
    const unreadCount = await this.messages.count({
      where: {
        conversationId: conversation.id,
        deletedAt: IsNull(),
        senderId: Not(membership.userId),
        createdAt: MoreThan(unreadSince),
      },
    });

    return {
      id: conversation.id,
      type: conversation.type,
      title: conversation.title,
      avatarUrl: conversation.avatarUrl,
      memberCount,
      unreadCount,
      lastMessagePreview: conversation.lastMessagePreview,
      lastMessageAt: conversation.lastMessageAt,
      settings: {
        muted: membership.muted,
        pinned: membership.pinned,
        savedToContacts: membership.savedToContacts,
        lastReadAt: membership.lastReadAt,
      },
      group: groupProfile
        ? {
            groupNo: groupProfile.groupNo,
            ownerId: groupProfile.ownerId,
            announcement: groupProfile.announcement,
            announcementUpdatedAt: groupProfile.announcementUpdatedAt,
          }
        : null,
      members: members.map((member) => ({
        id: member.id,
        role: member.role,
        joinedAt: member.joinedAt,
        user: this.usersService.toPublicUser(member.user),
      })),
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private createGroupNo() {
    // 群号需要人类可读，后续可替换成号段服务；当前先用时间片加随机数降低碰撞概率。
    return `${Date.now().toString().slice(-6)}${Math.floor(
      1000 + Math.random() * 9000,
    )}`;
  }

  private async findExistingDirect(ownerId: string, targetUserId: string) {
    const ownerMemberships = await this.members.find({
      where: {
        userId: ownerId,
        conversation: { type: ConversationType.Direct },
      },
    });
    if (ownerMemberships.length === 0) {
      return null;
    }

    const targetMembership = await this.members.findOne({
      where: {
        userId: targetUserId,
        conversationId: In(
          ownerMemberships.map((membership) => membership.conversationId),
        ),
      },
    });

    return targetMembership?.conversationId ?? null;
  }
}
