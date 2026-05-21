import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum UserStatus {
  Active = 'active',
  Disabled = 'disabled',
}

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index({ unique: true })
  @Column({ length: 20 })
  phone!: string;

  @Column({ length: 80 })
  nickname!: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  avatarUrl?: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  bio?: string | null;

  @Column({ select: false })
  passwordHash!: string;

  @Column({ type: 'enum', enum: UserStatus, default: UserStatus.Active })
  status!: UserStatus;

  @Column({ type: 'datetime', nullable: true })
  lastSeenAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
