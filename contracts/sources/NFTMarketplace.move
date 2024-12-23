// TODO                                                                     # 1: Define Module and Marketplace Address
address 0xed990159b07f1958216ec51360f9734f4d1f43522d97b3c66f1214699c107932{

module NFTMarketplace {
use 0x1::signer         ;
use 0x1::vector         ;
use 0x1::coin           ;
use 0x1::aptos_coin     ;
use 0x1::timestamp      ;

// TODO                                                   # 2: Define NFT Structure
struct NFT has store, key {
id: u64,
owner: address,
name: vector<u8>,
description: vector<u8>,
uri: vector<u8>,
price: u64,
for_sale: bool,
rarity: u8, // 1 for common, 2 for rare, 3 for epic, etc.
listing_date: u64,
creator: address,
    royalty_percentage: u64,
}
const DEFAULT_ROYALTY_PERCENTAGE: u64 = 5; // 5% royalty
const MAX_ROYALTY_PERCENTAGE: u64 = 15; // 15% maximum royalty

// TODO                      # 3: Define Marketplace Structure
struct Marketplace has key {
nfts: vector<NFT>
}

// TODO                           # 4: Define ListedNFT Structure
struct ListedNFT has copy, drop {
id: u64,
price: u64,
rarity: u8
}

// TODO                                # 5: Set Marketplace Fee
const MARKETPLACE_FEE_PERCENT: u64 = 2 ; // 2% fee

// TODO                                                  # 6: Initialize Marketplace
public entry fun initialize(account: &signer) {
if (!exists<Marketplace>(signer::address_of(account))) {
let marketplace = Marketplace {
nfts: vector::empty<NFT>()
}                                                        ;
move_to(account, marketplace)                            ;
}                                                        ;}

// TODO                                                                  # 7: Check Marketplace Initialization
#[view]
public fun is_marketplace_initialized(marketplace_addr: address): bool {
exists<Marketplace>(marketplace_addr)
}

// TODO                                                                                                                                    # 8: Mint New NFT
public entry fun mint_nft(
    account: &signer,
    name: vector<u8>,
    description: vector<u8>,
    uri: vector<u8>,
    rarity: u8,
    royalty_percentage: u64
) acquires Marketplace {
    assert!(royalty_percentage <= MAX_ROYALTY_PERCENTAGE, 103);
    
    let marketplace = borrow_global_mut<Marketplace>(signer::address_of(account));
    let nft_id = vector::length(&marketplace.nfts);
    let creator_address = signer::address_of(account);

    let new_nft = NFT {
        id: nft_id,
        owner: creator_address,
        creator: creator_address,
        name,
        description,
        uri,
        price: 0,
        for_sale: false,
        rarity,
        listing_date: 0,
        royalty_percentage,
    };

    vector::push_back(&mut marketplace.nfts, new_nft);
}

public entry fun purchase_nft_with_royalty(
    account: &signer,
    marketplace_addr: address,
    nft_id: u64,
    payment: u64,
    tip_amount: u64
) acquires Marketplace {
    let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
    let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

    assert!(nft_ref.for_sale, 400);
    assert!(payment >= nft_ref.price, 401);
    assert!(tip_amount >= 0, 402);

    // Calculate fees and royalties
    let marketplace_fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100;
    let royalty_amount = (nft_ref.price * nft_ref.royalty_percentage) / 100;
    let seller_revenue = payment - marketplace_fee - royalty_amount + tip_amount;

    // Transfer payments
    coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.owner, seller_revenue);
    coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, marketplace_fee);
    
    // Transfer royalties to creator if it's a secondary sale
    if (nft_ref.owner != nft_ref.creator) {
        coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.creator, royalty_amount)
    };

    // Transfer ownership
    nft_ref.owner = signer::address_of(account);
    nft_ref.for_sale = false;
    nft_ref.price = 0
}

