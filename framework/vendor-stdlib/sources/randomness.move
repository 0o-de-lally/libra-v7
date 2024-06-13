// Copyright Aptos Labs
// Original Source:
https://github.com/aptos-labs/aptos-core/commit/8d6485a6a0505f0d22c764a814552d808bc42f8a

/// This module provides access to *instant* secure randomness generated by the Aptos validators, as documented in
/// [AIP-41](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-41.md).
///
/// Secure randomness means (1) the randomness cannot be predicted ahead of time by validators, developers or users
/// and (2) the randomness cannot be biased in any way by validators, developers or users.
///
/// Security holds under the same proof-of-stake assumption that secures the
// Aptos network.

// OL NOTE: This source has been modified to be backward compatible with 0L V7.
// Principal changes:
// - No Apis are public
// - as such, no checks for unbiasable are needed
// - per block seed is provided directly from block prologue
// - the tx counter nonce has been removed since it requires a native function
// - events have been removed


module diem_framework::randomness {
    use std::hash;
    use std::option;
    use std::option::Option;
    use std::vector;
    // use diem_framework::event;
    use diem_framework::system_addresses;
    // use diem_framework::transaction_context;
    #[test_only]
    use diem_std::debug;
    #[test_only]
    use diem_std::table_with_length;

    friend diem_framework::block;

    const DST: vector<u8> = b"ALL_YOUR_BASE";


    const MAX_U256: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    /// 32-byte randomness seed unique to every block.
    /// This resource is updated in every block prologue.
    struct PerBlockRandomness has drop, key {
        epoch: u64,
        round: u64,
        seed: Option<vector<u8>>,
    }

    // 0L NOTE: we will be skipping sending events on every randomness
    // generation. Seems like a significant bloat to the DB, an is unrelated to
    // the security model.

    // #[event]
    // /// Event emitted every time a public randomness API in this module is called.
    // struct RandomnessGeneratedEvent has store, drop {
    // }

    /// Called in genesis.move.
    /// Must be called in tests to initialize the `PerBlockRandomness` resource.
    public fun initialize(framework: &signer) {
        system_addresses::assert_diem_framework(framework);
        if (!exists<PerBlockRandomness>(@diem_framework)) {
            move_to(framework, PerBlockRandomness {
                epoch: 0,
                round: 0,
                seed: option::none(),
            });
        }
    }

    #[test_only]
    public fun initialize_for_testing(framework: &signer) acquires  PerBlockRandomness {
        initialize(framework);
        set_seed(x"0000000000000000000000000000000000000000000000000000000000000000");
    }

    /// Invoked in block prologues to update the block-level randomness seed.
    public(friend) fun on_new_block(vm: &signer, epoch: u64, round: u64, seed_for_new_block: Option<vector<u8>>) acquires PerBlockRandomness {
        system_addresses::assert_vm(vm);
        if (exists<PerBlockRandomness>(@diem_framework)) {
            let randomness = borrow_global_mut<PerBlockRandomness>(@diem_framework);
            randomness.epoch = epoch;
            randomness.round = round;
            randomness.seed = seed_for_new_block;
        }
    }

    /// Generate the next 32 random bytes. Repeated calls will yield different results (assuming the collision-resistance
    /// of the hash function).
    fun next_32_bytes(): vector<u8> acquires PerBlockRandomness {
        // assert!(is_unbiasable(), E_API_USE_IS_BIASIBLE);

        let input = DST;
        let randomness = borrow_global<PerBlockRandomness>(@diem_framework);
        let seed = *option::borrow(&randomness.seed);

        vector::append(&mut input, seed);
        // 0L NOTE: these native APIs dont exist in 0L V7.
        // instead the transaction hash will be forced with the seed above,
        // which will always be called by the block prologue.
        // We will drop the unbiased checks, because this is not going to be an
        // public facing API.
        // The increment txn_counter native which creates a nonce, will be
        // ignored. Though could later be added back. Unclear if there's any
        // added safety versus the nonce being on chain as a malicious validator
        // could see this counter.

        // vector::append(&mut input, transaction_context::get_transaction_hash());
        // vector::append(&mut input, fetch_and_increment_txn_counter());
        hash::sha3_256(input)
    }

