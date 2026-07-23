import { ApiProperty } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsPositive, IsString, IsUUID } from 'class-validator';

export class CreateEmployeeDto {
  @ApiProperty()
  @IsString()
  fullName: string;

  @ApiProperty({ description: 'مدیر | فروشنده | خمیرگیر | چانه‌گیر | نانوا | حسابدار' })
  @IsString()
  role: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  baseSalary?: number;

  @ApiProperty({ required: false, description: 'اگر این کارمند همزمان کاربر سیستم هم هست، شناسه کاربر را وارد کنید' })
  @IsOptional()
  @IsUUID()
  userId?: string;
}
