#[test_only]
module air_rights_management::air_rights_nft_tests;

use air_rights_management::air_rights_nft::{
    Self,
    AirRightsNFT,
    GovernmentCap,
    AirRightsRegistry,
    AIR_CREDITS
};
use iota::coin::{Self, Coin, TreasuryCap};
use iota::iota::IOTA;
use iota::test_scenario::{Self as test, Scenario};
use iota::token::{Self, Token};
use std::string;

const GOVERNMENT: address = @0x1;
const CORPORATION_A: address = @0x2;
const CORPORATION_B: address = @0x3;

// Test helper to create test scenario
fun setup_test(): Scenario {
    let mut scenario = test::begin(GOVERNMENT);

    // Initialize the contract
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        air_rights_nft::test_init(test::ctx(&mut scenario));
    };

    scenario
}

#[test]
fun test_init_contract() {
    let mut scenario = test::begin(GOVERNMENT);

    test::next_tx(&mut scenario, GOVERNMENT);
    {
        air_rights_nft::test_init(test::ctx(&mut scenario));
    };

    // Check that GovernmentCap was created
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        assert!(test::has_most_recent_for_sender<GovernmentCap>(&scenario), 0);
        let registry = test::take_shared<AirRightsRegistry>(&scenario);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_register_corporation() {
    let mut scenario = setup_test();

    test::next_tx(&mut scenario, CORPORATION_A);
    {
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::register_corporation(
            &mut registry,
            CORPORATION_A,
            test::ctx(&mut scenario),
        );

        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_mint_air_rights() {
    let mut scenario = setup_test();

    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"), // NYC coordinates
            1000, // 1000 sqm
            string::utf8(b"100-500"), // 100-500 meters height
            string::utf8(b"construction_prevention"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025
            5, // 5% royalty
            &mut registry,
            1000000, // 1M IOTA price
            true, // transferable
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Check that NFT was created
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        assert!(test::has_most_recent_for_sender<AirRightsNFT>(&scenario), 0);
    };

    test::end(scenario);
}

#[test]
fun test_enable_air_rights_for_sale() {
    let mut scenario = setup_test();

    // First mint an NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"),
            1000,
            string::utf8(b"100-500"),
            string::utf8(b"construction_prevention"),
            1640995200000,
            1735689600000,
            5,
            &mut registry,
            1000000,
            true,
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Enable the NFT for sale
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);
        let nft = test::take_from_sender<AirRightsNFT>(&scenario);

        air_rights_nft::enable_air_rights_for_sale(
            &gov_cap,
            nft,
            &mut registry,
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_whitelist_corporation() {
    let mut scenario = setup_test();

    // Register corporation first
    test::next_tx(&mut scenario, CORPORATION_A);
    {
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::register_corporation(
            &mut registry,
            CORPORATION_A,
            test::ctx(&mut scenario),
        );

        test::return_shared(registry);
    };

    // Mint an NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"),
            1000,
            string::utf8(b"100-500"),
            string::utf8(b"construction_prevention"),
            1640995200000,
            1735689600000,
            5,
            &mut registry,
            1000000,
            true,
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Whitelist corporation for the NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let mut nft = test::take_from_sender<AirRightsNFT>(&scenario);
        let registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::whitelist_corporation(
            CORPORATION_A,
            &mut nft,
            &registry,
        );

        test::return_to_sender(&scenario, nft);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_get_air_rights_info() {
    let mut scenario = setup_test();

    // Mint an NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"),
            1000,
            string::utf8(b"100-500"),
            string::utf8(b"construction_prevention"),
            1640995200000,
            1735689600000,
            5,
            &mut registry,
            1000000,
            true,
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Test the view function
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let nft = test::take_from_sender<AirRightsNFT>(&scenario);

        let (
            location,
            area,
            height,
            rights_type,
            expiry,
            owner,
            transferable,
        ) = air_rights_nft::get_air_rights_info(&nft);

        assert!(location == string::utf8(b"40.7128,-74.0060"), 0);
        assert!(area == 1000, 1);
        assert!(height == string::utf8(b"100-500"), 2);
        assert!(rights_type == string::utf8(b"construction_prevention"), 3);
        assert!(expiry == 1735689600000, 4);
        assert!(owner == GOVERNMENT, 5);
        assert!(transferable == true, 6);

        test::return_to_sender(&scenario, nft);
    };

    test::end(scenario);
}

#[test]
fun test_extend_air_rights_validity() {
    let mut scenario = setup_test();

    // Mint an NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"),
            1000,
            string::utf8(b"100-500"),
            string::utf8(b"construction_prevention"),
            1640995200000,
            1735689600000, // Original expiry
            5,
            &mut registry,
            1000000,
            true,
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Extend validity
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut nft = test::take_from_sender<AirRightsNFT>(&scenario);

        air_rights_nft::extend_air_rights_validity(
            &gov_cap,
            &mut nft,
            1767225600000, // New expiry date (Jan 1, 2026)
            test::ctx(&mut scenario),
        );

        // Verify the expiry date was updated
        let (_, _, _, _, expiry, _, _) = air_rights_nft::get_air_rights_info(&nft);
        assert!(expiry == 1767225600000, 0);

        test::return_to_sender(&scenario, gov_cap);
        test::return_to_sender(&scenario, nft);
    };

    test::end(scenario);
}

#[test]
fun test_update_transferability() {
    let mut scenario = setup_test();

    // Mint an NFT
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut registry = test::take_shared<AirRightsRegistry>(&scenario);

        air_rights_nft::mint_air_rights(
            &gov_cap,
            string::utf8(b"40.7128,-74.0060"),
            1000,
            string::utf8(b"100-500"),
            string::utf8(b"construction_prevention"),
            1640995200000,
            1735689600000,
            5,
            &mut registry,
            1000000,
            true, // Initially transferable
            test::ctx(&mut scenario),
        );

        test::return_to_sender(&scenario, gov_cap);
        test::return_shared(registry);
    };

    // Update transferability to false
    test::next_tx(&mut scenario, GOVERNMENT);
    {
        let gov_cap = test::take_from_sender<GovernmentCap>(&scenario);
        let mut nft = test::take_from_sender<AirRightsNFT>(&scenario);

        air_rights_nft::update_air_rights_transferability(
            &gov_cap,
            &mut nft,
            false,
        );

        // Verify transferability was updated
        let (_, _, _, _, _, _, transferable) = air_rights_nft::get_air_rights_info(&nft);
        assert!(transferable == false, 0);

        test::return_to_sender(&scenario, gov_cap);
        test::return_to_sender(&scenario, nft);
    };

    test::end(scenario);
}