    /// Generates a sequence of bytes uniformly at random
    fun bytes(n: u64): vector<u8> acquires PerBlockRandomness {
        let v = vector[];
        let c = 0;
        while (c < n) {
            let blob = next_32_bytes();
            vector::append(&mut v, blob);

            c = c + 32;
        };

        if (c > n) {
            vector::trim(&mut v, n);
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        v
    }

    /// Generates an u8 uniformly at random.
    fun u8_integer(): u8 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let ret: u8 = vector::pop_back(&mut raw);

        // event::emit_event(RandomnessGeneratedEvent {});

        ret
    }

    /// Generates an u16 uniformly at random.
    fun u16_integer(): u16 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let i = 0;
        let ret: u16 = 0;
        while (i < 2) {
            ret = ret * 256 + (vector::pop_back(&mut raw) as u16);
            i = i + 1;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        ret
    }

    /// Generates an u32 uniformly at random.
    fun u32_integer(): u32 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let i = 0;
        let ret: u32 = 0;
        while (i < 4) {
            ret = ret * 256 + (vector::pop_back(&mut raw) as u32);
            i = i + 1;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        ret
    }

    /// Generates an u64 uniformly at random.
    fun u64_integer(): u64 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let i = 0;
        let ret: u64 = 0;
        while (i < 8) {
            ret = ret * 256 + (vector::pop_back(&mut raw) as u64);
            i = i + 1;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        ret
    }

    /// Generates an u128 uniformly at random.
    fun u128_integer(): u128 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let i = 0;
        let ret: u128 = 0;
        while (i < 16) {
            ret = ret * 256 + (vector::pop_back(&mut raw) as u128);
            i = i + 1;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        ret
    }

    /// Generates a u256 uniformly at random.
    fun u256_integer(): u256 acquires PerBlockRandomness {
        // event::emit_event(RandomnessGeneratedEvent {});
        u256_integer_internal()
    }

