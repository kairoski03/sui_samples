module fungible_tokens::regulated_coin {
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    struct RegulatedCoin<phantom T> has key, store {
        id: UID,
        balance: Balance<T>,
        creator: address
    }

    public fun value<T>(c: &RegulatedCoin<T>): u64 {
        balance::value(&c.balance)
    }

    public fun creator<T>(c: &RegulatedCoin<T>): address {
        c.creator
    }

    public fun borrow<T: drop>(_: T, coin: &RegulatedCoin<T>): &Balance<T> {
        &coin.balance
    }

    public fun borrow_mut<T: drop>(_: T, coin: &mut RegulatedCoin<T>): &mut Balance<T> {
        &mut coin.balance
    }

    public fun zero<T: drop>(_: T, creator: address, ctx: &mut TxContext): RegulatedCoin<T> {
        RegulatedCoin { id: object::new(ctx), balance: balance::zero(), creator }
    }

    public fun from_balance<T: drop> (
        _: T, balance: Balance<T>, creator: address, ctx: &mut TxContext
    ): RegulatedCoin<T> {
        RegulatedCoin { id: object::new(ctx), balance, creator }
    }

    public fun into_balance<T: drop>(_: T, coin: RegulatedCoin<T>): Balance<T> {
        let RegulatedCoin { balance, creator: _, id} = coin;
        sui::object::delete(id);
        balance
    }

    public  fun join<T: drop>(witness: T, c1: &mut RegulatedCoin<T>, c2: RegulatedCoin<T>) {
        balance::join(&mut c1.balance, into_balance(witness, c2));
    }

    public fun split<T: drop>(
        witness: T, c1: &mut RegulatedCoin<T>, creator: address, value: u64, ctx: &mut TxContext
    ) : RegulatedCoin<T> {
        let balance = balance::split(&mut c1.balance, value);
        from_balance(witness, balance, creator, ctx)
    }
}

module abc::abc {
    use rc::regulated_coin::{Self as rcoin, RegulatedCoin as RCoin};
    use sui::balance::{Balance, Supply};
    use sui::object::UID;
    use sui::tx_context::TxContext;
    use sui::tx_context;
    use sui::object;
    use sui::balance;
    use sui::transfer;
    use std::vector;
    use sui::coin;
    use sui::coin::Coin;

    struct Abc has drop {}

    struct Transfer has key {
        id: UID,
        balance: Balance<Abc>,
        to: address,
    }

    struct Registry has key {
        id: UID,
        banned: vector<address>,
        swapped_amount: u64,
    }

    struct AbcTreasuryCap has key, store {
        id: UID,
        supply: Supply<Abc>
    }

    const ENotOwner: u64 = 1;
    const EAddressBanned: u64 = 2;

    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let treasury_cap = AbcTreasuryCap {
            id: object::new(ctx),
            supply: balance::create_supply(Abc {})
        };

        transfer::public_transfer(zero(sender, ctx), sender);
        transfer::public_transfer(treasury_cap, sender);

