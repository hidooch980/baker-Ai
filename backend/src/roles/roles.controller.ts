import { Body, Controller, Get, Param, Post, Put } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { RolesService } from './roles.service';
import { RequirePermissions } from '../common/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('roles')
@Controller('roles')
export class RolesController {
  constructor(private readonly rolesService: RolesService) {}

  @RequirePermissions('roles.manage')
  @Get()
  findAll() {
    return this.rolesService.findAll();
  }

  @RequirePermissions('roles.manage')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.rolesService.findOne(id);
  }

  @RequirePermissions('roles.manage')
  @Post()
  create(@Body() body: { name: string; description?: string }, @CurrentUser() actor: { id: string }) {
    return this.rolesService.create(body.name, body.description, actor?.id);
  }

  @RequirePermissions('roles.manage')
  @Put(':id/permissions')
  setPermissions(@Param('id') id: string, @Body() body: { permissionIds: string[] }, @CurrentUser() actor: { id: string }) {
    return this.rolesService.setPermissions(id, body.permissionIds, actor?.id);
  }
}
