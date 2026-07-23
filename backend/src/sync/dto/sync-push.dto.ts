import { IsArray, IsIn, IsObject, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export const SYNCABLE_ENTITIES = ['Sale', 'Expense', 'Attendance', 'Production'] as const;
export type SyncableEntity = (typeof SYNCABLE_ENTITIES)[number];

export class SyncOperationDto {
  /** شناسه یکتای که موبایل هنگام کار آفلاین تولید کرده است (برای ردیابی ایدموتنت). */
  @IsString()
  clientOperationId!: string;

  @IsIn(SYNCABLE_ENTITIES)
  entity!: SyncableEntity;

  @IsIn(['CREATE', 'UPDATE', 'DELETE'])
  operation!: 'CREATE' | 'UPDATE' | 'DELETE';

  @IsOptional()
  @IsString()
  entityId?: string;

  @IsObject()
  payload!: Record<string, unknown>;
}

export class SyncPushDto {
  @IsString()
  clientId!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncOperationDto)
  operations!: SyncOperationDto[];
}