#[view]
public fun get_nft_royalty_info(
    marketplace_addr: address,
    nft_id: u64
): (address, u64) acquires Marketplace {
    let marketplace = borrow_global<Marketplace>(marketplace_addr);
    let nft = vector::borrow(&marketplace.nfts, nft_id);
    (nft.creator, nft.royalty_percentage)
}


// TODO                                                                                                                                                           # 9: View NFT Details
#[view]
public fun get_nft_details(marketplace_addr: address, nft_id: u64): (u64, address, vector<u8>, vector<u8>, vector<u8>, u64, bool, u8, u64) acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                                                                                    ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                                                                                               ;

(nft.id, nft.owner, nft.name, nft.description, nft.uri, nft.price, nft.for_sale, nft.rarity, nft.listing_date)
}

// TODO                                                                                                                     # 10: List NFT for Sale
public entry fun list_for_sale(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
    let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
    let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

    assert!(nft_ref.owner == signer::address_of(account), 100);
    assert!(!nft_ref.for_sale, 101);
    assert!(price > 0, 102);

    nft_ref.for_sale = true;
    nft_ref.price = price;
    nft_ref.listing_date = timestamp::now_seconds();
}


// TODO                                                                                                                 # 11: Update NFT Price
public entry fun set_price(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr)                                                      ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)                                                         ;

assert!(nft_ref.owner == signer::address_of(account), 200) ; // Caller is not the owner
assert!(price > 0, 201)                                    ; // Invalid price

nft_ref.price = price ;
}

// TODO                                                                                                                      # 12: Purchase NFT
public entry fun purchase_nft(account: &signer, marketplace_addr: address, nft_id: u64, payment: u64) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr)                                                           ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)                                                              ;

assert!(nft_ref.for_sale, 400)         ; // NFT is not for sale
assert!(payment >= nft_ref.price, 401) ; // Insufficient payment

// Calculate marketplace fee
let fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100 ;
let seller_revenue = payment - fee                        ;

// Transfer payment to the seller and fee to the marketplace
coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, seller_revenue) ;
coin::transfer<aptos_coin::AptosCoin>(account, signer::address_of(account), fee) ;

// Transfer ownership
nft_ref.owner = signer::address_of(account) ;
nft_ref.for_sale = false                    ;
nft_ref.price = 0                           ;
}

// TODO                                                                                         # 13: Check if NFT is for Sale
#[view]
public fun is_nft_for_sale(marketplace_addr: address, nft_id: u64): bool acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                  ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                             ;
nft.for_sale
}

// TODO                                                                                      # 14: Get NFT Price
#[view]
public fun get_nft_price(marketplace_addr: address, nft_id: u64): u64 acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                               ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                          ;
nft.price
}

// TODO                                                                                                                                  # 15: Transfer Ownership
public entry fun transfer_ownership(account: &signer, marketplace_addr: address, nft_id: u64, new_owner: address) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr)                                                                       ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)                                                                          ;

assert!(nft_ref.owner == signer::address_of(account), 300) ; // Caller is not the owner
assert!(nft_ref.owner != new_owner, 301)                   ; // Prevent transfer to the same owner

// Update NFT ownership and reset its for_sale status and price
nft_ref.owner = new_owner                                       ;
nft_ref.for_sale = false                                        ;
nft_ref.price = 0                                               ;
}

// TODO                                                                                      # 16: Retrieve NFT Owner
#[view]
public fun get_owner(marketplace_addr: address, nft_id: u64): address acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                               ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                          ;
nft.owner
}

// TODO                                                                                                                                        # 17: Retrieve NFTs for Sale
#[view]
public fun get_all_nfts_for_owner(marketplace_addr: address, owner_addr: address, limit: u64, offset: u64): vector<u64> acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                                                                 ;
let nft_ids = vector::empty<u64>()                                                                                                             ;

