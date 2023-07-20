use libra_types::legacy_types::legacy_recovery::LegacyRecovery;
use zapatos_crypto::{ed25519::Ed25519PublicKey, HashValue};
use zapatos_framework::{self, ReleaseBundle};
use zapatos_gas::{
    AbstractValueSizeGasParameters, ChangeSetConfigs, NativeGasParameters,
    LATEST_GAS_FEATURE_VERSION,
};
use zapatos_types::{
    chain_id::ChainId,
    on_chain_config::{Features, GasScheduleV2, OnChainConsensusConfig, OnChainExecutionConfig, TimedFeatures},
    transaction::ChangeSet,
};
use zapatos_vm::{
    data_cache::AsMoveResolver,
    move_vm_ext::{MoveVmExt, SessionId},
};
use zapatos_vm_genesis::{
    create_and_initialize_validators,
    default_gas_schedule, emit_new_block_and_epoch_event, genesis_context::GenesisStateView,
    initialize, initialize_aptos_coin,
    initialize_features, initialize_on_chain_governance, mainnet_genesis_config, publish_framework,
    set_genesis_end, validate_genesis_config, verify_genesis_write_set, GenesisConfiguration, Validator, GENESIS_KEYPAIR,
};

use crate::supply::SupplySettings;

pub fn migration_genesis(
    validators: &[Validator],
    recovery: Option<&[LegacyRecovery]>,
    framework: &ReleaseBundle,
    chain_id: ChainId,
    supply_settings: &SupplySettings,
) -> anyhow::Result<ChangeSet> {
    let genesis = encode_genesis_change_set(
        &GENESIS_KEYPAIR.1,
        validators,
        recovery,
        framework,
        chain_id,
        &mainnet_genesis_config(),
        &OnChainConsensusConfig::default(),
        &OnChainExecutionConfig::default(),
        &default_gas_schedule(),
        supply_settings,
    );

    Ok(genesis)
}

/// Generates a genesis using the recovery file for hard forks.
pub fn encode_genesis_change_set(
    _core_resources_key: &Ed25519PublicKey,
    validators: &[Validator],
    recovery: Option<&[LegacyRecovery]>,
    framework: &ReleaseBundle,
    chain_id: ChainId,
    genesis_config: &GenesisConfiguration,
    consensus_config: &OnChainConsensusConfig,
    execution_config: &OnChainExecutionConfig,
    gas_schedule: &GasScheduleV2,
    supply_settings: &SupplySettings,
) -> ChangeSet {
    validate_genesis_config(genesis_config);

    // Create a Move VM session so we can invoke on-chain genesis intializations.
    let mut state_view = GenesisStateView::new();
    for (module_bytes, module) in framework.code_and_compiled_modules() {
        state_view.add_module(&module.self_id(), module_bytes);
    }
    let data_cache = state_view.as_move_resolver();
    let move_vm = MoveVmExt::new(
        NativeGasParameters::zeros(),
        AbstractValueSizeGasParameters::zeros(),
        LATEST_GAS_FEATURE_VERSION,
        ChainId::test().id(),
        Features::default(),
        TimedFeatures::enable_all(),
    )
    .unwrap();
    let id1 = HashValue::zero();
    let mut session = move_vm.new_session(&data_cache, SessionId::genesis(id1));
    // On-chain genesis process.
    initialize(
        &mut session,
        chain_id,
        genesis_config,
        consensus_config,
        execution_config,
        gas_schedule,
    );
    initialize_features(&mut session);

    initialize_aptos_coin(&mut session);

    initialize_on_chain_governance(&mut session, genesis_config);


    if let Some(r) = recovery {
        if r.len() > 0 {
          crate::genesis_functions::genesis_migrate_all_users(&mut session, r, supply_settings)
          .expect("could not migrate users");
        }
    }

    //////// 0L ////////
    // moved this to happen after legacy account migration, since the validators need to have their accounts migrated as well, including the mapping of legacy address to the authkey (which no longer derives to the previous same address).
    // Note: the operator accounts at genesis will be different.
    create_and_initialize_validators(&mut session, validators);


    set_genesis_end(&mut session);

    // Reconfiguration should happen after all on-chain invocations.
    emit_new_block_and_epoch_event(&mut session);

    let cs1 = session
        .finish(
            &mut (),
            &ChangeSetConfigs::unlimited_at_gas_feature_version(LATEST_GAS_FEATURE_VERSION),
        )
        .unwrap();

    let state_view = GenesisStateView::new();
    let data_cache = state_view.as_move_resolver();

    // Publish the framework, using a different session id, in case both scripts creates tables
    let mut id2_arr = [0u8; 32];
    id2_arr[31] = 1;
    let id2 = HashValue::new(id2_arr);
    let mut session = move_vm.new_session(&data_cache, SessionId::genesis(id2));
    publish_framework(&mut session, framework);
    let cs2 = session
        .finish(
            &mut (),
            &ChangeSetConfigs::unlimited_at_gas_feature_version(LATEST_GAS_FEATURE_VERSION),
        )
        .unwrap();

    let change_set_ext = cs1.squash(cs2).unwrap();

    let (delta_change_set, change_set) = change_set_ext.into_inner();

    // Publishing stdlib should not produce any deltas around aggregators and map to write ops and
    // not deltas. The second session only publishes the framework module bundle, which should not
    // produce deltas either.
    assert!(
        delta_change_set.is_empty(),
        "non-empty delta change set in genesis"
    );

    assert!(!change_set
        .write_set()
        .iter()
        .any(|(_, op)| op.is_deletion()));
    verify_genesis_write_set(change_set.events());
    change_set
}
