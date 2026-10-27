#![no_std]
//! FlowPay payday guarantee.
//!
//! An employer locks next payday's payroll in this contract. Every employee can
//! check on-chain that their salary is reserved and when it unlocks. From the
//! unlock time each salary can be claimed by its employee, or released to them
//! by anyone (e.g. FlowPay's backend on payday): funds can only ever move to the
//! employee recorded for them. The employer can recover what is still unclaimed
//! only after a grace period, never before payday.

use soroban_sdk::{
    contract, contracterror, contractevent, contractimpl, contracttype, panic_with_error, token, Address, Env, Vec,
};

/// Unclaimed salaries stay reserved for 30 days after payday before the employer may reclaim them.
pub const RECLAIM_GRACE_SECONDS: u64 = 30 * 24 * 60 * 60;
/// Same ceiling as FlowPay's atomic payroll batches.
pub const MAX_EMPLOYEES: u32 = 100;

#[contracterror]
#[derive(Copy, Clone, Debug, Eq, PartialEq, PartialOrd, Ord)]
#[repr(u32)]
pub enum Error {
    NoEmployees = 1,
    TooManyEmployees = 2,
    InvalidAmount = 3,
    DuplicateEmployee = 4,
    UnlockInPast = 5,
    PayrollNotFound = 6,
    NotUnlocked = 7,
    NothingToPay = 8,
    ReclaimTooEarly = 9,
    Overflow = 10,
}

#[contracttype]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Payroll {
    pub employer: Address,
    pub token: Address,
    /// Ledger timestamp (seconds) from which salaries can be paid out.
    pub unlock_at: u64,
    /// Ledger timestamp from which the employer may recover unclaimed salaries.
    pub reclaim_after: u64,
    pub total: i128,
    /// Still held by the contract for this payroll.
    pub remaining: i128,
    pub employees: Vec<Address>,
}

#[contracttype]
#[derive(Clone)]
enum DataKey {
    NextId,
    Payroll(u64),
    /// Unpaid salary of one employee in one payroll. Removed once paid.
    Salary(u64, Address),
}

#[contractevent(topics = ["payroll_funded"])]
pub struct PayrollFunded {
    #[topic]
    pub id: u64,
    pub employer: Address,
    pub total: i128,
    pub unlock_at: u64,
}

#[contractevent(topics = ["salary_paid"])]
pub struct SalaryPaid {
    #[topic]
    pub id: u64,
    #[topic]
    pub employee: Address,
    pub amount: i128,
}

#[contractevent(topics = ["payroll_reclaimed"])]
pub struct PayrollReclaimed {
    #[topic]
    pub id: u64,
    pub amount: i128,
}

#[contract]
pub struct PayrollVault;

fn bump<K: soroban_sdk::IntoVal<Env, soroban_sdk::Val>>(env: &Env, key: &K) {
    // Keep entries alive at least until the employer could reclaim (payday + 30 days).
    let max = env.storage().max_ttl();
    env.storage().persistent().extend_ttl(key, max / 2, max);
}

fn load(env: &Env, id: u64) -> Payroll {
    env.storage()
        .persistent()
        .get(&DataKey::Payroll(id))
        .unwrap_or_else(|| panic_with_error!(env, Error::PayrollNotFound))
}

fn pay(env: &Env, id: u64, payroll: &mut Payroll, employee: &Address) -> i128 {
    if env.ledger().timestamp() < payroll.unlock_at {
        panic_with_error!(env, Error::NotUnlocked);
    }
    let key = DataKey::Salary(id, employee.clone());
    let amount: i128 = env
        .storage()
        .persistent()
        .get(&key)
        .unwrap_or_else(|| panic_with_error!(env, Error::NothingToPay));
    // Effects before the external call.
    env.storage().persistent().remove(&key);
    payroll.remaining -= amount;
    env.storage().persistent().set(&DataKey::Payroll(id), payroll);
    token::Client::new(env, &payroll.token).transfer(&env.current_contract_address(), employee, &amount);
    SalaryPaid { id, employee: employee.clone(), amount }.publish(env);
    amount
}

