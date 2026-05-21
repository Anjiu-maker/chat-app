import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { Contact } from './entities/contact.entity';
import {
  FriendRequest,
  FriendRequestStatus,
} from './entities/friend-request.entity';

@Injectable()
export class ContactsService implements OnModuleInit {
  constructor(
    @InjectRepository(Contact)
    private readonly contacts: Repository<Contact>,
    @InjectRepository(FriendRequest)
    private readonly friendRequests: Repository<FriendRequest>,
    private readonly usersService: UsersService,
  ) {}

  async onModuleInit() {
    // Clean up legacy one-way contacts from old immediate-add flow.
    // Accepted friend requests create bidirectional rows — any orphaned
    // one-way rows are leftover from before the request/accept refactor.
    try {
      await this.contacts.query(
        `DELETE c1 FROM contacts c1
         LEFT JOIN contacts c2
           ON c1.ownerId = c2.contactUserId
          AND c1.contactUserId = c2.ownerId
         WHERE c2.id IS NULL`,
      );
    } catch {
      // Table may not exist yet on first run — ignore.
    }
  }

  // ── Contacts ──

  async list(ownerId: string) {
    const rows = await this.contacts.find({
      where: { ownerId },
      order: { updatedAt: 'DESC' },
    });
    return rows.map((row) => ({
      id: row.id,
      remark: row.remark,
      tag: row.tag,
      user: this.usersService.toPublicUser(row.contactUser),
    }));
  }

  async areContacts(ownerId: string, contactUserId: string) {
    const contact = await this.contacts.findOne({
      where: { ownerId, contactUserId },
      select: { id: true },
    });
    return Boolean(contact);
  }

  async update(
    ownerId: string,
    contactId: string,
    patch: { remark?: string; tag?: string },
  ) {
    const contact = await this.findEntityForOwner(ownerId, contactId);
    Object.assign(contact, patch);
    await this.contacts.save(contact);
    return this.findOneForOwner(ownerId, contactId);
  }

  async remove(ownerId: string, contactId: string) {
    const contact = await this.findEntityForOwner(ownerId, contactId);
    await this.contacts.remove(contact);
    return { deleted: true };
  }

  // ── Friend requests ──

  async sendRequest(fromUserId: string, dto: { toUserId: string; message?: string }) {
    if (fromUserId === dto.toUserId) {
      throw new BadRequestException('不能添加自己为好友');
    }
    await this.usersService.findByIdOrThrow(dto.toUserId);

    // Check if already contacts
    if (await this.areContacts(fromUserId, dto.toUserId)) {
      throw new ConflictException('已经是好友了');
    }

    // Check for existing pending request in either direction
    const existingPending = await this.friendRequests.findOne({
      where: [
        { fromUserId, toUserId: dto.toUserId, status: FriendRequestStatus.Pending },
        { fromUserId: dto.toUserId, toUserId: fromUserId, status: FriendRequestStatus.Pending },
      ],
    });
    if (existingPending) {
      if (existingPending.fromUserId === fromUserId) {
        throw new ConflictException('已发送过好友请求，请等待对方同意');
      }
      throw new ConflictException('对方已向你发送好友请求，请直接同意');
    }

    // If a previous request was rejected or cancelled, revive it
    const previous = await this.friendRequests.findOne({
      where: { fromUserId, toUserId: dto.toUserId },
    });
    if (previous) {
      previous.status = FriendRequestStatus.Pending;
      previous.message = dto.message ?? previous.message;
      previous.updatedAt = new Date();
      await this.friendRequests.save(previous);
      return {
        ...previous,
        fromUser: this.usersService.toPublicUser(previous.fromUser),
        toUser: this.usersService.toPublicUser(previous.toUser),
      };
    }

    const request = await this.friendRequests.save(
      this.friendRequests.create({
        fromUserId,
        toUserId: dto.toUserId,
        message: dto.message,
      }),
    );
    return {
      ...request,
      fromUser: this.usersService.toPublicUser(request.fromUser),
      toUser: this.usersService.toPublicUser(request.toUser),
    };
  }

  async acceptRequest(userId: string, requestId: string) {
    const request = await this.friendRequests.findOne({
      where: { id: requestId, toUserId: userId, status: FriendRequestStatus.Pending },
    });
    if (!request) {
      throw new NotFoundException('好友请求不存在或已处理');
    }

    request.status = FriendRequestStatus.Accepted;
    await this.friendRequests.save(request);

    // Delete any legacy one-way contacts between these two users
    await this.contacts.delete({
      ownerId: request.fromUserId,
      contactUserId: request.toUserId,
    });
    await this.contacts.delete({
      ownerId: request.toUserId,
      contactUserId: request.fromUserId,
    });

    // Create bidirectional contacts
    const now = new Date();
    await this.contacts.save([
      this.contacts.create({
        ownerId: request.fromUserId,
        contactUserId: request.toUserId,
        createdAt: now,
      }),
      this.contacts.create({
        ownerId: request.toUserId,
        contactUserId: request.fromUserId,
        createdAt: now,
      }),
    ]);

    return {
      accepted: true,
      fromUser: this.usersService.toPublicUser(request.fromUser),
      toUser: this.usersService.toPublicUser(request.toUser),
    };
  }

  async rejectRequest(userId: string, requestId: string) {
    const request = await this.friendRequests.findOne({
      where: { id: requestId, toUserId: userId, status: FriendRequestStatus.Pending },
    });
    if (!request) {
      throw new NotFoundException('好友请求不存在或已处理');
    }
    request.status = FriendRequestStatus.Rejected;
    await this.friendRequests.save(request);
    return { rejected: true };
  }

  async cancelRequest(userId: string, requestId: string) {
    const request = await this.friendRequests.findOne({
      where: { id: requestId, fromUserId: userId, status: FriendRequestStatus.Pending },
    });
    if (!request) {
      throw new NotFoundException('好友请求不存在或已处理');
    }
    request.status = FriendRequestStatus.Cancelled;
    await this.friendRequests.save(request);
    return { cancelled: true };
  }

  async pendingIncoming(userId: string) {
    const requests = await this.friendRequests.find({
      where: { toUserId: userId, status: FriendRequestStatus.Pending },
      order: { createdAt: 'DESC' },
    });
    return requests.map((r) => ({
      id: r.id,
      fromUser: this.usersService.toPublicUser(r.fromUser),
      message: r.message,
      createdAt: r.createdAt,
    }));
  }

  async pendingOutgoing(userId: string) {
    const requests = await this.friendRequests.find({
      where: { fromUserId: userId, status: FriendRequestStatus.Pending },
      order: { createdAt: 'DESC' },
    });
    return requests.map((r) => ({
      id: r.id,
      toUser: this.usersService.toPublicUser(r.toUser),
      message: r.message,
      createdAt: r.createdAt,
    }));
  }

  // ── Private helpers ──

  private async findOneForOwner(ownerId: string, contactId: string) {
    const contact = await this.findEntityForOwner(ownerId, contactId);
    return {
      id: contact.id,
      remark: contact.remark,
      tag: contact.tag,
      user: this.usersService.toPublicUser(contact.contactUser),
    };
  }

  private async findEntityForOwner(ownerId: string, contactId: string) {
    const contact = await this.contacts.findOne({
      where: { id: contactId, ownerId },
    });
    if (!contact) {
      throw new NotFoundException('联系人不存在');
    }
    return contact;
  }
}
