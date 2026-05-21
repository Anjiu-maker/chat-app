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

@Entity({ name: 'contacts' })
@Index(['ownerId', 'contactUserId'], { unique: true })
export class Contact {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  ownerId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  owner!: User;

  @Column()
  contactUserId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  contactUser!: User;

  @Column({ type: 'varchar', length: 80, nullable: true })
  remark?: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  tag?: string | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
