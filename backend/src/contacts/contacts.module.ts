import { forwardRef, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatModule } from '../chat/chat.module';
import { UsersModule } from '../users/users.module';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';
import { Contact } from './entities/contact.entity';
import { FriendRequest } from './entities/friend-request.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Contact, FriendRequest]),
    UsersModule,
    forwardRef(() => ChatModule),
  ],
  controllers: [ContactsController],
  providers: [ContactsService],
  exports: [ContactsService, TypeOrmModule],
})
export class ContactsModule {}
