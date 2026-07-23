import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsArray, IsNumber, IsOptional, IsPositive, IsUUID, ValidateNested } from 'class-validator';

export class CreateDoughDivisionDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  productId?: string;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  pieceCount: number;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  pieceWeightG: number;
}

export class CreateDoughBatchDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  productionId?: string;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  flourKg: number;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  waterLiters: number;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  saltKg: number;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  yeastKg: number;

  @ApiProperty()
  @IsNumber()
  @IsPositive()
  doughWeightKg: number;

  @ApiProperty({ required: false, type: [CreateDoughDivisionDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateDoughDivisionDto)
  divisions?: CreateDoughDivisionDto[];
}
