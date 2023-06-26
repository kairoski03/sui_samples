module b::strength {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Strength has key, store {
        id: UID,
        strength: u64,
    }

    public entry fun create(ctx: &mut TxContext) {
        let strength = Strength {
            id: object::new(ctx),
            strength: 3,
        };
        transfer::transfer(strength, tx_context::sender(ctx));
    }
}