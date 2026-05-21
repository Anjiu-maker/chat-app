import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Conversation } from './conversation.entity';

@Entity({ name: 'group_profiles' })
export class GroupProfile {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  conversationId!: string;

  @OneToOne(() => Conversation, (conversation) => conversation.groupProfile, {
    eager: true,
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'conversationId' })
  conversation!: Conversation;

  @Column({ length: 40, unique: true })
  groupNo!: string;

  @Column()
  ownerId!: string;

  @Column({ type: 'varchar', length: 500, nullable: true })
  announcement?: string | null;

  @Column({ type: 'datetime', nullable: true })
  announcementUpdatedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
