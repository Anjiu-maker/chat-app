import { Body, Controller, Get, Patch, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { JwtUser } from '../common/interfaces/jwt-user.interface';
import { SearchUsersDto } from './dto/search-users.dto';
import { UpdateMeDto } from './dto/update-me.dto';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async me(@CurrentUser() user: JwtUser) {
    return this.usersService.toPublicUser(
      await this.usersService.findByIdOrThrow(user.id),
    );
  }

  @Patch('me')
  updateMe(@CurrentUser() user: JwtUser, @Body() body: UpdateMeDto) {
    return this.usersService.updateMe(user.id, body);
  }

  @Get('search')
  search(@Query() query: SearchUsersDto) {
    return this.usersService.search(query.q);
  }
}
