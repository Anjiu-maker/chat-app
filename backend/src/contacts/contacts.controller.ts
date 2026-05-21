import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { JwtUser } from '../common/interfaces/jwt-user.interface';
import { ChatGateway } from '../chat/chat.gateway';
import { ContactsService } from './contacts.service';
import { SendFriendRequestDto } from './dto/send-friend-request.dto';
import { UpdateContactDto } from './dto/update-contact.dto';

@Controller('contacts')
@UseGuards(JwtAuthGuard)
export class ContactsController {
  constructor(
    private readonly contactsService: ContactsService,
    private readonly chatGateway: ChatGateway,
  ) {}

  @Get()
  list(@CurrentUser() user: JwtUser) {
    return this.contactsService.list(user.id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() body: UpdateContactDto,
  ) {
    return this.contactsService.update(user.id, id, body);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.contactsService.remove(user.id, id);
  }

  // ── Friend requests ──

  @Post('requests')
  async sendRequest(
    @CurrentUser() user: JwtUser,
    @Body() body: SendFriendRequestDto,
  ) {
    const result = await this.contactsService.sendRequest(user.id, body);
    this.chatGateway.server
      .to(`user:${body.toUserId}`)
      .emit('friend:request', {
        id: result.id,
        fromUser: result.fromUser,
        message: result.message,
      });
    return result;
  }

  @Get('requests/incoming')
  incomingRequests(@CurrentUser() user: JwtUser) {
    return this.contactsService.pendingIncoming(user.id);
  }

  @Get('requests/outgoing')
  outgoingRequests(@CurrentUser() user: JwtUser) {
    return this.contactsService.pendingOutgoing(user.id);
  }

  @Post('requests/:id/accept')
  async acceptRequest(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    const result = await this.contactsService.acceptRequest(user.id, id);
    this.chatGateway.server
      .to(`user:${result.fromUser.id}`)
      .emit('friend:accepted', {
        byUser: result.toUser,
      });
    return result;
  }

  @Post('requests/:id/reject')
  async rejectRequest(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    const result = await this.contactsService.rejectRequest(user.id, id);
    return result;
  }

  @Delete('requests/:id')
  cancelRequest(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.contactsService.cancelRequest(user.id, id);
  }
}
