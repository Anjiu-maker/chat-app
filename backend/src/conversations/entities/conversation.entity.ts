import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ConversationMember } from './conversation-member.entity';
import { GroupProfile } from './group-profile.entity';

export enum ConversationType {
  Direct = 'direct',
  Group = 'group',
}

@Entity({ name: 'conversations' })
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'enum', enum: ConversationType })
  type!: ConversationType;

  @Column({ type: 'varchar', length: 120, nullable: true })
  title?: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  avatarUrl?: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  lastMessagePreview?: string | null;

  @Column({ type: 'datetime', nullable: true })
  lastMessageAt?: Date | null;

  @OneToMany(() => ConversationMember, (member) => member.conversation)
  members!: ConversationMember[];

  @OneToOne(() => GroupProfile, (profile) => profile.conversation)
  groupProfile?: GroupProfile;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
