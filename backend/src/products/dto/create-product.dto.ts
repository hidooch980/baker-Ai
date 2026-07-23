import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsPositive, IsString } from 'class-validator';

export class CreateProductDto {
  @ApiProperty()
  @IsString()
  code: string;

  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  type?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsNumber()
  weightGrams?: number;

  @ApiProperty({ required: false, default: 'عدد' })
  @IsOptional()
  @IsString()
  unit?: string;

  @ApiProperty({ description: 'قیمت فروش اولیه' })
  @IsNumber()
  @IsPositive()
  price: number;
}