#[contractimpl]
impl PayrollVault {
    /// Locks a payroll. `entries` are (employee, amount in the token's smallest unit).
    /// Transfers the total from the employer into the contract and returns the payroll id.
    pub fn fund(env: Env, employer: Address, token: Address, unlock_at: u64, entries: Vec<(Address, i128)>) -> u64 {
        employer.require_auth();
        if entries.is_empty() {
            panic_with_error!(&env, Error::NoEmployees);
        }
        if entries.len() > MAX_EMPLOYEES {
            panic_with_error!(&env, Error::TooManyEmployees);
        }
        if unlock_at <= env.ledger().timestamp() {
            panic_with_error!(&env, Error::UnlockInPast);
        }

        let id: u64 = env.storage().instance().get(&DataKey::NextId).unwrap_or(1);
        env.storage().instance().set(&DataKey::NextId, &(id + 1));
        env.storage().instance().extend_ttl(env.storage().max_ttl() / 2, env.storage().max_ttl());

        let mut total: i128 = 0;
        let mut employees = Vec::new(&env);
        for (employee, amount) in entries.iter() {
            if amount <= 0 {
                panic_with_error!(&env, Error::InvalidAmount);
            }
            if employees.contains(&employee) {
                panic_with_error!(&env, Error::DuplicateEmployee);
            }
            total = total.checked_add(amount).unwrap_or_else(|| panic_with_error!(&env, Error::Overflow));
            let key = DataKey::Salary(id, employee.clone());
            env.storage().persistent().set(&key, &amount);
            bump(&env, &key);
            employees.push_back(employee);
        }

        let payroll = Payroll {
            employer: employer.clone(),
            token: token.clone(),
            unlock_at,
            reclaim_after: unlock_at + RECLAIM_GRACE_SECONDS,
            total,
            remaining: total,
            employees,
        };
        let key = DataKey::Payroll(id);
        env.storage().persistent().set(&key, &payroll);
        bump(&env, &key);

        token::Client::new(&env, &token).transfer(&employer, &env.current_contract_address(), &total);
        PayrollFunded { id, employer, total, unlock_at }.publish(&env);
        id
    }

    /// The employee withdraws their salary (from `unlock_at`).
    pub fn claim(env: Env, id: u64, employee: Address) -> i128 {
        employee.require_auth();
        let mut payroll = load(&env, id);
        pay(&env, id, &mut payroll, &employee)
    }

    /// Anyone may push an unlocked salary to its employee; it can only go to them.
    pub fn release(env: Env, id: u64, employee: Address) -> i128 {
        let mut payroll = load(&env, id);
        pay(&env, id, &mut payroll, &employee)
    }

    /// The employer recovers unclaimed salaries, only after the grace period.
    pub fn reclaim(env: Env, id: u64) -> i128 {
        let mut payroll = load(&env, id);
        payroll.employer.require_auth();
        if env.ledger().timestamp() < payroll.reclaim_after {
            panic_with_error!(&env, Error::ReclaimTooEarly);
        }
        if payroll.remaining <= 0 {
            panic_with_error!(&env, Error::NothingToPay);
        }
        let amount = payroll.remaining;
        for employee in payroll.employees.iter() {
            env.storage().persistent().remove(&DataKey::Salary(id, employee));
        }
        payroll.remaining = 0;
        env.storage().persistent().set(&DataKey::Payroll(id), &payroll);
        token::Client::new(&env, &payroll.token).transfer(&env.current_contract_address(), &payroll.employer, &amount);
        PayrollReclaimed { id, amount }.publish(&env);
        amount
    }

    pub fn payroll(env: Env, id: u64) -> Payroll {
        load(&env, id)
    }

    /// The unpaid salary reserved for `employee` in payroll `id` (0 once paid).
    pub fn salary(env: Env, id: u64, employee: Address) -> i128 {
        env.storage().persistent().get(&DataKey::Salary(id, employee)).unwrap_or(0)
    }
}

#[cfg(test)]
mod test;
