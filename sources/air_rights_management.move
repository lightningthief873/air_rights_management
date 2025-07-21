module air_rights_management::air_rights_nft;

use iota::coin::{Self, Coin, TreasuryCap};
use iota::event;
use iota::iota::IOTA;
use iota::token::{Self, Token, TokenPolicy};
use std::string;

// =================== CLT Token Structures ===================

/// The OTW for the AIR_CREDITS Token / Coin.
public struct AIR_CREDITS has drop {}

/// This is the Rule requirement for the Air Rights Shop.
public struct AirRightsShop has drop {}

// =================== Original Structures ===================

public struct AirRightsNFT has key, store {
    id: UID,
    name: string::String,
    government_authority: address,
    corporation_owner: address,
    location_coordinates: string::String,
    area_coverage_sqm: u64,
    height_range_meters: string::String, // e.g., "100-500" for 100m to 500m
    rights_type: string::String, // e.g., "construction_prevention", "drone_access", "advertising"
    issue_date: u64,
    expiry_date: u64,
    royalty_percentage: u64,
    price: u64,
    whitelisted_corporations: vector<address>,
    is_transferable: bool,
}

public struct GovernmentCap has key {
    id: UID,
    authority_name: string::String,
}

public struct InitiateAirRightsResale has key, store {
    id: UID,
    air_rights_nft: AirRightsNFT,
    seller: address,
    buyer: address,
    price: u64,
}

public struct AirRightsRegistry has key, store {
    id: UID,
    available_air_rights: vector<AirRightsNFT>,
    total_zones: u64,
    registered_corporations: vector<address>,
}

// =================== Events ===================

public struct AirRightsPurchasedSuccessfully has copy, drop {
    location: string::String,
    area_coverage_sqm: u64,
    height_range: string::String,
    corporation_owner: address,
    expiry_date: u64,
    message: string::String,
}

public struct CorporationRegistered has copy, drop {
    corporation: address,
    registry_date: u64,
    message: string::String,
}

public struct AirCreditsRewarded has copy, drop {
    recipient: address,
    amount: u64,
    reason: string::String,
}

public struct AirCreditsPurchase has copy, drop {
    buyer: address,
    location: string::String,
    credits_spent: u64,
}

// =================== Error Codes ===================

#[error]
const NOT_ENOUGH_FUNDS: vector<u8> = b"Insufficient funds for air rights purchase";
#[error]
const INVALID_ROYALTY: vector<u8> = b"Royalty percentage must be between 0 and 100";
#[error]
const ALL_AIR_RIGHTS_SOLD: vector<u8> = b"All air rights in this zone have been sold";
#[error]
const NOT_AUTHORISED_CORPORATION: vector<u8> =
    b"Corporation is not whitelisted for this air rights purchase";
#[error]
const INVALID_AIR_RIGHTS_PURCHASE: vector<u8> = b"Unable to purchase air rights";
#[error]
const INVALID_ZONE_COUNT: vector<u8> = b"Zone count should be greater than zero";
#[error]
const AIR_RIGHTS_NOT_TRANSFERABLE: vector<u8> = b"These air rights cannot be transferred";
#[error]
const AIR_RIGHTS_EXPIRED: vector<u8> = b"Air rights have expired";
#[error]
const CORPORATION_NOT_REGISTERED: vector<u8> = b"Corporation must be registered first";
#[error]
const INSUFFICIENT_AIR_CREDITS: vector<u8> = b"Insufficient AIR_CREDITS for purchase";

// =================== Initialization ===================

fun init(ctx: &mut TxContext) {
    let sender = ctx.sender();
    transfer::transfer(
        GovernmentCap {
            id: object::new(ctx),
            authority_name: string::utf8(b"Municipal Air Rights Authority"),
        },
        sender,
    );

    transfer::share_object(AirRightsRegistry {
        id: object::new(ctx),
        available_air_rights: vector::empty<AirRightsNFT>(),
        total_zones: 1000, // Total air space zones available
        registered_corporations: vector::empty<address>(),
    })
}