        transfer::share_object(Registry{
            id: object::new(ctx),
            banned: vector::empty(),
            swapped_amount: 0,
        })
    }

    public fun swapped_amount(r: &Registry): u64 {
        r.swapped_amount
    }

    public fun banned(r: &Registry): &vector<address> {
        &r.banned
    }

    public entry fun create(_: &AbcTreasuryCap, for: address, ctx: &mut TxContext) {
        transfer::public_transfer(zero(for, ctx), for)
    }


    public entry fun mint(treasury: &mut AbcTreasuryCap, owned: &mut RCoin<Abc>, value: u64) {
        balance::join(borrow_mut(owned), balance::increase_supply(&mut treasury.supply, value));
    }

    public entry fun burn(treasury: &mut AbcTreasuryCap, owned: &mut RCoin<Abc>, value: u64) {
        balance::decrease_supply(
            &mut treasury.supply,
            balance::split(borrow_mut(owned), value)
        );
    }

    public entry fun ban(_cap: &AbcTreasuryCap, registry: &mut Registry, to_ban: address) {
        vector::push_back(&mut registry.banned, to_ban)
    }

    public entry fun transfer(r: &Registry, coin: &mut RCoin<Abc>, value: u64, to: address, ctx: &mut TxContext) {
        let sender  = tx_context::sender(ctx);

        assert!(rcoin::creator(coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &to) == false, EAddressBanned);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        transfer::transfer(Transfer {
            to,
            id: object::new(ctx),
            balance: balance::split(borrow_mut(coin), value),
        }, to)
    }

    public entry fun accept_transfer(r: &Registry, coin: &mut RCoin<Abc>, transfer: Transfer) {
        let Transfer {id, balance, to} = transfer;

        assert!(rcoin::creator(coin) == to, ENotOwner);
        assert!(vector::contains(&r.banned, &to) == false, EAddressBanned);

        balance::join(borrow_mut(coin), balance);
        object::delete(id)
    }

    public entry fun take(r: &mut Registry, coin: &mut RCoin<Abc>, value: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(rcoin::creator(coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        r.swapped_amount = r.swapped_amount + value;

        transfer::public_transfer(coin::take(borrow_mut(coin), value, ctx), sender);
    }

    public entry fun put_back(r: &mut Registry, rc_coin: &mut RCoin<Abc>, coin: Coin<Abc>, ctx: &TxContext) {
        let balance = coin::into_balance(coin);
        let sender = tx_context::sender(ctx);

        assert!(rcoin::creator(rc_coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        r.swapped_amount = r.swapped_amount - balance::value(&balance);

        balance::join(borrow_mut(rc_coin), balance);
    }

    fun borrow(coin: &RCoin<Abc>): &Balance<Abc> { rcoin::borrow(Abc {}, coin) }
    fun borrow_mut(coin: &mut RCoin<Abc>): &mut Balance<Abc> { rcoin::borrow_mut(Abc {}, coin) }
    fun zero(creator: address, ctx: &mut TxContext): RCoin<Abc> { rcoin::zero(Abc {}, creator, ctx) }
    fun into_balance(coin: RCoin<Abc>): Balance<Abc> { rcoin::into_balance(Abc {}, coin) }
    fun from_balance(balance: Balance<Abc>, creator: address, ctx: &mut TxContext): RCoin<Abc> {
        rcoin::from_balance(Abc {}, balance, creator, ctx)
    }

    #[test_only] public fun init_for_testing(ctx: &mut TxContext) { init(ctx) }
    #[test_only] public fun borrow_for_testing(coin: &RCoin<Abc>): &Balance<Abc> { borrow(coin) }
    #[test_only] public fun borrow_mut_for_testing(coin: &mut RCoin<Abc>): &Balance<Abc> { borrow_mut(coin) }
}

#[test_only]
module abc::tests {
    use abc::abc::{Self, Abc, AbcTreasuryCap, Registry};
    use sui::test_scenario::{Self, Scenario, next_tx, ctx, };
    use rc::regulated_coin::{Self as rcoin, RegulatedCoin as RCoin};
    use sui::coin::Coin;

    #[test]
    fun test_minting() {
        let scenario = scenario();
        test_minting_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_creation() {
        let scenario = scenario();
        test_creation_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer() {
        let scenario = scenario();
        test_transfer_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_burn() {
        let scenario = scenario();
        test_burn_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_take() {
        let scenario = scenario();
        test_take_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_put_back() {
        let scenario = scenario();
        test_put_back_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_ban() {
        let scenario = scenario();
        test_ban_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = abc::abc::EAddressBanned)]
    fun test_address_banned_fail() {
        let scenario = scenario();
        test_address_banned_fail_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = abc::abc::EAddressBanned)]
    fun test_different_account_fail() {
        let scenario = scenario();
        test_different_account_fail_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = abc::abc::ENotOwner)]
    fun test_not_owned_balance_fail() {
        let scenario = scenario();
        test_not_owned_balance_fail_(&mut scenario);
        test_scenario::end(scenario);
    }

    fun scenario(): Scenario { test_scenario::begin(@0xAbc) }
    fun people(): (address, address, address) { (@0xAbc, @0xE05, @0xFACE) }

    fun test_minting_(test: &mut Scenario) {
        let (admin, _, _) = people();

        next_tx(test, admin);
        {
            abc::init_for_testing(ctx(test))
        };

        next_tx(test, admin);
        {
            let cap = test_scenario::take_from_sender<AbcTreasuryCap>(test);
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);

            abc::mint(&mut cap, &mut coin, 1000000);

            assert!(rcoin::value(&coin) == 1000000, 0);

            test_scenario::return_to_sender(test, cap);
            test_scenario::return_to_sender(test, coin);
        }
    }

    fun test_creation_(test: &mut Scenario) {
        let (admin, user1, _) = people();

        test_minting_(test);

        next_tx(test, admin);
        {
            let cap = test_scenario::take_from_sender<AbcTreasuryCap>(test);

            abc::create(&cap, user1, ctx(test));

            test_scenario::return_to_sender(test, cap);
        };

        next_tx(test, user1);
        {
          let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);

          assert!(rcoin::creator(&coin) == user1, 1);
          assert!(rcoin::value(&coin) == 0, 2);

          test_scenario::return_to_sender(test, coin);
        };
    }

    fun test_transfer_(test: &mut Scenario) {
        let (admin, user1, _) = people();

        test_creation_(test);

        next_tx(test, admin);
        {
            let coin  = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::transfer(reg_ref, &mut coin, 500000, user1, ctx(test));

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        };

        next_tx(test, user1);
        {
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let transfer = test_scenario::take_from_sender<abc::Transfer>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::accept_transfer(reg_ref, &mut coin, transfer);

            assert!(rcoin::value(&coin) == 500000, 3);

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        }
    }

    fun test_burn_(test: &mut Scenario) {
        let (admin, _, _) = people();

        test_transfer_(test);

        next_tx(test, admin);
        {
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let treasury_cap = test_scenario::take_from_sender<AbcTreasuryCap>(test);

            abc::burn(&mut treasury_cap, &mut coin, 100000);

            assert!(rcoin::value(&coin) == 400000, 4);

            test_scenario::return_to_sender(test, treasury_cap);
            test_scenario::return_to_sender(test, coin);
        };
    }

    fun test_take_(test: &mut Scenario) {
        let (_, user1, user2) = people();

        test_transfer_(test);

        next_tx(test, user1);
        {
            let coin  = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::take(reg_ref, &mut coin, 100000, ctx(test));

            assert!(abc::swapped_amount(reg_ref) == 100000, 5);
            assert!(rcoin::value(&coin) == 400000, 5);

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        };

        next_tx(test, user1);
        {
            let coin = test_scenario::take_from_sender<Coin<Abc>>(test);
            sui::transfer::public_transfer(coin, user2);
        };
    }

    fun test_put_back_(test: &mut Scenario) {
        let (admin, _, user2) = people();

        test_take_(test);

        next_tx(test, user2);
        {
            let coin  = test_scenario::take_from_sender<Coin<Abc>>(test);
            sui::transfer::public_transfer(coin, admin);
        };

        next_tx(test, admin);
        {
            let coin = test_scenario::take_from_sender<Coin<Abc>>(test);
            let reg_coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::put_back(reg_ref, &mut reg_coin, coin, ctx(test));

            test_scenario::return_to_sender(test, reg_coin);
            test_scenario::return_shared(reg);
        }
    }

    fun test_ban_(test: &mut Scenario) {
        let (admin, user1, _) = people();

        test_transfer_(test);

        next_tx(test, admin);
        {
            let cap = test_scenario::take_from_sender<AbcTreasuryCap>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::ban(&cap, reg_ref, user1);

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, cap);
        }
    }

    fun test_address_banned_fail_(test: &mut Scenario) {
        let (_, user1, user2) = people();

        test_ban_(test);

        next_tx(test, user1);
        {
            let coin  = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::transfer(reg_ref, &mut coin, 250000, user2, ctx(test));

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        };
    }

    fun test_different_account_fail_(test: &mut Scenario) {
        let (admin, user1, _) = people();

        test_ban_(test);

        next_tx(test, admin);
        {
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::transfer(reg_ref, &mut coin, 250000, user1, ctx(test));

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        };
    }

    fun test_not_owned_balance_fail_(test: &mut Scenario) {
        let (_, user1, user2) = people();

        test_ban_(test);

        next_tx(test, user1);
        {
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            sui::transfer::public_transfer(coin, user2);
        };

        next_tx(test, user2);
        {
            let coin = test_scenario::take_from_sender<RCoin<Abc>>(test);
            let reg = test_scenario::take_shared<Registry>(test);
            let reg_ref = &mut reg;

            abc::transfer(reg_ref, &mut coin, 500000, user1, ctx(test));
            // sui::transfer::public_transfer(coin, user1);

            test_scenario::return_shared(reg);
            test_scenario::return_to_sender(test, coin);
        }
    }
}
