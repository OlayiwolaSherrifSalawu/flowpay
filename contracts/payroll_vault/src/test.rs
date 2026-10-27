#![cfg(test)]
extern crate std;

use super::*;
use soroban_sdk::{
    testutils::{Address as _, Ledger},
    token::{StellarAssetClient, TokenClient},
    vec, Address, Env,
};

/// The SDK reports contract errors as `soroban_sdk::Error` codes.
fn err(e: Error) -> soroban_sdk::Error {
    soroban_sdk::Error::from_contract_error(e as u32)
}

const DAY: u64 = 24 * 60 * 60;
const NOW: u64 = 1_800_000_000;

struct Setup<'a> {
    env: Env,
    vault: PayrollVaultClient<'a>,
    usd: TokenClient<'a>,
    employer: Address,
    ada: Address,
    mateo: Address,
}

fn setup<'a>() -> Setup<'a> {
    let env = Env::default();
    env.mock_all_auths();
    env.ledger().with_mut(|l| l.timestamp = NOW);

    let issuer = Address::generate(&env);
    let sac = env.register_stellar_asset_contract_v2(issuer);
    let employer = Address::generate(&env);
    StellarAssetClient::new(&env, &sac.address()).mint(&employer, &1_000_000_000);

    let vault_id = env.register(PayrollVault, ());
    Setup {
        vault: PayrollVaultClient::new(&env, &vault_id),
        usd: TokenClient::new(&env, &sac.address()),
        ada: Address::generate(&env),
        mateo: Address::generate(&env),
        employer,
        env,
    }
}

fn fund(s: &Setup) -> u64 {
    s.vault.fund(
        &s.employer,
        &s.usd.address,
        &(NOW + 7 * DAY),
        &vec![&s.env, (s.ada.clone(), 970_000_000i128), (s.mateo.clone(), 10_000_000i128)],
    )
}

fn at(s: &Setup, t: u64) {
    s.env.ledger().with_mut(|l| l.timestamp = t);
}

#[test]
fn funding_locks_the_total_and_records_each_salary() {
    let s = setup();
    let id = fund(&s);
    assert_eq!(id, 1);
    assert_eq!(s.usd.balance(&s.employer), 20_000_000);
    assert_eq!(s.usd.balance(&s.vault.address), 980_000_000);

    let p = s.vault.payroll(&id);
    assert_eq!(p.total, 980_000_000);
    assert_eq!(p.remaining, 980_000_000);
    assert_eq!(p.unlock_at, NOW + 7 * DAY);
    assert_eq!(p.reclaim_after, NOW + 7 * DAY + RECLAIM_GRACE_SECONDS);
    assert_eq!(s.vault.salary(&id, &s.ada), 970_000_000);
    assert_eq!(s.vault.salary(&id, &s.mateo), 10_000_000);
    assert_eq!(fund_again(&s), 2, "ids increase");
}

fn fund_again(s: &Setup) -> u64 {
    s.vault.fund(&s.employer, &s.usd.address, &(NOW + DAY), &vec![&s.env, (s.ada.clone(), 1i128)])
}

#[test]
fn nobody_is_paid_before_payday() {
    let s = setup();
    let id = fund(&s);
    at(&s, NOW + 7 * DAY - 1);
    assert_eq!(s.vault.try_claim(&id, &s.ada), Err(Ok(err(Error::NotUnlocked))));
    assert_eq!(s.vault.try_release(&id, &s.mateo), Err(Ok(err(Error::NotUnlocked))));
}

#[test]
fn on_payday_employees_claim_or_are_released_exactly_once() {
    let s = setup();
    let id = fund(&s);
    at(&s, NOW + 7 * DAY);

    assert_eq!(s.vault.claim(&id, &s.ada), 970_000_000);
    assert_eq!(s.usd.balance(&s.ada), 970_000_000);
    assert_eq!(s.vault.try_claim(&id, &s.ada), Err(Ok(err(Error::NothingToPay))), "no double claim");

    assert_eq!(s.vault.release(&id, &s.mateo), 10_000_000);
    assert_eq!(s.usd.balance(&s.mateo), 10_000_000, "release pays the employee, never the caller");
    assert_eq!(s.vault.payroll(&id).remaining, 0);
    assert_eq!(s.usd.balance(&s.vault.address), 0);
}

#[test]
fn strangers_have_nothing_to_claim() {
    let s = setup();
    let id = fund(&s);
    at(&s, NOW + 8 * DAY);
    let stranger = Address::generate(&s.env);
    assert_eq!(s.vault.try_claim(&id, &stranger), Err(Ok(err(Error::NothingToPay))));
    assert_eq!(s.vault.try_claim(&99, &s.ada), Err(Ok(err(Error::PayrollNotFound))));
}