/// Initialize the AIR_CREDITS CLT system
public fun init_air_credits_token(otw: AIR_CREDITS, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = coin::create_currency(
        otw,
        2, // 2 decimals for credits
        b"ACRED", // symbol
        b"Air Credits", // name
        b"Closed Loop Token for Air Rights Management", // description
        option::none(), // url
        ctx,
    );

    let (mut policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

    // Add rule for spending - only within AirRightsShop
    token::add_rule_for_action<AIR_CREDITS, AirRightsShop>(
        &mut policy,
        &policy_cap,
        token::spend_action(),
        ctx,
    );

    // Add rule for transfer - require treasury approval
    token::add_rule_for_action<AIR_CREDITS, AirRightsShop>(
        &mut policy,
        &policy_cap,
        token::transfer_action(),
        ctx,
    );

    transfer::public_share_object(treasury_cap);
    token::share_policy(policy);
    transfer::public_freeze_object(coin_metadata);
    transfer::public_transfer(policy_cap, tx_context::sender(ctx));
}

// =================== CLT Reward Functions ===================

/// Reward users with AIR_CREDITS for various actions
public(package) fun reward_air_credits(
    cap: &mut TreasuryCap<AIR_CREDITS>,
    amount: u64,
    recipient: address,
    reason: string::String,
    ctx: &mut TxContext,
) {
    let token = token::mint(cap, amount, ctx);
    let req = token::transfer(token, recipient, ctx);
    token::confirm_with_treasury_cap(cap, req, ctx);

    event::emit(AirCreditsRewarded {
        recipient,
        amount,
        reason,
    });
}

/// Government rewards corporations for compliance or early adoption
public fun reward_corporation_compliance(
    _: &GovernmentCap,
    cap: &mut TreasuryCap<AIR_CREDITS>,
    corporation: address,
    amount: u64,
    registry: &AirRightsRegistry,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&registry.registered_corporations, &corporation),
        CORPORATION_NOT_REGISTERED,
    );

    reward_air_credits(
        cap,
        amount,
        corporation,
        string::utf8(b"Compliance reward"),
        ctx,
    );
}

// =================== Original Air Rights Functions ===================

#[allow(lint(self_transfer))]
public fun mint_air_rights(
    _: &GovernmentCap,
    location_coordinates: string::String,
    area_coverage_sqm: u64,
    height_range_meters: string::String,
    rights_type: string::String,
    issue_date: u64,
    expiry_date: u64,
    royalty_percentage: u64,
    registry: &mut AirRightsRegistry,
    price: u64,
    is_transferable: bool,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(registry.total_zones > 0, ALL_AIR_RIGHTS_SOLD);
    assert!(royalty_percentage >= 0 && royalty_percentage <= 100, INVALID_ROYALTY);
    assert!(expiry_date > issue_date, AIR_RIGHTS_EXPIRED);

    let name: string::String = string::utf8(b"Air Rights NFT");
    let mut whitelisted_corporations = vector::empty<address>();

    let nft = AirRightsNFT {
        id: object::new(ctx),
        name,
        government_authority: sender,
        corporation_owner: sender, // Initially owned by government
        location_coordinates,
        area_coverage_sqm,
        height_range_meters,
        rights_type,
        issue_date,
        expiry_date,
        royalty_percentage,
        price,
        whitelisted_corporations,
        is_transferable,
    };

    set_total_zones(registry.total_zones - 1, registry);
    transfer::public_transfer(nft, sender);
}

public fun register_corporation(
    registry: &mut AirRightsRegistry,
    corporation: address,
    ctx: &mut TxContext,
) {
    if (!vector::contains(&registry.registered_corporations, &corporation)) {
        vector::push_back(&mut registry.registered_corporations, corporation);

        event::emit(CorporationRegistered {
            corporation,
            registry_date: tx_context::epoch_timestamp_ms(ctx),
            message: string::utf8(b"Corporation registered successfully"),
        });
    }
}

public fun enable_air_rights_for_sale(
    _: &GovernmentCap,
    nft: AirRightsNFT,
    registry: &mut AirRightsRegistry,
) {
    vector::push_back(&mut registry.available_air_rights, nft);
}

// =================== Enhanced Purchase Functions ===================

