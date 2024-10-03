use crate::legacy_types::legacy_address_v5::LEGACY_CORE_CODE_ADDRESS;
use super::legacy_address_v5::LegacyAddressV5;
use anyhow::Result;
use move_core_types::language_storage::ModuleId;
use move_core_types::language_storage::RESOURCE_TAG;
use move_core_types::language_storage::TypeTag;
use move_core_types::identifier::Identifier;
use move_core_types::language_storage::StructTag;
use serde::{Deserialize, Serialize};
use move_core_types::ident_str;
#[derive(Serialize, Deserialize, Debug, PartialEq, Hash, Eq, Clone, PartialOrd, Ord)]
pub struct StructTagV5 {
    pub address: LegacyAddressV5,
    pub module: Identifier,
    pub name: Identifier,
    // TODO: rename to "type_args" (or better "ty_args"?)
    pub type_params: Vec<TypeTag>,
}

impl StructTagV5 {
    pub fn new(module: &str, name: &str, type_params: Option<Vec<TypeTag>>) -> Self {
      Self {
          address: LEGACY_CORE_CODE_ADDRESS,
          module: ident_str!("DiemAccount").into(),
          name: ident_str!("DiemAccount").into(),
          type_params: type_params.unwrap_or(vec![]),
      }
    }
    pub fn access_vector(&self) -> Vec<u8> {
        let mut key = vec![RESOURCE_TAG];
        key.append(&mut bcs::to_bytes(self).unwrap());
        key
    }

    pub fn convert_to_legacy(s: &StructTag) -> Result<StructTagV5> {
      let legacy_address = LegacyAddressV5::from_hex_literal(&s.address.to_hex_literal())?;

      Ok(StructTagV5 {
        address: legacy_address,
        module: s.module.clone(),
        name: s.name.clone(),
        type_params: s.type_params.clone(),
      })
    }

    // pub fn module_id(&self) -> ModuleId {
    //     ModuleId::new(self.address, self.module.to_owned())
    // }
}