let nfts_len = vector::length(&marketplace.nfts)   ;
let end = min(offset + limit, nfts_len)            ;
let mut_i = offset                                 ;
while (mut_i < end) {
let nft = vector::borrow(&marketplace.nfts, mut_i) ;
if (nft.owner == owner_addr) {
vector::push_back(&mut nft_ids, nft.id)            ;
}                                                  ;
mut_i = mut_i + 1                                  ;
}                                                  ;

nft_ids
}

// TODO                                                                                                                        # 18: Retrieve NFTs for Sale
#[view]
public fun get_all_nfts_for_sale(marketplace_addr: address, limit: u64, offset: u64): vector<ListedNFT> acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                                                 ;
let nfts_for_sale = vector::empty<ListedNFT>()                                                                                 ;

let nfts_len = vector::length(&marketplace.nfts)                                ;
let end = min(offset + limit, nfts_len)                                         ;
let mut_i = offset                                                              ;
while (mut_i < end) {
let nft = vector::borrow(&marketplace.nfts, mut_i)                              ;
if (nft.for_sale) {
let listed_nft = ListedNFT { id: nft.id, price: nft.price, rarity: nft.rarity } ;
vector::push_back(&mut nfts_for_sale, listed_nft)                               ;
}                                                                               ;
mut_i = mut_i + 1                                                               ;
}                                                                               ;

nfts_for_sale
}

// TODO                                                   # 19: Define Helper Function for Minimum Value
// Helper function to find the minimum of two u64 numbers
public fun min(a: u64, b: u64): u64 {
if (a < b) { a } else { b }
}

// TODO                                                                                                  # 20: Retrieve NFTs by Rarity
// New function to retrieve NFTs by rarity
#[view]
public fun get_nfts_by_rarity(marketplace_addr: address, rarity: u8): vector<u64> acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                           ;
let nft_ids = vector::empty<u64>()                                                                       ;

let nfts_len = vector::length(&marketplace.nfts)   ;
let mut_i = 0                                      ;
while (mut_i < nfts_len) {
let nft = vector::borrow(&marketplace.nfts, mut_i) ;
if (nft.rarity == rarity) {
vector::push_back(&mut nft_ids, nft.id)            ;
}                                                  ;
mut_i = mut_i + 1                                  ;
}                                                  ;

nft_ids
}

struct Auction has store {
nft_id: u64,
seller: address,
start_price: u64,
current_price: u64,
highest_bidder: address,
start_time: u64,
end_time: u64,
active: bool
}

struct AuctionStore has key {
auctions: vector<Auction>,
auction_count: u64
}

// Add these constants at the top with other constants
const MINIMUM_AUCTION_DURATION: u64 = 60               ;
const MINIMUM_BID_INCREMENT: u64 = 100                 ; // Minimum bid increment in APT

// Add these error codes at the top
const ENOT_AUCTION_OWNER: u64 = 1000      ;
const EAUCTION_ALREADY_EXISTS: u64 = 1001 ;
const EAUCTION_NOT_ACTIVE: u64 = 1002     ;
const EBID_TOO_LOW: u64 = 1003            ;
const EAUCTION_ENDED: u64 = 1004          ;
const EAUCTION_NOT_ENDED: u64 = 1005      ;

// Initialize auction store
public entry fun initialize_auction_store(account: &signer) {
let auction_store = AuctionStore {
auctions: vector::empty<Auction>(),
auction_count: 0
}                                                             ;
move_to(account, auction_store)                               ;
}

// Create new auction
public entry fun create_auction(
account: &signer,
marketplace_addr: address,
nft_id: u64,
start_price: u64,
duration: u64
) acquires AuctionStore, Marketplace {
let seller = signer::address_of(account) ;

// Verify NFT ownership
assert!(get_owner(marketplace_addr, nft_id) == seller, ENOT_AUCTION_OWNER) ;

// Verify minimum duration
assert!(duration >= MINIMUM_AUCTION_DURATION, 1006) ;

let auction_store = borrow_global_mut<AuctionStore>(marketplace_addr) ;

// Create new auction
let auction = Auction {
nft_id,
seller,
start_price,
current_price: start_price,
highest_bidder: seller, // Initially set to seller
start_time: timestamp::now_seconds(),
end_time: timestamp::now_seconds() + duration,
active: true
}                                                  ;

vector::push_back(&mut auction_store.auctions, auction)       ;
auction_store.auction_count = auction_store.auction_count + 1 ;
}

