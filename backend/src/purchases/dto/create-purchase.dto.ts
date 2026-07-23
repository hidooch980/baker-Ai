import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsIn, IsNumber, IsOptional, IsPositive, IsString, IsUUID, Min, ValidateNested } from 'class-validator';

export class CreatePurchaseItemDto {
  @ApiProperty()
  @IsString()
  itemName: string;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  quantity: number;

  @ApiProperty()
  @IsString()
  unit: string;

  @ApiProperty()
  @IsNumber()
  @Min(0)
  unitPrice: number;
}

export class CreatePurchaseDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  invoiceNumber?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  supplierId?: string;

  @ApiProperty({ enum: ['FLOUR', 'MATERIAL', 'FUEL', 'EQUIPMENT', 'OTHER'] })
  @IsIn(['FLOUR', 'MATERIAL', 'FUEL', 'EQUIPMENT', 'OTHER'])
  category: string;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  discount?: number;

  @ApiProperty({ required: false, default: 0, description: 'مقدار پرداخت‌شده در لحظه خرید. مابقی به عنوان بدهی تامین‌کننده ثبت می‌شود' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  paidAmount?: number;

  @ApiProperty({ type: [CreatePurchaseItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreatePurchaseItemDto)
  items: CreatePurchaseItemDto[];
}
