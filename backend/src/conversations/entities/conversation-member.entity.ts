import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Conversation } from './conversation.entity';

export enum ConversationMemberRole {
  Owner = 'owner',
  Admin = 'admin',
  Member = 'member',
}

@Entity({ name: 'conversation_members' })
@Index(['conversationId', 'userId'], { unique: true })
export class ConversationMember {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column()
  conversationId!: string;

  @ManyToOne(() => Conversation, (conversation) => conversation.members, {
    eager: true,
    onDelete: 'CASCADE',
  })
  conversation!: Conversation;

  @Index()
  @Column()
  userId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  user!: User;

  @Column({
    type: 'enum',
    enum: ConversationMemberRole,
    default: ConversationMemberRole.Member,
  })
  role!: ConversationMemberRole;

  @Column({ default: false })
  muted!: boolean;

  @Column({ default: false })
  pinned!: boolean;

  @Column({ default: true })
  savedToContacts!: boolean;

  @Column({ type: 'datetime', nullable: true })
  lastReadAt?: Date | null;

  @Column({ type: 'datetime', nullable: true })
  joinedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
