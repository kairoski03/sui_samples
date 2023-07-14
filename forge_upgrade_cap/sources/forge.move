module forge::forge {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::package::UpgradeCap;
    use sui::package;
    use sui::tx_context;

    struct Sword has key, store {
        id: UID,
        magic: u64,
    }

    struct Ownership has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let ownership = Ownership {
            id: object::new(ctx),
        };
        // Transfer the forge object to the module/package publisher
        transfer::transfer(ownership, tx_context::sender(ctx));
    }

    public entry fun create(magic: u64, recipient: address, ctx: &mut TxContext) {
        let sword = Sword {
            id: object::new(ctx),
            // magic: magic * 2, // on-chain
            magic: magic * 3, //fake
        };
        transfer::transfer(sword, recipient);
    }

    public entry fun make_immutable(cap: UpgradeCap) {
        package::make_immutable(cap);
    }

    public entry fun do(_: &Ownership) {
        // do something
    }
}