/// Purchase air rights with IOTA and earn AIR_CREDITS as rewards
#[allow(lint(self_transfer))]
public fun purchase_air_rights_with_iota(
    coin: &mut Coin<IOTA>,
    target_location: string::String,
    target_area: u64,
    registry: &mut AirRightsRegistry,
    air_credits_cap: &mut TreasuryCap<AIR_CREDITS>,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(
        vector::contains(&registry.registered_corporations, &sender),
        CORPORATION_NOT_REGISTERED,
    );

    let mut i = 0;
    let length = vector::length(&registry.available_air_rights);

    while (i < length) {
        let current_nft = vector::borrow(&registry.available_air_rights, i);
        if (
            current_nft.location_coordinates == target_location && 
            current_nft.area_coverage_sqm == target_area
        ) {
            let mut purchased_nft = vector::remove(&mut registry.available_air_rights, i);

            assert!(
                vector::contains(&purchased_nft.whitelisted_corporations, &sender),
                NOT_AUTHORISED_CORPORATION,
            );
            assert!(
                purchased_nft.expiry_date > tx_context::epoch_timestamp_ms(ctx),
                AIR_RIGHTS_EXPIRED,
            );

            let payment = coin.split(purchased_nft.price, ctx);
            transfer::public_transfer(payment, purchased_nft.government_authority);
            purchased_nft.corporation_owner = sender;

            // Reward with AIR_CREDITS (10% of purchase price as credits)
            let credit_reward = purchased_nft.price / 10;
            reward_air_credits(
                air_credits_cap,
                credit_reward,
                sender,
                string::utf8(b"Air rights purchase reward"),
                ctx,
            );

            event::emit(AirRightsPurchasedSuccessfully {
                location: purchased_nft.location_coordinates,
                area_coverage_sqm: purchased_nft.area_coverage_sqm,
                height_range: purchased_nft.height_range_meters,
                corporation_owner: purchased_nft.corporation_owner,
                expiry_date: purchased_nft.expiry_date,
                message: string::utf8(b"Air Rights NFT purchased successfully with IOTA"),
            });

            transfer::public_transfer(purchased_nft, sender);
            break
        };
        i = i + 1;
    };
    assert!(i < length, INVALID_AIR_RIGHTS_PURCHASE);
}

public fun purchase_air_rights_with_credits(
    payment: Token<AIR_CREDITS>,
    target_location: string::String,
    target_area: u64,
    registry: &mut AirRightsRegistry,
    air_credits_cap: &mut TreasuryCap<AIR_CREDITS>,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(
        vector::contains(&registry.registered_corporations, &sender),
        CORPORATION_NOT_REGISTERED,
    );

    let mut i = 0;
    let length = vector::length(&registry.available_air_rights);

    while (i < length) {
        let current_nft = vector::borrow(&registry.available_air_rights, i);
        if (
            current_nft.location_coordinates == target_location && 
            current_nft.area_coverage_sqm == target_area
        ) {
            let mut purchased_nft = vector::remove(&mut registry.available_air_rights, i);

            assert!(
                vector::contains(&purchased_nft.whitelisted_corporations, &sender),
                NOT_AUTHORISED_CORPORATION,
            );
            assert!(
                purchased_nft.expiry_date > tx_context::epoch_timestamp_ms(ctx),
                AIR_RIGHTS_EXPIRED,
            );

            let discounted_price = (purchased_nft.price * 80) / 100;
            let credits_amount = payment.value();
            assert!(credits_amount >= discounted_price, INSUFFICIENT_AIR_CREDITS);

            purchased_nft.corporation_owner = sender;

            event::emit(AirCreditsPurchase {
                buyer: sender,
                location: purchased_nft.location_coordinates,
                credits_spent: credits_amount,
            });

            event::emit(AirRightsPurchasedSuccessfully {
                location: purchased_nft.location_coordinates,
                area_coverage_sqm: purchased_nft.area_coverage_sqm,
                height_range: purchased_nft.height_range_meters,
                corporation_owner: purchased_nft.corporation_owner,
                expiry_date: purchased_nft.expiry_date,
                message: string::utf8(b"Air Rights NFT purchased successfully with AIR_CREDITS"),
            });

            // ✅ Properly consume the token
            token::burn(air_credits_cap, payment);
            transfer::public_transfer(purchased_nft, sender);
            return;
        };
        i = i + 1;
    };

    // 🔥 No match found, must consume the token anyway to avoid linear type error
    token::burn(air_credits_cap, payment);
    assert!(false, INVALID_AIR_RIGHTS_PURCHASE);
}

// =================== Original Functions (Maintained) ===================

public fun transfer_air_rights(
    mut nft: AirRightsNFT,
    recipient: address,
    registry: &AirRightsRegistry,
    ctx: &mut TxContext,
) {
    assert!(nft.is_transferable, AIR_RIGHTS_NOT_TRANSFERABLE);
    assert!(nft.expiry_date > tx_context::epoch_timestamp_ms(ctx), AIR_RIGHTS_EXPIRED);
    assert!(
        vector::contains(&registry.registered_corporations, &recipient),
        CORPORATION_NOT_REGISTERED,
    );

    nft.corporation_owner = recipient;
    transfer::public_transfer(nft, recipient);
}

