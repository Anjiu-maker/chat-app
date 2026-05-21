import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { JwtUser } from '../common/interfaces/jwt-user.interface';
import { ConversationsService } from './conversations.service';
import { CreateDirectConversationDto } from './dto/create-direct-conversation.dto';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateConversationSettingsDto } from './dto/update-conversation-settings.dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get('conversations')
  list(@CurrentUser() user: JwtUser) {
    return this.conversationsService.listForUser(user.id);
  }

  @Get('conversations/:id')
  detail(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.conversationsService.getDetail(user.id, id);
  }

  @Post('conversations/direct')
  createDirect(
    @CurrentUser() user: JwtUser,
    @Body() body: CreateDirectConversationDto,
  ) {
    return this.conversationsService.createDirect(user.id, body.targetUserId);
  }

  @Patch('conversations/:id/settings')
  updateSettings(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Body() body: UpdateConversationSettingsDto,
  ) {
    return this.conversationsService.updateSettings(user.id, id, body);
  }

  @Post('conversations/:id/read')
  markRead(@CurrentUser() user: JwtUser, @Param('id') id: string) {
    return this.conversationsService.markRead(user.id, id);
  }

  @Get('groups')
  groups(@CurrentUser() user: JwtUser) {
    return this.conversationsService.listGroupsForUser(user.id);
  }

  @Post('groups')
  createGroup(@CurrentUser() user: JwtUser, @Body() body: CreateGroupDto) {
    return this.conversationsService.createGroup(user.id, body);
  }
}
