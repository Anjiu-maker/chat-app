import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { JwtUser } from '../common/interfaces/jwt-user.interface';
import { ChatService } from './chat.service';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get(':id/messages')
  messages(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Query('limit') limit?: string,
  ) {
    return this.chatService.getRecentMessages(
      user.id,
      id,
      limit ? parseInt(limit, 10) : 50,
    );
  }

  @Get(':id/messages/sync')
  syncMessages(
    @CurrentUser() user: JwtUser,
    @Param('id') id: string,
    @Query('afterSeq') afterSeq?: string,
  ) {
    return this.chatService.getMessagesAfter(
      user.id,
      id,
      afterSeq ? parseInt(afterSeq, 10) : 0,
    );
  }
}