#[allow(unused_variable)]
public fun initiate_air_rights_resale(
    mut nft: AirRightsNFT,
    updated_price: u64,
    buyer_corporation: address,
    registry: &AirRightsRegistry,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(nft.is_transferable, AIR_RIGHTS_NOT_TRANSFERABLE);
    assert!(nft.expiry_date > tx_context::epoch_timestamp_ms(ctx), AIR_RIGHTS_EXPIRED);
    assert!(
        vector::contains(&nft.whitelisted_corporations, &buyer_corporation),
        NOT_AUTHORISED_CORPORATION,
    );
    assert!(
        vector::contains(&registry.registered_corporations, &buyer_corporation),
        CORPORATION_NOT_REGISTERED,
    );

    nft.price = updated_price;

    let initiate_resale = InitiateAirRightsResale {
        id: object::new(ctx),
        seller: sender,
        buyer: buyer_corporation,
        price: updated_price,
        air_rights_nft: nft,
    };
    transfer::public_transfer(initiate_resale, buyer_corporation);
}

#[allow(lint(self_transfer))]
public fun complete_air_rights_resale(
    coin: &mut Coin<IOTA>,
    initiated_resale: InitiateAirRightsResale,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    let InitiateAirRightsResale {
        id: resale_id,
        seller: seller_address,
        buyer: _buyer_address,
        price: resale_price,
        air_rights_nft: mut nft,
    } = initiated_resale;

    assert!(nft.expiry_date > tx_context::epoch_timestamp_ms(ctx), AIR_RIGHTS_EXPIRED);

    let royalty_fee = (nft.price * nft.royalty_percentage) / 100;
    assert!(coin.balance().value() >= royalty_fee + resale_price, NOT_ENOUGH_FUNDS);

    // Pay royalty to government authority
    let royalty_payment = coin.split(royalty_fee, ctx);
    transfer::public_transfer(royalty_payment, nft.government_authority);

    // Pay seller
    let seller_payment = coin.split(resale_price, ctx);
    transfer::public_transfer(seller_payment, seller_address);

    // Transfer ownership
    nft.corporation_owner = sender;
    transfer::public_transfer(nft, sender);

    object::delete(resale_id);
}

#[allow(unused_variable)]
public fun revoke_air_rights(_: &GovernmentCap, nft: AirRightsNFT, ctx: &mut TxContext) {
    let AirRightsNFT {
        id,
        name,
        government_authority,
        corporation_owner,
        location_coordinates,
        area_coverage_sqm,
        height_range_meters,
        rights_type,
        issue_date,
        expiry_date,
        royalty_percentage,
        price,
        whitelisted_corporations,
        is_transferable,
    } = nft;
    object::delete(id);
}

fun set_total_zones(value: u64, registry: &mut AirRightsRegistry) {
    assert!(value >= 0, INVALID_ZONE_COUNT);
    registry.total_zones = value;
}

#[allow(unused_variable)]
public fun whitelist_corporation(
    corporation: address,
    nft: &mut AirRightsNFT,
    registry: &AirRightsRegistry,
) {
    assert!(
        vector::contains(&registry.registered_corporations, &corporation),
        CORPORATION_NOT_REGISTERED,
    );
    if (!vector::contains(&nft.whitelisted_corporations, &corporation)) {
        vector::push_back(&mut nft.whitelisted_corporations, corporation);
    }
}

public fun extend_air_rights_validity(
    _: &GovernmentCap,
    nft: &mut AirRightsNFT,
    new_expiry_date: u64,
    ctx: &mut TxContext,
) {
    assert!(new_expiry_date > tx_context::epoch_timestamp_ms(ctx), AIR_RIGHTS_EXPIRED);
    nft.expiry_date = new_expiry_date;
}

public fun update_air_rights_transferability(
    _: &GovernmentCap,
    nft: &mut AirRightsNFT,
    transferable: bool,
) {
    nft.is_transferable = transferable;
}

// =================== View Functions ===================

public fun get_air_rights_info(
    nft: &AirRightsNFT,
): (
    string::String, // location
    u64, // area_coverage
    string::String, // height_range
    string::String, // rights_type
    u64, // expiry_date
    address, // corporation_owner
    bool, // is_transferable
) {
    (
        nft.location_coordinates,
        nft.area_coverage_sqm,
        nft.height_range_meters,
        nft.rights_type,
        nft.expiry_date,
        nft.corporation_owner,
        nft.is_transferable,
    )
}

#[test_only]
public fun test_init(ctx: &mut TxContext) {
    init(ctx);
}
