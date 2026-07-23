import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsEnum, IsNumber, IsOptional, IsPositive, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { SaleType } from '@prisma/client';

export class CreateSaleItemDto {
  @ApiProperty()
  @IsUUID()
  productId: string;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  quantity: number;

  @ApiProperty({ required: false, description: 'اگر خالی بماند، قیمت فعلی محصول استفاده می‌شود' })
  @IsOptional()
  @IsNumber()
  unitPrice?: number;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  discount?: number;
}

export class CreateSaleDto {
  @ApiProperty({ enum: SaleType, default: SaleType.RETAIL })
  @IsEnum(SaleType)
  type: SaleType;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  customerId?: string;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  discount?: number;

  @ApiProperty({ type: [CreateSaleItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateSaleItemDto)
  items: CreateSaleItemDto[];

  @ApiProperty({ description: 'شناسه روش پرداخت (نقدی/کارتخوان/نسیه)' })
  @IsUUID()
  paymentMethodId: string;

  @ApiProperty({ required: false, description: 'مقدار پرداختی‌شده. اگر خالی بماند و فروش نسیه باشد، کل مبلف به بدهی مشتری می‌رود' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  paidAmount?: number;
}
