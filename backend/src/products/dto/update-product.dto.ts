import { ApiProperty, PartialType } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsPositive } from 'class-validator';
import { CreateProductDto } from './create-product.dto';

export class UpdateProductDto extends PartialType(CreateProductDto) {
  @ApiProperty({ required: false, description: 'اگر قیمت تفییر کند، تاریخچه قیمت قبلی حفق و قیمت جدید ثبت می‌شود' })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  price?: number;
}
