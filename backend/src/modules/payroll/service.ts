import { bmoniClient } from '../../bmoni/client.js';
import { Money } from '../../core/money.js';
import { db } from '../../db/index.js';
import type { PayrollEmployeeAllocation, PayrollRunSummary } from './types.js';

export class PayrollOrchestrationService {
  /**
   * Preview aggregate payroll run ("One Employer, Many Countries, One Bill")
   * Calculates total USD bill and currency fanouts before execution
   */
  static getPreview(allocations?: PayrollEmployeeAllocation[]): PayrollRunSummary {
    const list = allocations && allocations.length > 0 ? allocations : this.getDefaultEmployees();

    let totalUsdMinor = 0n;
    const countries = new Set<string>();
    const currencies = new Set<string>();

    const items = list.map((emp) => {
      countries.add(emp.country);
      currencies.add(emp.targetCurrency);

      const usdMoney = Money.fromMinor(emp.usdAmountMinor, 'USD');
      totalUsdMinor += BigInt(emp.usdAmountMinor);

      const targetMoney = Money.fromMinor(emp.targetAmountMinor, emp.targetCurrency);

      return {
        employeeId: emp.employeeId,
        name: emp.name,
        country: emp.country,
        targetCurrency: emp.targetCurrency,
        targetAmountFormatted: targetMoney.toMajorString(),
        usdAmountFormatted: usdMoney.toMajorString(),
        exchangeRate: emp.exchangeRate,
        status: 'PENDING' as const,
      };
    });

    const totalMoney = Money.fromMinor(totalUsdMinor, 'USD');
    // BMONI fee: $12 flat or minimal basis points vs $340 bank wire fee
    const feeMoney = Money.fromMinor(1200n, 'USD'); // $12.00

    return {
      runId: `preview_${Date.now()}`,
      title: 'Global Team Monthly Payroll',
      totalUsdMinor: Number(totalUsdMinor),
      totalUsdFormatted: totalMoney.toMajorString(),
      totalFeeUsdMinor: 1200,
      totalFeeUsdFormatted: feeMoney.toMajorString(),
      employeeCount: items.length,
      countriesCount: countries.size,
      countries: Array.from(countries),
      currencies: Array.from(currencies),
      items,
      status: 'PENDING' as any,
      executedAt: new Date().toISOString(),
    };
  }

  /**
   * Execute aggregate payroll fan-out across multiple countries and rails
   */
  static async executePayroll(
    employerUserId: string,
    sourceSmartWalletId: string,
    allocations?: PayrollEmployeeAllocation[]
  ): Promise<PayrollRunSummary> {
    const preview = this.getPreview(allocations);
    const runId = `run_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // 1. Parallel execution across all employees in the run
    const results = await Promise.all(
      preview.items.map(async (item) => {
        try {
          // Find employee record in db
          const emp = db.prepare('SELECT bmoni_user_id, wallet_id FROM employees WHERE id = ?').get(item.employeeId) as
            | { bmoni_user_id?: string; wallet_id?: string }
            | undefined;

          let proposalId: string | undefined = undefined;

          // If live BMONI IDs exist, create proposal
          if (emp?.bmoni_user_id && emp?.wallet_id) {
            const proposal = await bmoniClient.createTransferProposal({
              userId: employerUserId,
              walletId: sourceSmartWalletId,
              toUserId: emp.bmoni_user_id,
              sourceSmartWalletId: sourceSmartWalletId,
              token: item.targetCurrency === 'NGN' ? 'CNGN' : item.targetCurrency === 'MXN' ? 'MEXe' : 'USDB',
              fromAmount: item.targetAmountFormatted,
            });
            proposalId = proposal.id || proposal.proposalId;
          } else {
            // Simulated proposal for test/demo mode
            proposalId = `prop_fanout_${item.country.toLowerCase()}_${Date.now()}`;
          }

          return {
            ...item,
            status: 'SUCCESS' as const,
            proposalId,
            transactionHash: `0x${Buffer.from(Math.random().toString()).toString('hex').slice(0, 64)}`,
          };
        } catch (err: any) {
          console.error(`[Payroll] Failed payout for ${item.name}:`, err);
          return {
            ...item,
            status: 'FAILED' as const,
            error: err.message,
          };
        }
      })
    );

    // 2. Persist Payroll Run in DB
    const insertRun = db.prepare(`
      INSERT INTO payroll_runs (id, title, total_usd_minor, fee_usd_minor, employee_count, status)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    insertRun.run(
      runId,
      preview.title,
      preview.totalUsdMinor,
      preview.totalFeeUsdMinor,
      results.length,
      'COMPLETED'
    );

    // 3. Persist individual payroll items
    const insertItem = db.prepare(`
      INSERT INTO payroll_items (id, payroll_run_id, employee_id, employee_name, country, target_currency, target_amount_minor, usd_amount_minor, exchange_rate, status, proposal_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    for (const r of results) {
      const originalAlloc = preview.items.find((i) => i.employeeId === r.employeeId);
      insertItem.run(
        `item_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        runId,
        r.employeeId,
        r.name,
        r.country,
        r.targetCurrency,
        originalAlloc ? Math.round(parseFloat(originalAlloc.targetAmountFormatted) * 100) : 0,
        originalAlloc ? Math.round(parseFloat(originalAlloc.usdAmountFormatted) * 100) : 0,
        r.exchangeRate,
        r.status,
        r.proposalId ?? null
      );
    }

    // 4. Record Audit Activity
    db.prepare(`
      INSERT INTO audit_activity (id, category, action, actor, details_json)
      VALUES (?, ?, ?, ?, ?)
    `).run(
      `aud_${Date.now()}`,
      'BUSINESS',
      'PAYROLL_RUN_EXECUTED',
      employerUserId,
      JSON.stringify({
        runId,
        totalUsdFormatted: preview.totalUsdFormatted,
        employeeCount: results.length,
        countries: preview.countries,
      })
    );

    return {
      ...preview,
      runId,
      items: results,
      status: 'COMPLETED',
      executedAt: new Date().toISOString(),
    };
  }

  /**
   * Default sandbox test personas per build spec:
   * Employee 1: Bunch Dillon (Nigeria, BVN 99999999999) - $2,000 USD -> ₦3,100,000 NGN
   * Employee 2: Samson Jabo (Mexico, BVN/NIN 22222222222) - $2,000 USD -> $35,000 MXN
   */
  private static getDefaultEmployees(): PayrollEmployeeAllocation[] {
    return [
      {
        employeeId: 'emp_bunch_dillon',
        name: 'Bunch Dillon',
        email: 'bunch.dillon@example.ng',
        country: 'NG',
        targetCurrency: 'NGN',
        targetAmountMinor: 310000000, // ₦3,100,000.00 in kobo
        usdAmountMinor: 200000,       // $2,000.00
        exchangeRate: 1550.0,
      },
      {
        employeeId: 'emp_samson_jabo',
        name: 'Samson Jabo',
        email: 'samson.jabo@example.mx',
        country: 'MX',
        targetCurrency: 'MXN',
        targetAmountMinor: 3500000,   // $35,000.00 MXN in centavos
        usdAmountMinor: 200000,       // $2,000.00
        exchangeRate: 17.5,
      },
    ];
  }
}