    /// Generates a u256 uniformly at random.
    fun u256_integer_internal(): u256 acquires PerBlockRandomness {
        let raw = next_32_bytes();
        let i = 0;
        let ret: u256 = 0;
        while (i < 32) {
            ret = ret * 256 + (vector::pop_back(&mut raw) as u256);
            i = i + 1;
        };
        ret
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own via rejection sampling.
    fun u8_range(min_incl: u8, max_excl: u8): u8 acquires PerBlockRandomness {
        let range = ((max_excl - min_incl) as u256);
        let sample = ((u256_integer_internal() % range) as u8);

        // event::emit_event(RandomnessGeneratedEvent {});

        min_incl + sample
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own via rejection sampling.
    fun u16_range(min_incl: u16, max_excl: u16): u16 acquires PerBlockRandomness {
        let range = ((max_excl - min_incl) as u256);
        let sample = ((u256_integer_internal() % range) as u16);

        // event::emit_event(RandomnessGeneratedEvent {});

        min_incl + sample
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own via rejection sampling.
    fun u32_range(min_incl: u32, max_excl: u32): u32 acquires PerBlockRandomness {
        let range = ((max_excl - min_incl) as u256);
        let sample = ((u256_integer_internal() % range) as u32);

        // event::emit_event(RandomnessGeneratedEvent {});

        min_incl + sample
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own via rejection sampling.
   fun u64_range(min_incl: u64, max_excl: u64): u64 acquires PerBlockRandomness {
        // event::emit_event(RandomnessGeneratedEvent {});

        u64_range_internal(min_incl, max_excl)
    }

    fun u64_range_internal(min_incl: u64, max_excl: u64): u64 acquires PerBlockRandomness {
        let range = ((max_excl - min_incl) as u256);
        let sample = ((u256_integer_internal() % range) as u64);

        min_incl + sample
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own via rejection sampling.
    fun u128_range(min_incl: u128, max_excl: u128): u128 acquires PerBlockRandomness {
        let range = ((max_excl - min_incl) as u256);
        let sample = ((u256_integer_internal() % range) as u128);

        // event::emit_event(RandomnessGeneratedEvent {});

        min_incl + sample
    }

    /// Generates a number $n \in [min_incl, max_excl)$ uniformly at random.
    ///
    /// NOTE: The uniformity is not perfect, but it can be proved that the bias is negligible.
    /// If you need perfect uniformity, consider implement your own with `u256_integer()` + rejection sampling.
    fun u256_range(min_incl: u256, max_excl: u256): u256 acquires PerBlockRandomness {
        let range = max_excl - min_incl;
        let r0 = u256_integer_internal();
        let r1 = u256_integer_internal();

        // Will compute sample := (r0 + r1*2^256) % range.

        let sample = r1 % range;
        let i = 0;
        while ({
            spec {
                invariant sample >= 0 && sample < max_excl - min_incl;
            };
            i < 256
        }) {
            sample = safe_add_mod(sample, sample, range);
            i = i + 1;
        };

        let sample = safe_add_mod(sample, r0 % range, range);
        spec {
            assert sample >= 0 && sample < max_excl - min_incl;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        min_incl + sample
    }

    /// Generate a permutation of `[0, 1, ..., n-1]` uniformly at random.
    /// If n is 0, returns the empty vector.
    fun permutation(n: u64): vector<u64> acquires PerBlockRandomness {
        let values = vector[];

        if(n == 0) {
            return vector[]
        };

        // Initialize into [0, 1, ..., n-1].
        let i = 0;
        while ({
            spec {
                invariant i <= n;
                invariant len(values) == i;
            };
            i < n
        }) {
            std::vector::push_back(&mut values, i);
            i = i + 1;
        };
        spec {
            assert len(values) == n;
        };

        // Shuffle.
        let tail = n - 1;
        while ({
            spec {
                invariant tail >= 0 && tail < len(values);
            };
            tail > 0
        }) {
            let pop_position = u64_range_internal(0, tail + 1);
            spec {
                assert pop_position < len(values);
            };
            std::vector::swap(&mut values, pop_position, tail);
            tail = tail - 1;
        };

        // event::emit_event(RandomnessGeneratedEvent {});

        values
    }

    #[test_only]
    public fun set_seed(seed: vector<u8>) acquires PerBlockRandomness {
        assert!(vector::length(&seed) == 32, 0);
        let randomness = borrow_global_mut<PerBlockRandomness>(@diem_framework);
        randomness.seed = option::some(seed);
    }

    /// Compute `(a + b) % m`, assuming `m >= 1, 0 <= a < m, 0<= b < m`.
    inline fun safe_add_mod(a: u256, b: u256, m: u256): u256 {
        let neg_b = m - b;
        if (a < neg_b) {
            a + b
        } else {
            a - neg_b
        }
    }

    #[verify_only]
    fun safe_add_mod_for_verification(a: u256, b: u256, m: u256): u256 {
        let neg_b = m - b;
        if (a < neg_b) {
            a + b
        } else {
            a - neg_b
        }
    }

    // /// Fetches and increments a transaction-specific 32-byte randomness-related counter.
    // /// Aborts with `E_API_USE_SUSCEPTIBLE_TO_TEST_AND_ABORT` if randomness is not unbiasable.
    // native fun fetch_and_increment_txn_counter(): vector<u8>;

    // /// Called in each randomness generation function to ensure certain safety invariants, namely:
    // ///  1. The transaction that led to the call of this function had a private (or friend) entry
    // ///     function as its payload.
    // ///  2. The entry function had `#[randomness]` annotation.
    // native fun is_unbiasable(): bool;

    #[test]
    fun test_safe_add_mod() {
        assert!(2 == safe_add_mod(3, 4, 5), 1);
        assert!(2 == safe_add_mod(4, 3, 5), 1);
        assert!(7 == safe_add_mod(3, 4, 9), 1);
        assert!(7 == safe_add_mod(4, 3, 9), 1);
        assert!(0xfffffffffffffffffffffffffffffffffffffffffffffffe == safe_add_mod(0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0x000000000000000000000000000000000000000000000001, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0xfffffffffffffffffffffffffffffffffffffffffffffffe == safe_add_mod(0x000000000000000000000000000000000000000000000001, 0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0x000000000000000000000000000000000000000000000000 == safe_add_mod(0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0x000000000000000000000000000000000000000000000002, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0x000000000000000000000000000000000000000000000000 == safe_add_mod(0x000000000000000000000000000000000000000000000002, 0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0x000000000000000000000000000000000000000000000001 == safe_add_mod(0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0x000000000000000000000000000000000000000000000003, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0x000000000000000000000000000000000000000000000001 == safe_add_mod(0x000000000000000000000000000000000000000000000003, 0xfffffffffffffffffffffffffffffffffffffffffffffffd, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
        assert!(0xfffffffffffffffffffffffffffffffffffffffffffffffd == safe_add_mod(0xfffffffffffffffffffffffffffffffffffffffffffffffe, 0xfffffffffffffffffffffffffffffffffffffffffffffffe, 0xffffffffffffffffffffffffffffffffffffffffffffffff), 1);
    }

    #[test(fx = @diem_framework)]
    fun randomness_smoke_test(fx: signer) acquires PerBlockRandomness {
        initialize(&fx);
        set_seed(x"0000000000000000000000000000000000000000000000000000000000000000");
        // Test cases should always have no bias for any randomness call.
        // assert!(is_unbiasable(), 0);
        let num = u64_integer();
        debug::print(&num);
    }

    // #[test_only]
    // fun assert_event_count_equals(count: u64) {
    //     let events = event::emitted_events<RandomnessGeneratedEvent>();
    //     assert!(vector::length(&events) == count, 0);
    // }

    // #[test(fx = @diem_framework)]
    // fun test_emit_events(fx: signer) acquires PerBlockRandomness {
    //     initialize_for_testing(&fx);

    //     let c = 0;
    //     assert_event_count_equals(c);

    //     let _ = bytes(1);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u8_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u16_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u32_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u64_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u128_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u256_integer();
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u8_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u16_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u32_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u64_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u128_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = u256_range(0, 255);
    //     c = c + 1;
    //     assert_event_count_equals(c);

    //     let _ = permutation(6);
    //     c = c + 1;
    //     assert_event_count_equals(c);
    // }

    #[test(fx = @diem_framework)]
    fun test_bytes(fx: signer) acquires PerBlockRandomness {
        initialize_for_testing(&fx);

        let v = bytes(0);
        assert!(vector::length(&v) == 0, 0);

        let v = bytes(1);
        assert!(vector::length(&v) == 1, 0);
        let v = bytes(2);
        assert!(vector::length(&v) == 2, 0);
        let v = bytes(3);
        assert!(vector::length(&v) == 3, 0);
        let v = bytes(4);
        assert!(vector::length(&v) == 4, 0);
        let v = bytes(30);
        assert!(vector::length(&v) == 30, 0);
        let v = bytes(31);
        assert!(vector::length(&v) == 31, 0);
        let v = bytes(32);
        assert!(vector::length(&v) == 32, 0);

        let v = bytes(33);
        assert!(vector::length(&v) == 33, 0);
        let v = bytes(50);
        assert!(vector::length(&v) == 50, 0);
        let v = bytes(63);
        assert!(vector::length(&v) == 63, 0);
        let v = bytes(64);
        assert!(vector::length(&v) == 64, 0);
    }

    #[test_only]
    fun is_permutation(v: &vector<u64>): bool {
        let present = vector[];

        // Mark all elements from 0 to n-1 as not present
        let n = vector::length(v);
        let i = 0;
        while (i < n) {
            vector::push_back(&mut present, false);
            i = i + 1;
        };
        // for (i in 0..n) {
        //     vector::push_back(&mut present, false);
        // };

        let i = 0;
        while (i < n) {
            let e = vector::borrow(v, i);
            let bit = vector::borrow_mut(&mut present, *e);
            *bit = true;
            i = i + 1;
        };
        // for (i in 0..n) {
        //     let e = vector::borrow(v, i);
        //     let bit = vector::borrow_mut(&mut present, *e);
        //     *bit = true;
        // };

        let i = 0;
        while (i < n) {
            let bit = vector::borrow(&present, i);
            if(*bit == false) {
                return false
            };
            i = i + 1;
        };

        // for (i in 0..n) {
        //     let bit = vector::borrow(&present, i);
        //     if(*bit == false) {
        //         return false
        //     };
        // };

        true
    }

    #[test(fx = @diem_framework)]
    fun test_permutation(fx: signer) acquires PerBlockRandomness {
        initialize_for_testing(&fx);

        let v = permutation(0);
        assert!(vector::length(&v) == 0, 0);

        test_permutation_internal(1);
        test_permutation_internal(2);
        test_permutation_internal(3);
        test_permutation_internal(4);
    }

    #[test_only]
    /// WARNING: Do not call this with a large `size`, since execution time will be \Omega(size!), where ! is the factorial
    /// operator.
    fun test_permutation_internal(size: u64) acquires PerBlockRandomness {
        let num_permutations = 1;
        let c = 1;
        let i = 0;
        while (i < size) {
            num_permutations = num_permutations * c;
            c = c + 1;
            i = i + 1;
        };

        let permutations = table_with_length::new<vector<u64>, bool>();

        // This loop will not exit until all permutations are created
        while(table_with_length::length(&permutations) < num_permutations) {
            let v = permutation(size);
            assert!(vector::length(&v) == size, 0);
            assert!(is_permutation(&v), 0);

            if(table_with_length::contains(&permutations, v) == false) {
                table_with_length::add(&mut permutations, v, true);
            }
        };

        table_with_length::drop_unchecked(permutations);
    }
}
