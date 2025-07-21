#[test_only]
module air_rights_management::air_rights_nft_test {
    use std::string;
    use iota::coin;
    use iota::iota::IOTA;
    use iota::test_scenario::{Self, Scenario};
    use air_rights_management::air_rights_nft::{
        GovernmentCap,
        AirRightsRegistry,
        AirRightsNFT,
        InitiateAirRightsResale,
        mint_air_rights,
        initiate_air_rights_resale,
        revoke_air_rights,
        transfer_air_rights,
        test_init,
        register_corporation,
        whitelist_corporation,
        enable_air_rights_for_sale,
        purchase_air_rights,
        complete_air_rights_resale,
        extend_air_rights_validity,
        update_air_rights_transferability,
        get_air_rights_info
    };

    const GOVERNMENT: address = @0xAAAA;
    const CORPORATION_A: address = @0xAAAD;
    const CORPORATION_B: address = @0xAAAF;

    #[test]
    fun test_mint_air_rights() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"40.7128,-74.0060"), // NYC coordinates
            10000, // 10,000 sqm
            string::utf8(b"100-500"), // 100-500 meters height
            string::utf8(b"construction_prevention"),
            1640995200000, // Jan 1, 2022
            1704067200000, // Jan 1, 2024
            5, // 5% royalty
            &mut registry,
            1000000, // 1M IOTA
            true, // transferable
            test.ctx()
        );

        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_corporation_registration() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());
        
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_B, test.ctx());

        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_air_rights_resale() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);

        // Register corporations
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());
        register_corporation(&mut registry, CORPORATION_B, test.ctx());

        // Mint air rights
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"40.7589,-73.9851"), // Times Square coordinates
            5000, // 5,000 sqm
            string::utf8(b"200-800"), // 200-800 meters height
            string::utf8(b"drone_access"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            10, // 10% royalty
            &mut registry,
            2000000, // 2M IOTA
            true, // transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        // Whitelist corporations
        test_scenario::next_tx(test, GOVERNMENT);
        whitelist_corporation(CORPORATION_A, &mut air_rights, &registry);
        whitelist_corporation(CORPORATION_B, &mut air_rights, &registry);
        
        // Transfer to Corporation A
        test_scenario::next_tx(test, GOVERNMENT);
        transfer_air_rights(air_rights, CORPORATION_A, &registry, test.ctx());
        
        test_scenario::next_tx(test, CORPORATION_A);
        let mut air_rights_corp_a = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        // Corporation A initiates resale to Corporation B
        test_scenario::next_tx(test, CORPORATION_A);
        initiate_air_rights_resale(
            air_rights_corp_a,
            3000000, // 3M IOTA
            CORPORATION_B,
            &registry,
            test.ctx()
        );
        
        test_scenario::next_tx(test, CORPORATION_B);
        let initiated_resale = test_scenario::take_from_sender<InitiateAirRightsResale>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::next_tx(test, CORPORATION_B);
        test_scenario::return_to_sender(test, initiated_resale);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = iota::test_scenario::EEmptyInventory)]
    fun test_revoke_air_rights() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"34.0522,-118.2437"), // LA coordinates
            8000, // 8,000 sqm
            string::utf8(b"50-300"), // 50-300 meters height
            string::utf8(b"advertising"),
            1640995200000, // Jan 1, 2022
            1704067200000, // Jan 1, 2024
            3, // 3% royalty
            &mut registry,
            500000, // 500K IOTA
            false, // not transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        revoke_air_rights(&government_cap, air_rights, test.ctx());
        
        // This should fail as the NFT has been revoked/deleted
        test_scenario::next_tx(test, GOVERNMENT);
        let revoked_air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender(test, revoked_air_rights);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_transfer_air_rights() {  
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        // Register corporation
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"41.8781,-87.6298"), // Chicago coordinates
            12000, // 12,000 sqm
            string::utf8(b"300-1000"), // 300-1000 meters height
            string::utf8(b"construction_prevention"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            7, // 7% royalty
            &mut registry,
            1500000, // 1.5M IOTA
            true, // transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        transfer_air_rights(air_rights, CORPORATION_A, &registry, test.ctx());
        
        test_scenario::next_tx(test, CORPORATION_A);
        let transferred_air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::next_tx(test, CORPORATION_A);
        test_scenario::return_to_sender(test, transferred_air_rights);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = iota::test_scenario::EEmptyInventory)]
    fun test_enable_air_rights_for_sale() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"29.7604,-95.3698"), // Houston coordinates
            6000, // 6,000 sqm
            string::utf8(b"150-600"), // 150-600 meters height
            string::utf8(b"drone_access"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            4, // 4% royalty
            &mut registry,
            800000, // 800K IOTA
            true, // transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        enable_air_rights_for_sale(&government_cap, air_rights, &mut registry);
        
        // This should fail as the NFT is now in the registry, not with sender
        test_scenario::next_tx(test, CORPORATION_A);
        let air_rights_from_sender = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender(test, air_rights_from_sender);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_purchase_air_rights() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);

        // Register corporation
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());

        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"25.7617,-80.1918"), // Miami coordinates
            4000, // 4,000 sqm
            string::utf8(b"75-400"), // 75-400 meters height
            string::utf8(b"advertising"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            6, // 6% royalty
            &mut registry,
            1200000, // 1.2M IOTA
            true, // transferable
            test.ctx()
        );

        test_scenario::next_tx(test, GOVERNMENT);
        let mut air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        whitelist_corporation(CORPORATION_A, &mut air_rights, &registry);
        test_scenario::next_tx(test, GOVERNMENT);

        enable_air_rights_for_sale(&government_cap, air_rights, &mut registry);
        test_scenario::next_tx(test, CORPORATION_A);
        
        let mut coin_for_purchase = coin::mint_for_testing<IOTA>(2000000, test_scenario::ctx(test));
        test_scenario::next_tx(test, CORPORATION_A);
        purchase_air_rights(
            &mut coin_for_purchase,
            string::utf8(b"25.7617,-80.1918"), // Miami coordinates
            4000, // 4,000 sqm
            &mut registry,
            test_scenario::ctx(test)
        );
        test_scenario::next_tx(test, CORPORATION_A);
        let purchased_air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);

        coin_for_purchase.burn_for_testing();
        test_scenario::next_tx(test, GOVERNMENT);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::next_tx(test, CORPORATION_A);
        test_scenario::return_to_sender(test, purchased_air_rights);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_complete_air_rights_resale() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);

        // Register corporations
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());
        register_corporation(&mut registry, CORPORATION_B, test.ctx());

        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"37.7749,-122.4194"), // SF coordinates
            7000, // 7,000 sqm
            string::utf8(b"250-750"), // 250-750 meters height
            string::utf8(b"construction_prevention"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            8, // 8% royalty
            &mut registry,
            1800000, // 1.8M IOTA
            true, // transferable
            test.ctx()
        );

        test_scenario::next_tx(test, GOVERNMENT);
        let mut air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);

        // Whitelist both corporations
        test_scenario::next_tx(test, GOVERNMENT);
        whitelist_corporation(CORPORATION_A, &mut air_rights, &registry);
        whitelist_corporation(CORPORATION_B, &mut air_rights, &registry);

        test_scenario::next_tx(test, GOVERNMENT);
        transfer_air_rights(air_rights, CORPORATION_A, &registry, test.ctx());

        test_scenario::next_tx(test, CORPORATION_A);
        let air_rights_corp_a = test_scenario::take_from_sender<AirRightsNFT>(test);

        test_scenario::next_tx(test, CORPORATION_A);
        initiate_air_rights_resale(
            air_rights_corp_a,
            2500000, // 2.5M IOTA
            CORPORATION_B,
            &registry,
            test.ctx()
        );

        test_scenario::next_tx(test, CORPORATION_B);
        let initiated_resale = test_scenario::take_from_sender<InitiateAirRightsResale>(test);

        let mut coin_for_resale = coin::mint_for_testing<IOTA>(3000000, test_scenario::ctx(test));

        test_scenario::next_tx(test, CORPORATION_B);
        complete_air_rights_resale(&mut coin_for_resale, initiated_resale, test_scenario::ctx(test));

        coin_for_resale.burn_for_testing();
        test_scenario::next_tx(test, GOVERNMENT);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_whitelist_corporation() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        // Register corporation first
        test_scenario::next_tx(test, GOVERNMENT);
        register_corporation(&mut registry, CORPORATION_A, test.ctx());
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"39.9526,-75.1652"), // Philadelphia coordinates
            9000, // 9,000 sqm
            string::utf8(b"120-500"), // 120-500 meters height
            string::utf8(b"drone_access"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            5, // 5% royalty
            &mut registry,
            1100000, // 1.1M IOTA
            true, // transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        whitelist_corporation(CORPORATION_A, &mut air_rights, &registry);
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender(test, air_rights);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_extend_air_rights_validity() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"42.3601,-71.0589"), // Boston coordinates
            5500, // 5,500 sqm
            string::utf8(b"180-650"), // 180-650 meters height
            string::utf8(b"advertising"),
            1640995200000, // Jan 1, 2022
            1704067200000, // Jan 1, 2024 (shorter validity)
            4, // 4% royalty
            &mut registry,
            900000, // 900K IOTA
            false, // not transferable initially
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        // Extend validity to 2026
        test_scenario::next_tx(test, GOVERNMENT);
        extend_air_rights_validity(
            &government_cap,
            &mut air_rights,
            1767139200000, // Jan 1, 2026
            test.ctx()
        );
        
        // Make it transferable
        test_scenario::next_tx(test, GOVERNMENT);
        update_air_rights_transferability(&government_cap, &mut air_rights, true);
        
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender(test, air_rights);

        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_air_rights_info() {
        let mut scenario = test_scenario::begin(GOVERNMENT);
        let test = &mut scenario;
        initialize(test, GOVERNMENT);

        test_scenario::next_tx(test, GOVERNMENT);
        let government_cap = test_scenario::take_from_sender<GovernmentCap>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        let mut registry = test_scenario::take_shared<AirRightsRegistry>(test);
        
        test_scenario::next_tx(test, GOVERNMENT);
        mint_air_rights(
            &government_cap,
            string::utf8(b"47.6062,-122.3321"), // Seattle coordinates
            8500, // 8,500 sqm
            string::utf8(b"200-900"), // 200-900 meters height
            string::utf8(b"construction_prevention"),
            1640995200000, // Jan 1, 2022
            1735689600000, // Jan 1, 2025 (future date)
            6, // 6% royalty
            &mut registry,
            2200000, // 2.2M IOTA
            true, // transferable
            test.ctx()
        );
        
        test_scenario::next_tx(test, GOVERNMENT);
        let air_rights = test_scenario::take_from_sender<AirRightsNFT>(test);
        
        // Test the view function
        test_scenario::next_tx(test, GOVERNMENT);
        let (location, area, height_range, rights_type, expiry, owner, transferable) = 
            get_air_rights_info(&air_rights);
        
        // Verify the information matches what we set
        assert!(location == string::utf8(b"47.6062,-122.3321"), 0);
        assert!(area == 8500, 1);
        assert!(height_range == string::utf8(b"200-900"), 2);
        assert!(rights_type == string::utf8(b"construction_prevention"), 3);
        assert!(expiry == 1735689600000, 4);
        assert!(owner == GOVERNMENT, 5);
        assert!(transferable == true, 6);
        
        test_scenario::return_to_sender<GovernmentCap>(test, government_cap);
        test_scenario::return_shared<AirRightsRegistry>(registry);
        test_scenario::return_to_sender(test, air_rights);

        test_scenario::end(scenario);
    }

    fun initialize(scenario: &mut Scenario, government: address) {
        test_scenario::next_tx(scenario, government);
        {
            test_init(test_scenario::ctx(scenario));
        };
    }
}