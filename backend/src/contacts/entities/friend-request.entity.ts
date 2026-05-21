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

export enum FriendRequestStatus {
  Pending = 'pending',
  Accepted = 'accepted',
  Rejected = 'rejected',
  Cancelled = 'cancelled',
}

@Entity({ name: 'friend_requests' })
@Index(['fromUserId', 'toUserId'])
export class FriendRequest {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column()
  fromUserId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  fromUser!: User;

  @Index()
  @Column()
  toUserId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  toUser!: User;

  @Column({
    type: 'enum',
    enum: FriendRequestStatus,
    default: FriendRequestStatus.Pending,
  })
  status!: FriendRequestStatus;

  @Column({ type: 'varchar', length: 200, nullable: true })
  message?: string | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
