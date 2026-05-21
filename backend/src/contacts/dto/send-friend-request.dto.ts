import { IsNotEmpty, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class SendFriendRequestDto {
  @IsUUID()
  @IsNotEmpty()
  toUserId!: string;

  @IsString()
  @IsOptional()
  @MaxLength(200)
  message?: string;
}