// Place bid
public entry fun place_bid(
account: &signer,
marketplace_addr: address,
auction_id: u64,
bid_amount: u64
) acquires AuctionStore {
let bidder = signer::address_of(account)                                  ;
let auction_store = borrow_global_mut<AuctionStore>(marketplace_addr)     ;
let auction = vector::borrow_mut(&mut auction_store.auctions, auction_id) ;

// Verify auction is active
assert!(auction.active, EAUCTION_NOT_ACTIVE)                          ;
assert!(timestamp::now_seconds() <= auction.end_time, EAUCTION_ENDED) ;

// Verify bid amount
assert!(bid_amount > auction.current_price, EBID_TOO_LOW)                          ;
assert!(bid_amount >= auction.current_price + MINIMUM_BID_INCREMENT, EBID_TOO_LOW) ;

// Return funds to previous highest bidder if exists
if (auction.highest_bidder != auction.seller) {
coin::transfer<aptos_coin::AptosCoin>(
account,
auction.highest_bidder,
auction.current_price
)                                                    ;
}                                                    ;

// Update auction state
auction.highest_bidder = bidder    ;
auction.current_price = bid_amount ;

// Transfer bid amount to contract
coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, bid_amount) ;
}

// End auction
public entry fun end_auction(
account: &signer,
marketplace_addr: address,
auction_id: u64
) acquires AuctionStore, Marketplace {
let auction_store = borrow_global_mut<AuctionStore>(marketplace_addr)     ;
let auction = vector::borrow_mut(&mut auction_store.auctions, auction_id) ;

// Verify auction can be ended
assert!(timestamp::now_seconds() >= auction.end_time, EAUCTION_NOT_ENDED) ;
assert!(auction.active, EAUCTION_NOT_ACTIVE)                              ;

// Calculate fees
let fee = (auction.current_price * MARKETPLACE_FEE_PERCENT) / 100 ;
let seller_revenue = auction.current_price - fee                  ;

if (auction.highest_bidder != auction.seller) {
// Transfer NFT to winner
transfer_ownership(
account,
marketplace_addr,
auction.nft_id,
auction.highest_bidder
)                                               ;

// Transfer funds to seller
coin::transfer<aptos_coin::AptosCoin>(
account,
auction.seller,
seller_revenue
)                                      ;

// Transfer fee to marketplace
coin::transfer<aptos_coin::AptosCoin>(
account,
marketplace_addr,
fee
)                                      ;
}                                      ;

auction.active = false ;
}

// View functions
#[view]
public fun get_auction_details(
marketplace_addr: address,
auction_id: u64
): (u64, address, u64, u64, address, u64, u64, bool) acquires AuctionStore {
let auction_store = borrow_global<AuctionStore>(marketplace_addr)            ;
let auction = vector::borrow(&auction_store.auctions, auction_id)            ;

(
auction.nft_id,
auction.seller,
auction.start_price,
auction.current_price,
auction.highest_bidder,
auction.start_time,
auction.end_time,
auction.active
)
}

#[view]
public fun get_active_auctions(
marketplace_addr: address
): vector<u64> acquires AuctionStore {
let auction_store = borrow_global<AuctionStore>(marketplace_addr) ;
let active_auctions = vector::empty<u64>()                        ;
let i = 0                                                         ;

while (i < auction_store.auction_count) {
let auction = vector::borrow(&auction_store.auctions, i)              ;
if (auction.active && timestamp::now_seconds() <= auction.end_time) {
vector::push_back(&mut active_auctions, i)                            ;
}                                                                     ;
i = i + 1                                                             ;
}                                                                     ;

active_auctions
}
public entry fun transfer_nft(
account: &signer,
marketplace_addr: address,
nft_id: u64,
recipient: address
) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr) ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)    ;

