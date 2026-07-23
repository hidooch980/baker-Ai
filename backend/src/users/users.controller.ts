import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @RequirePermissions('users.manage')
  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @RequirePermissions('users.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @RequirePermissions('users.manage')
  @Post()
  create(@Body() dto: CreateUserDto, @CurrentUser() actor: { id: string }) {
    return this.usersService.create(dto, actor?.id);
  }

  @RequirePermissions('users.manage')
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateUserDto, @CurrentUser() actor: { id: string }) {
    return this.usersService.update(id, dto, actor?.id);
  }

  @RequirePermissions('users.manage')
  @Delete(':id')
  remove(@Param('id') id: string, @CurrentUser() actor: { id: string }) {
    return this.usersService.remove(id, actor?.id);
  }
}
