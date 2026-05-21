import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateConversationSettingsDto {
  @IsBoolean()
  @IsOptional()
  muted?: boolean;

  @IsBoolean()
  @IsOptional()
  pinned?: boolean;

  @IsBoolean()
  @IsOptional()
  savedToContacts?: boolean;
}
