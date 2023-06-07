module forge::forge {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::TxContext;

    struct Sword has key, store {
        id: UID,
        magic: u64,
    }

    public entry fun create(magic: u64, recipient: address, ctx: &mut TxContext) {
        let sword = Sword {
            id: object::new(ctx),
            magic: magic * 2,
        };
        transfer::transfer(sword, recipient);
    }
}