use libra_types::legacy_types::{legacy_recovery::{self, LegacyRecovery}, legacy_address::LegacyAddress};
use std::path::PathBuf;
/// Make a recovery genesis blob
pub fn recovery_file_parse(recovery_json_path: PathBuf) -> anyhow::Result<Vec<LegacyRecovery>> {
    let mut r = legacy_recovery::read_from_recovery_file(
        &recovery_json_path,
    );

    fix_slow_wallet(&mut r)?;

    Ok(r)
}

fn fix_slow_wallet(r: &mut [LegacyRecovery]) -> anyhow::Result<Vec<LegacyAddress>> {
  let mut errs = vec![];
  r.iter_mut().for_each(|e| {
    if e.account.is_some() && e.balance.is_some(){
      if let Some(s) = e.slow_wallet.as_mut() {
        let balance = e.balance.as_ref().unwrap().coin;

        if s.unlocked > balance {
          s.unlocked = balance;
          errs.push(e.account.as_ref().unwrap().to_owned())
        }
      }
    }
  });

  Ok(errs)
}

#[test]
fn parse_json_single() {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/sample_end_user_single.json");

    let r = recovery_file_parse(p).unwrap();
    if let Some(acc) = r[0].account {
        assert!(&acc.to_string() == "6BBF853AA6521DB445E5CBDF3C85E8A0");
    }

    let _has_root = r
        .iter()
        .find(|el| el.comm_wallet.is_some())
        .expect("could not find 0x0 state in recovery file");
}


#[test]
fn parse_json_all() {
    let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/sample_export_recovery.json");

    let mut r = recovery_file_parse(p).unwrap();

    let _has_root = r
        .iter()
        .find(|el| el.comm_wallet.is_some())
        .expect("could not find 0x0 state in recovery file");

  let res = fix_slow_wallet(&mut r).unwrap();

  assert!(res.len() == 0);
}
