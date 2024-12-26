
address 0x3ed23f75dc96ed785388d48d31252e98e3b031fb3cdca6175f0a9c75d4489521{

module NFTMarketplace {
use 0x1::signer         ;
use 0x1::vector         ;
use 0x1::coin           ;
use 0x1::aptos_coin     ;
use 0x1::timestamp      ;

//  Define NFT Structure
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
const DEFAULT_ROYALTY_PERCENTAGE: u64 = 5                 ; // 5% royalty
const MAX_ROYALTY_PERCENTAGE: u64 = 15                    ; // 15% maximum royalty

//  Define Marketplace Structure
struct Marketplace has key {
nfts: vector<NFT>
}

//  Define ListedNFT Structure
struct ListedNFT has copy, drop {
id: u64,
price: u64,
rarity: u8
}

// Set Marketplace Fee
const MARKETPLACE_FEE_PERCENT: u64 = 2 ; // 2% fee

//  Initialize Marketplace
public entry fun initialize(account: &signer) {
if (!exists<Marketplace>(signer::address_of(account))) {
let marketplace = Marketplace {
nfts: vector::empty<NFT>()
}                                                        ;
move_to(account, marketplace)                            ;
}                                                        ;}

// Check Marketplace Initialization
#[view]
public fun is_marketplace_initialized(marketplace_addr: address): bool {
exists<Marketplace>(marketplace_addr)
}

// # 8: Mint New NFT
public entry fun mint_nft(
account: &signer,
name: vector<u8>,
description: vector<u8>,
uri: vector<u8>,
rarity: u8,
royalty_percentage: u64
) acquires Marketplace {
assert!(royalty_percentage <= MAX_ROYALTY_PERCENTAGE, 103) ;

let marketplace = borrow_global_mut<Marketplace>(signer::address_of(account)) ;
let nft_id = vector::length(&marketplace.nfts)                                ;
let creator_address = signer::address_of(account)                             ;

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
}                         ;

vector::push_back(&mut marketplace.nfts, new_nft) ;
}

public entry fun purchase_nft_with_royalty(
account: &signer,
marketplace_addr: address,
nft_id: u64,
payment: u64,
tip_amount: u64
) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr) ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)    ;

assert!(nft_ref.for_sale, 400)         ;
assert!(payment >= nft_ref.price, 401) ;
assert!(tip_amount >= 0, 402)          ;

// Calculate fees and royalties
let marketplace_fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100        ;
let royalty_amount = (nft_ref.price * nft_ref.royalty_percentage) / 100      ;
let seller_revenue = payment - marketplace_fee - royalty_amount + tip_amount ;

// Transfer payments
coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.owner, seller_revenue)     ;
coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, marketplace_fee) ;

// Transfer royalties to creator if it's a secondary sale
if (nft_ref.owner != nft_ref.creator) {
coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.creator, royalty_amount)
}                                                                               ;

// Transfer ownership
nft_ref.owner = signer::address_of(account) ;
nft_ref.for_sale = false                    ;
nft_ref.price = 0
}

#[view]
public fun get_nft_royalty_info(
marketplace_addr: address,
nft_id: u64
): (address, u64) acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr) ;
let nft = vector::borrow(&marketplace.nfts, nft_id)            ;
(nft.creator, nft.royalty_percentage)
}

//  View NFT Details
#[view]
public fun get_nft_details(marketplace_addr: address, nft_id: u64): (u64, address, vector<u8>, vector<u8>, vector<u8>, u64, bool, u8, u64) acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                                                                                    ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                                                                                               ;

(nft.id, nft.owner, nft.name, nft.description, nft.uri, nft.price, nft.for_sale, nft.rarity, nft.listing_date)
}

//  List NFT for Sale
public entry fun list_for_sale(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr)                                                          ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)                                                             ;

assert!(nft_ref.owner == signer::address_of(account), 100) ;
assert!(!nft_ref.for_sale, 101)                            ;
assert!(price > 0, 102)                                    ;

nft_ref.for_sale = true                         ;
nft_ref.price = price                           ;
nft_ref.listing_date = timestamp::now_seconds() ;
}

//  Update NFT Price
public entry fun set_price(account: &signer, marketplace_addr: address, nft_id: u64, price: u64) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr)                                                      ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)                                                         ;

assert!(nft_ref.owner == signer::address_of(account), 200) ; // Caller is not the owner
assert!(price > 0, 201)                                    ; // Invalid price

