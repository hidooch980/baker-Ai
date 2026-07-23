import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const PERMISSIONS: Array<{ key: string; module: string; description: string }> = [
  { key: 'users.manage', module: 'users', description: 'مدیریت کاربران' },
  { key: 'roles.manage', module: 'roles', description: 'مدیریت نقش‌ها و دسترسی‌ها' },
  { key: 'sales.create', module: 'sales', description: 'ثبت فروش' },
  { key: 'sales.view', module: 'sales', description: 'مشاهده فروش' },
  { key: 'customers.manage', module: 'customers', description: 'مدیریت مشتریان' },
  { key: 'production.manage', module: 'production', description: 'مدیریت تولید' },
  { key: 'dough.manage', module: 'dough', description: 'مدیریت خمیر و چانه' },
  { key: 'finance.manage', module: 'finance', description: 'مدیریت مالی و صندوق' },
  { key: 'reports.view', module: 'reports', description: 'مشاهده گزارش‌ها' },
  { key: 'employees.manage', module: 'employees', description: 'مدیریت پرسنل، حضور و غیاب و حقوق و دستمزد' },
];

const ROLES: Array<{ name: string; permissionKeys: string[] }> = [
  { name: 'مدیر', permissionKeys: PERMISSIONS.map((p) => p.key) },
  { name: 'فروشنده', permissionKeys: ['sales.create', 'sales.view', 'customers.manage'] },
  { name: 'خمیرگیر', permissionKeys: ['production.manage', 'dough.manage'] },
  { name: 'چانه‌گیر', permissionKeys: ['production.manage', 'dough.manage'] },
  { name: 'نانوا', permissionKeys: ['production.manage'] },
  { name: 'حسابدار', permissionKeys: ['finance.manage', 'reports.view', 'employees.manage'] },
];

async function main() {
  for (const perm of PERMISSIONS) {
    await prisma.permission.upsert({
      where: { key: perm.key },
      update: {},
      create: perm,
    });
  }

  for (const role of ROLES) {
    const createdRole = await prisma.role.upsert({
      where: { name: role.name },
      update: {},
      create: { name: role.name, isSystem: true },
    });

    for (const key of role.permissionKeys) {
      const permission = await prisma.permission.findUnique({ where: { key } });
      if (!permission) continue;
      await prisma.rolePermission.upsert({
        where: { roleId_permissionId: { roleId: createdRole.id, permissionId: permission.id } },
        update: {},
        create: { roleId: createdRole.id, permissionId: permission.id },
      });
    }
  }

  const adminPasswordHash = await bcrypt.hash('ChangeMe123!', 10);
  const adminUser = await prisma.user.upsert({
    where: { phone: '09000000000' },
    update: {},
    create: {
      fullName: 'مدیر سیستم',
      phone: '09000000000',
      passwordHash: adminPasswordHash,
    },
  });

  const adminRole = await prisma.role.findUnique({ where: { name: 'مدیر' } });
  if (adminRole) {
    await prisma.userRole.upsert({
      where: { userId_roleId: { userId: adminUser.id, roleId: adminRole.id } },
      update: {},
      create: { userId: adminUser.id, roleId: adminRole.id },
    });
  }

  const defaultCategories = ['برق', 'آب', 'گاز', 'اجاره', 'تعمیرات', 'حقوق', 'حمل‌ونقل', 'سوخت', 'مواد اولیه', 'مالیات', 'بیمه', 'سایر'];
  for (const name of defaultCategories) {
    await prisma.expenseCategory.upsert({ where: { name }, update: {}, create: { name } });
  }

  console.log('Seed completed. Default admin phone: 09000000000 / password: ChangeMe123!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
