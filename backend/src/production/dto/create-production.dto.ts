import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsDateString, IsEnum, IsInt, IsOptional, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { ShiftType } from '@prisma/client';

export class CreateProductionItemDto {
  @ApiProperty()
  @IsUUID()
  productId: string;

  @ApiProperty()
  @IsInt()
  @Min(0)
  producedQty: number;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  wasteQty?: number;

  @ApiProperty({ required: false, default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  returnedQty?: number;
}

export class CreateProductionDto {
  @ApiProperty()
  @IsDateString()
  date: string;

  @ApiProperty({ enum: ShiftType })
  @IsEnum(ShiftType)
  shift: ShiftType;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  operatorId?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  notes?: string;

  @ApiProperty({ type: [CreateProductionItemDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateProductionItemDto)
  items: CreateProductionItemDto[];
}
