import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Conversation } from '../../conversations/entities/conversation.entity';
import { User } from '../../users/entities/user.entity';

export enum MessageType {
  Text = 'text',
  Image = 'image',
  File = 'file',
  System = 'system',
}

@Entity({ name: 'messages' })
export class Message {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column()
  conversationId!: string;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  conversation!: Conversation;

  @Index()
  @Column()
  senderId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  sender!: User;

  @Column({ type: 'enum', enum: MessageType, default: MessageType.Text })
  type!: MessageType;

  @Column({ type: 'text' })
  content!: string;

  @Column({ type: 'varchar', length: 64, nullable: true })
  fileId?: string | null;

  @Column({ type: 'datetime', nullable: true })
  editedAt?: Date | null;

  @Column({ type: 'datetime', nullable: true })
  deletedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @Column({ type: 'bigint', unsigned: true, nullable: true })
  serverSeq?: number | null;
}