// Verify ownership and valid recipient
assert!(nft_ref.owner == signer::address_of(account), 500) ; // Not the owner
assert!(recipient != @0x0, 501)                            ; // Invalid recipient address
assert!(nft_ref.owner != recipient, 502)                   ; // Cannot transfer to self
assert!(!nft_ref.for_sale, 503)                            ; // Cannot transfer listed NFT

// Update ownership
nft_ref.owner = recipient ;
nft_ref.for_sale = false  ;
nft_ref.price = 0         ;
}

// Batch transfer function
public entry fun batch_transfer_nfts(
account: &signer,
marketplace_addr: address,
nft_ids: vector<u64>,
recipient: address
) acquires Marketplace {
let i = 0                             ;
let len = vector::length(&nft_ids)    ;

while (i < len) {
let nft_id = *vector::borrow(&nft_ids, i)                  ;
transfer_nft(account, marketplace_addr, nft_id, recipient) ;
i = i + 1                                                  ;
}
}

// View function to get transfer history
#[view]
public fun get_nft_transfers(
marketplace_addr: address,
nft_id: u64
): vector<address> acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr) ;
let nft = vector::borrow(&marketplace.nfts, nft_id)            ;

// Return the current owner
let transfers = vector::empty<address>()     ;
vector::push_back(&mut transfers, nft.owner) ;
transfers
}

// Verify if address can receive NFTs
#[view]
public fun can_receive_nfts(addr: address): bool {
addr != @0x0
}

// Get all NFTs owned by an address
#[view]
public fun get_owned_nfts(
marketplace_addr: address,
owner_addr: address
): vector<u64> acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr) ;
let owned_nfts = vector::empty<u64>()                          ;
let i = 0                                                      ;
let len = vector::length(&marketplace.nfts)                    ;

while (i < len) {
let nft = vector::borrow(&marketplace.nfts, i) ;
if (nft.owner == owner_addr) {
vector::push_back(&mut owned_nfts, nft.id)     ;
}                                              ;
i = i + 1                                      ;
}                                              ;

owned_nfts
}

public entry fun clear_marketplace(account: &signer) acquires Marketplace {
let marketplace_addr = signer::address_of(account)                          ;
assert!(exists<Marketplace>(marketplace_addr), 600)                         ;

// Get the old marketplace
let old_marketplace = move_from<Marketplace>(marketplace_addr) ;
let Marketplace { nfts } = old_marketplace                     ;

// Create new empty marketplace
let new_marketplace = Marketplace {
nfts: vector::empty<NFT>()
}                                   ;

// Move the new empty marketplace to the account
move_to(account, new_marketplace)                ;

// Return the old NFTs vector to properly clean up resources
move_to(account, Marketplace { nfts })                       ;
}




public entry fun purchase_nft_with_tip(
    account: &signer,
    marketplace_addr: address,
    nft_id: u64,
    payment: u64,
    tip_amount: u64
) acquires Marketplace {
    let marketplace = borrow_global_mut<Marketplace>(marketplace_addr);
    let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id);

    assert!(nft_ref.for_sale, 400); // NFT is not for sale
    assert!(payment >= nft_ref.price, 401); // Insufficient payment
    assert!(tip_amount >= 0, 402); // Invalid tip amount

    // Calculate marketplace fee
    let fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100;
    let seller_revenue = payment - fee + tip_amount;

    // Transfer payment to the seller and fee to the marketplace
    coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.owner, seller_revenue);
    coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, fee);

    // Transfer ownership
    nft_ref.owner = signer::address_of(account);
    nft_ref.for_sale = false;
    nft_ref.price = 0;
}

}
}
