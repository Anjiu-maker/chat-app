import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity({ name: 'file_objects' })
export class FileObject {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column()
  uploaderId!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  uploader!: User;

  @Column({ length: 255 })
  originalName!: string;

  @Column({ length: 120 })
  mimeType!: string;

  @Column({ type: 'bigint' })
  size!: number;

  @Column({ length: 120 })
  bucket!: string;

  @Column({ length: 500 })
  objectKey!: string;

  @Column({ length: 700 })
  url!: string;

  @CreateDateColumn()
  createdAt!: Date;
}
