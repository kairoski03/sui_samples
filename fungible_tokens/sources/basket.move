module fungible_tokens::basket {
    use fungible_tokens::managed::MANAGED;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance, Supply};
    use sui::object::{Self, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::TxContext;

    struct BASKET has drop {}

    struct Reserve has key {
        id: UID,
        total_supply: Supply<BASKET>,
        sui: Balance<SUI>,
        managed: Balance<MANAGED>,
    }

    const EBadDepositRatio: u64 = 0;

    fun init(witness: BASKET, ctx: &mut TxContext) {
        let total_supply = balance::create_supply<BASKET>(witness);

        transfer::share_object(Reserve{
            id: object::new(ctx),
            total_supply,
            sui: balance::zero<SUI>(),
            managed: balance::zero<MANAGED>(),
        })
    }

    public fun mint(
        reserve: &mut Reserve, sui: Coin<SUI>, managed: Coin<MANAGED>, ctx: &mut TxContext
    ): Coin<BASKET> {
        let num_sui = coin::value(&sui);
        assert!(num_sui == coin::value(&managed), EBadDepositRatio);

        coin::put(&mut reserve.sui, sui);
        coin::put(&mut reserve.managed, managed);

        let minted_balance = balance::increase_supply(&mut reserve.total_supply, num_sui);

        coin::from_balance(minted_balance, ctx)
    }

    public fun burn(
        reserve: &mut Reserve, basket: Coin<BASKET>, ctx: &mut TxContext
    ) : (Coin<SUI>, Coin<MANAGED>) {
        let num_basket = balance::decrease_supply(&mut reserve.total_supply, coin::into_balance(basket));
        let sui = coin::take(&mut reserve.sui, num_basket, ctx);
        let managed = coin::take(&mut reserve.managed, num_basket, ctx);

        (sui, managed)
    }

    public fun total_supply(reserve: &Reserve) : u64 {
        balance::supply_value(&reserve.total_supply)
    }

    public fun sui_supply(reserve: &Reserve): u64 {
        balance::value(&reserve.sui)
    }

    public fun managed_supply(reserve: &Reserve): u64 {
        balance::value(&reserve.sui)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BASKET {}, ctx)
    }
}