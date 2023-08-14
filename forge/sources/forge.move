module forge::forge {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};

    struct Sword has key, store {
        id: UID,
        magic: u64,
    }

    public entry fun create(magic: u64, ctx: &mut TxContext) {
        let sword = Sword {
            id: object::new(ctx),
            magic: magic * 1,
        };
        transfer::transfer(sword, sender(ctx));
    }
}