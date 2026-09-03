import { bmoniClient } from '../../bmoni/client.js';
import { prisma } from '../../db/index.js';
import { env } from '../../config/env.js';


export type EmployeeRecord = NonNullable<Awaited<ReturnType<typeof prisma.employee.findFirst>>>;

export class EmployeeService {
  static async listEmployees(): Promise<EmployeeRecord[]> {
    try {
      return await prisma.employee.findMany({
        orderBy: { createdAt: 'desc' },
      });
    } catch (err) {
      console.warn('[EmployeeService] listEmployees error:', err);
      return [];
    }
  }

  static async getEmployeeById(id: string): Promise<EmployeeRecord | undefined> {
    try {
      const employee = await prisma.employee.findUnique({ where: { id } });
      return employee ?? undefined;
    } catch (err) {
      console.warn('[EmployeeService] getEmployeeById error:', err);
      return undefined;
    }
  }

  static async inviteEmployee(data: {
    firstName: string;
    lastName: string;
    email: string;
    phoneNumber?: string;
    country: string;
    targetCurrency: string;
  }): Promise<{ employee: EmployeeRecord; inviteUrl: string }> {
    const id = `emp_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;

    // 1. Call BMONI partner employee invite endpoint
    let inviteUrl = `https://bmoni.com/invite/flowpay_${id}`;
    try {
      const res = await bmoniClient.inviteEmployee({
        name: `${data.firstName} ${data.lastName}`,
        email: data.email,
        country: data.country,
      });
      if (res.inviteUrl) {
        inviteUrl = res.inviteUrl;
      }
    } catch (err) {
      console.warn('[EmployeeService] BMONI invite fallback (offline/sandbox):', err);
    }

    // 2. Insert via Prisma
    const employee = await prisma.employee.create({
      data: {
        id,
        partnerId: env.BMONI_PARTNER_ID,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        phoneNumber: data.phoneNumber ?? null,
        country: data.country,
        targetCurrency: data.targetCurrency,
        status: 'INVITED',
      },
    });

    return { employee, inviteUrl };
  }
}