#[test]
fn employer_reclaims_only_unclaimed_and_only_after_the_grace_period() {
    let s = setup();
    let id = fund(&s);
    at(&s, NOW + 7 * DAY);
    s.vault.claim(&id, &s.ada);

    at(&s, NOW + 7 * DAY + RECLAIM_GRACE_SECONDS - 1);
    assert_eq!(s.vault.try_reclaim(&id), Err(Ok(err(Error::ReclaimTooEarly))));

    at(&s, NOW + 7 * DAY + RECLAIM_GRACE_SECONDS);
    assert_eq!(s.vault.reclaim(&id), 10_000_000);
    assert_eq!(s.usd.balance(&s.employer), 30_000_000);
    assert_eq!(s.vault.salary(&id, &s.mateo), 0);
    assert_eq!(s.vault.try_release(&id, &s.mateo), Err(Ok(err(Error::NothingToPay))));
    assert_eq!(s.vault.try_reclaim(&id), Err(Ok(err(Error::NothingToPay))));
}

#[test]
fn funding_rejects_bad_payrolls() {
    let s = setup();
    let e = &s.env;
    let t = NOW + DAY;
    assert_eq!(s.vault.try_fund(&s.employer, &s.usd.address, &t, &vec![e]), Err(Ok(err(Error::NoEmployees))));
    assert_eq!(
        s.vault.try_fund(&s.employer, &s.usd.address, &t, &vec![e, (s.ada.clone(), 0i128)]),
        Err(Ok(err(Error::InvalidAmount)))
    );
    assert_eq!(
        s.vault.try_fund(&s.employer, &s.usd.address, &t, &vec![e, (s.ada.clone(), 1i128), (s.ada.clone(), 2i128)]),
        Err(Ok(err(Error::DuplicateEmployee)))
    );
    assert_eq!(
        s.vault.try_fund(&s.employer, &s.usd.address, &NOW, &vec![e, (s.ada.clone(), 1i128)]),
        Err(Ok(err(Error::UnlockInPast)))
    );
    let mut many = vec![e];
    for _ in 0..=MAX_EMPLOYEES {
        many.push_back((Address::generate(e), 1i128));
    }
    assert_eq!(s.vault.try_fund(&s.employer, &s.usd.address, &t, &many), Err(Ok(err(Error::TooManyEmployees))));
    assert_eq!(s.usd.balance(&s.employer), 1_000_000_000, "failed funding moves nothing");
}

#[test]
fn funding_requires_the_employers_signature() {
    let env = Env::default();
    let issuer = Address::generate(&env);
    let sac = env.register_stellar_asset_contract_v2(issuer);
    let employer = Address::generate(&env);
    env.mock_all_auths();
    StellarAssetClient::new(&env, &sac.address()).mint(&employer, &100);
    let vault = PayrollVaultClient::new(&env, &env.register(PayrollVault, ()));
    vault.fund(&employer, &sac.address(), &(env.ledger().timestamp() + DAY), &vec![&env, (Address::generate(&env), 100i128)]);
    let auths = env.auths();
    assert!(auths.iter().any(|(who, _)| who == &employer), "employer authorized the funding");
}

#[test]
fn storage_rent_covers_the_reclaim_window_and_no_more() {
    use soroban_sdk::testutils::storage::Persistent;
    let s = setup();
    let id = fund(&s);
    let ttl = s.env.as_contract(&s.vault.address, || {
        s.env.storage().persistent().get_ttl(&DataKey::Payroll(id))
    });
    let needed = ((7 * DAY + RECLAIM_GRACE_SECONDS) / 5) as u32;
    assert!(ttl >= needed, "alive through the reclaim window: {ttl} < {needed}");
    assert!(ttl <= needed + 17_280 + 1, "not rented for longer than needed: {ttl}");
}

#[test]
fn a_full_100_person_payroll_fits_in_one_entry_and_pays_out() {
    let s = setup();
    let e = &s.env;
    let mut entries = vec![e];
    let mut people = std::vec::Vec::new();
    for _ in 0..MAX_EMPLOYEES {
        let who = Address::generate(e);
        people.push(who.clone());
        entries.push_back((who, 1_000_000i128));
    }
    // Real network budgets, not the unlimited test default.
    e.cost_estimate().budget().reset_default();
    let id = s.vault.fund(&s.employer, &s.usd.address, &(NOW + DAY), &entries);
    at(&s, NOW + DAY);
    e.cost_estimate().budget().reset_default();
    s.vault.release(&id, &people[99]);
    assert_eq!(s.usd.balance(&people[99]), 1_000_000);
    assert_eq!(s.vault.salary(&id, &people[0]), 1_000_000);
    assert_eq!(s.vault.payroll(&id).remaining, 99_000_000);
}
