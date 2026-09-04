import { prisma } from '../../db/index.js';

export type MoneyMission = NonNullable<Awaited<ReturnType<typeof prisma.moneyMission.findFirst>>>;

export class MoneyMissionService {
  static async listMissions(): Promise<MoneyMission[]> {
    try {
      return await prisma.moneyMission.findMany({
        orderBy: { createdAt: 'desc' },
      });
    } catch (err) {
      console.warn('[MoneyMissionService] listMissions error:', err);
      return [];
    }
  }

  static async createMission(data: {
    title: string;
    description: string;
    ruleType: string;
    condition: Record<string, unknown>;
    action: Record<string, unknown>;
  }): Promise<MoneyMission> {
    const id = `mission_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;

    return await prisma.moneyMission.create({
      data: {
        id,
        title: data.title,
        description: data.description,
        ruleType: data.ruleType,
        conditionJson: data.condition as any,
        actionJson: data.action as any,
        isActive: true,
      },
    });
  }

  static async toggleMission(id: string): Promise<{ is_active: boolean }> {
    const mission = await prisma.moneyMission.findUnique({
      where: { id },
      select: { isActive: true },
    });

    const nextState = !mission?.isActive;

    await prisma.moneyMission.update({
      where: { id },
      data: { isActive: nextState },
    });

    return { is_active: nextState };
  }
}
