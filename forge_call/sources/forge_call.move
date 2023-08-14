module forge_call::forge_call {
    use forge::forge;

    use sui::tx_context::TxContext;

    public entry fun sword_create_test(magic: u64, ctx: &mut TxContext) {
        forge::create(magic, ctx);
    }
}