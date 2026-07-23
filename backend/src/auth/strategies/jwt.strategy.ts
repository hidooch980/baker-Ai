import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../prisma/prisma.service';

export type JwtPayload = { sub: string; phone: string };

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('jwt.accessSecret') as string,
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        userRoles: {
          include: { role: { include: { rolePermissions: { include: { permission: true } } } } },
        },
      },
    });

    if (!user || !user.isActive || user.deletedAt) {
      return null;
    }

    const permissions = new Set<string>();
    const roles: string[] = [];
    for (const userRole of user.userRoles) {
      roles.push(userRole.role.name);
      for (const rolePermission of userRole.role.rolePermissions) {
        permissions.add(rolePermission.permission.key);
      }
    }

    return {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      roles,
      permissions: Array.from(permissions),
    };
  }
}