nft_ref.price = price ;
}

// Purchase NFT
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

//  Check if NFT is for Sale
#[view]
public fun is_nft_for_sale(marketplace_addr: address, nft_id: u64): bool acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                                  ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                             ;
nft.for_sale
}

//  Get NFT Price
#[view]
public fun get_nft_price(marketplace_addr: address, nft_id: u64): u64 acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                               ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                          ;
nft.price
}

// Transfer Ownership
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

//  Retrieve NFT Owner
#[view]
public fun get_owner(marketplace_addr: address, nft_id: u64): address acquires Marketplace {
let marketplace = borrow_global<Marketplace>(marketplace_addr)                               ;
let nft = vector::borrow(&marketplace.nfts, nft_id)                                          ;
nft.owner
}

// Retrieve NFTs for Sale
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

//  Retrieve NFTs for Sale
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

//  Define Helper Function for Minimum Value
// Helper function to find the minimum of two u64 numbers
public fun min(a: u64, b: u64): u64 {
if (a < b) { a } else { b }
}

//  Retrieve NFTs by Rarity
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

//Auction System
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
const MINIMUM_AUCTION_DURATION: u64 = 60               ;
const MINIMUM_BID_INCREMENT: u64 = 100                 ; 

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



//purchase the nft with Tip 
public entry fun purchase_nft_with_tip(
account: &signer,
marketplace_addr: address,
nft_id: u64,
payment: u64,
tip_amount: u64
) acquires Marketplace {
let marketplace = borrow_global_mut<Marketplace>(marketplace_addr) ;
let nft_ref = vector::borrow_mut(&mut marketplace.nfts, nft_id)    ;

assert!(nft_ref.for_sale, 400)         ; 
assert!(payment >= nft_ref.price, 401) ;
assert!(tip_amount >= 0, 402)          ; 

let fee = (nft_ref.price * MARKETPLACE_FEE_PERCENT) / 100 ;
let seller_revenue = payment - fee + tip_amount           ;

coin::transfer<aptos_coin::AptosCoin>(account, nft_ref.owner, seller_revenue) ;
coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, fee)         ;

// Transfer ownership
nft_ref.owner = signer::address_of(account) ;
nft_ref.for_sale = false                    ;
nft_ref.price = 0                           ;
}


//Offer System
struct Offer has store {
buyer: address,
nft_id: u64,
amount: u64,
timestamp: u64,
status: u8 , // 0: pending, 1: accepted, 2: declined
index: u64 }

struct OfferStore has key {
offers: vector<Offer>,
offer_count: u64
}
const EOFFER_ALREADY_EXISTS: u64 = 2000 ;
const EOFFER_NOT_FOUND: u64 = 2001      ;
const EOFFER_INVALID_AMOUNT: u64 = 2002 ;
const EOFFER_INVALID_STATUS: u64 = 2003 ;
const EOFFER_NOT_OWNER: u64 = 2004      ;
const EOFFER_SELF_OFFER: u64 = 2005     ;

// Initialize offer store
public entry fun initialize_offer_store(account: &signer) {
if (!exists<OfferStore>(signer::address_of(account))) {
let offer_store = OfferStore {
offers: vector::empty<Offer>(),
offer_count: 0
}                                                           ;
move_to(account, offer_store)                               ;
}
}

// Make an offer for an NFT
public entry fun make_offer(
account: &signer,
marketplace_addr: address,
nft_id: u64,
offer_amount: u64
) acquires OfferStore, Marketplace {
let buyer = signer::address_of(account) ;

// Get marketplace and NFT info
let marketplace = borrow_global<Marketplace>(marketplace_addr) ;
let nft = vector::borrow(&marketplace.nfts, nft_id)            ;

// Validations
assert!(nft.owner != buyer, EOFFER_SELF_OFFER)   ;
assert!(offer_amount > 0, EOFFER_INVALID_AMOUNT) ;

// Ensure offer store exists
assert!(exists<OfferStore>(marketplace_addr), 1) ;

let offer_store = borrow_global_mut<OfferStore>(marketplace_addr) ;

// Transfer the offer amount to the marketplace contract
coin::transfer<aptos_coin::AptosCoin>(
account,
marketplace_addr,
offer_amount
)                                                        ;

// Create new offer
let offer = Offer {
buyer,
nft_id,
amount: offer_amount,
timestamp: timestamp::now_seconds(),
status: 0, // pending
index: offer_store.offer_count}      ;

vector::push_back(&mut offer_store.offers, offer)     ;
offer_store.offer_count = offer_store.offer_count + 1 ;
}

