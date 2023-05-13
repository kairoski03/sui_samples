module forge_call::forge_call {
    use forge::forge;
    use sui::object::UID;
    use sui::tx_context::TxContext;

    struct Sword has key, store {
        id: UID,
        magic: u64,
        strength: u64,
    }

    public entry fun sword_create_test(magic: u64, strength: u64, recipient: address, ctx: &mut TxContext) {
        forge::sword_create_test(magic, strength, recipient, ctx);
    }
}