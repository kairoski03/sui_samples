module c::magic {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Magic has key, store {
        id: UID,
        magic: u64,
    }

    public entry fun create(ctx: &mut TxContext) {
        let magic = Magic {
            id: object::new(ctx),
            magic: 3
        };
        transfer::transfer(magic, tx_context::sender(ctx));
    }
}