// Accept an offer
public entry fun accept_offer(
account: &signer,
marketplace_addr: address,
offer_index: u64
) acquires OfferStore, Marketplace {
let seller = signer::address_of(account)                             ;
let offer_store = borrow_global_mut<OfferStore>(marketplace_addr)    ;
let offer = vector::borrow_mut(&mut offer_store.offers, offer_index) ;

let marketplace = borrow_global_mut<Marketplace>(marketplace_addr) ;
let nft = vector::borrow_mut(&mut marketplace.nfts, offer.nft_id)  ;

// Validations
assert!(nft.owner == seller, EOFFER_NOT_OWNER)    ;
assert!(offer.status == 0, EOFFER_INVALID_STATUS) ;

// Calculate fees
let marketplace_fee = (offer.amount * MARKETPLACE_FEE_PERCENT) / 100 ;
let seller_revenue = offer.amount - marketplace_fee                  ;

// Transfer payment
coin::transfer<aptos_coin::AptosCoin>(account, seller, seller_revenue)            ;
coin::transfer<aptos_coin::AptosCoin>(account, marketplace_addr, marketplace_fee) ;

// Transfer NFT ownership
nft.owner = offer.buyer   ;
nft.for_sale = false      ;
nft.price = 0             ;

// Update offer status
offer.status = 1       ;
}

// Decline an offer
public entry fun decline_offer(
account: &signer,
marketplace_addr: address,
offer_index: u64
) acquires OfferStore, Marketplace {
let seller = signer::address_of(account)                             ;
let offer_store = borrow_global_mut<OfferStore>(marketplace_addr)    ;
let offer = vector::borrow_mut(&mut offer_store.offers, offer_index) ;

let marketplace = borrow_global<Marketplace>(marketplace_addr) ;
let nft = vector::borrow(&marketplace.nfts, offer.nft_id)      ;

// Validations
assert!(nft.owner == seller, EOFFER_NOT_OWNER)    ;
assert!(offer.status == 0, EOFFER_INVALID_STATUS) ;

// Update offer status
offer.status = 2       ;
}

// View functions for offers
#[view]
public fun get_offer_details(
marketplace_addr: address,
offer_index: u64
): (address, u64, u64, u64, u8) acquires OfferStore {
let offer_store = borrow_global<OfferStore>(marketplace_addr) ;
let offer = vector::borrow(&offer_store.offers, offer_index)  ;

(offer.buyer, offer.nft_id, offer.amount, offer.timestamp, offer.status)
}

#[view]
public fun get_offers_for_nft(
marketplace_addr: address,
nft_id: u64
): vector<u64> acquires OfferStore {
let offer_store = borrow_global<OfferStore>(marketplace_addr) ;
let offer_indices = vector::empty<u64>()                      ;
let i = 0                                                     ;

while (i < offer_store.offer_count) {
let offer = vector::borrow(&offer_store.offers, i) ;
if (offer.nft_id == nft_id && offer.status == 0) {
vector::push_back(&mut offer_indices, i)           ;
}                                                  ;
i = i + 1                                          ;
}                                                  ;

offer_indices
}




//Transfer APT System
public entry fun transfer_apt(
    account: &signer,
    recipient: address,
    amount: u64
) {
    // Validate amount and recipient
    assert!(amount > 0, 700);                
    assert!(recipient != @0x0, 701);         
    assert!(recipient != signer::address_of(account), 702);
    coin::transfer<aptos_coin::AptosCoin>(
        account,
        recipient,
        amount
    );
}

// Batch transfer APT to multiple recipients
public entry fun batch_transfer_apt(
    account: &signer,
    recipients: vector<address>,
    amounts: vector<u64>
) {
    let recipients_len = vector::length(&recipients);
    let amounts_len = vector::length(&amounts);
    
    // Validate input vectors have same length
    assert!(recipients_len == amounts_len, 703);
    
    let i = 0;
    while (i < recipients_len) {
        let recipient = *vector::borrow(&recipients, i);
        let amount = *vector::borrow(&amounts, i);
        
        transfer_apt(account, recipient, amount);
        i = i + 1;
    }
}

// View function to check APT balance
#[view]
public fun get_apt_balance(addr: address): u64 {
    coin::balance<aptos_coin::AptosCoin>(addr)
}







}
}