use move_core_types::{
    ident_str,
    identifier::IdentStr,
    move_resource::{MoveResource, MoveStructType},
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TxScheduleResource {
    scheduled: Vec<TimedTransferResource>,
    veto: Vec<TimedTransferResource>,
    paid: Vec<TimedTransferResource>,
    guid_capability: GUIDCapabilityResource, // we need this for the MultiSig
}

impl MoveStructType for TxScheduleResource {
    const MODULE_NAME: &'static IdentStr = ident_str!("donor_voice");
    const STRUCT_NAME: &'static IdentStr = ident_str!("TxSchedule");
}

impl MoveResource for TxScheduleResource {}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TimedTransferResource {
    uid: diem_api_types::U128, // copy of ID generated by MultiSig for the transaction
    deadline: diem_api_types::U64, // what epoch does the transaction execute
    tx: PaymentResource,               // The transaction properties
    epoch_latest_veto_received: u64, // This is to check if we need to extend the deadline
}

impl MoveStructType for TimedTransferResource {
    const MODULE_NAME: &'static IdentStr = ident_str!("donor_voice");
    const STRUCT_NAME: &'static IdentStr = ident_str!("TimedTransfer");
}

impl MoveResource for TimedTransferResource {}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PaymentResource {
    payee: diem_api_types::U128,
    value: diem_api_types::U64,
    description: Vec<u8>,
}

impl MoveStructType for PaymentResource {
    const MODULE_NAME: &'static IdentStr = ident_str!("donor_voice");
    const STRUCT_NAME: &'static IdentStr = ident_str!("Payment");
}

impl MoveResource for PaymentResource {}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GUIDCapabilityResource {
    addr: diem_api_types::U128,
}
impl MoveStructType for GUIDCapabilityResource {
    const MODULE_NAME: &'static IdentStr = ident_str!("account");
    const STRUCT_NAME: &'static IdentStr = ident_str!("GUIDCapability");
}

impl MoveResource for GUIDCapabilityResource {}
