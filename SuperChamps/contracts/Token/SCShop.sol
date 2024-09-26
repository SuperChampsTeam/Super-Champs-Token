// SPDX-License-Identifier: None
// Super Champs Foundation 2024

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../../interfaces/IPermissionsManager.sol";
import "../Utils/SCPermissionedAccess.sol";

/// @title Shop Sales Manager
/// @author Chance Santana-Wees (Coelacanth/Coel.eth)
/// @notice Used by the Super Champs Shop system to transfer tokens from user accounts. 
/// @dev Allows the transfer of tokens from user accounts before token unlock.
contract SCShop is SCPermissionedAccess {

    uint256 internal _tx_nonce;
    bool internal _tx_group;
    
    ///@notice Input data for transfers of ERC20 tokens from one account to another.
    ///@dev Purpose is to emit a saleReceipt event and to allow transfer of tokens from user wallets by the Shop system before token unlock.
    ///@param origin_ Address that is sending tokens.
    ///@param recipient_ Address that is receiving the tokens.
    ///@param tokens_ [List] The token to transfer. (This contract must already have approval to transfer tokens from origin_)
    ///@param amounts_ [List] The quantity of tokens sent.
    ///@param subsystem_ The string ID of the Shop subsystem calling this function.
    ///@param metadata_ An optional string parameter that may be populated with arbitrary metadata.
    struct TokenTxData {
        address origin_;
        address recipient_;
        IERC20[] tokens_;
        uint256[] amounts_; 
        string subsystem_; 
        string metadata_;
    }

    ///@notice Input data for transfers of ERC721 tokens from one account to another.
    ///@dev Purpose is to emit a saleReceipt event and to allow transfer of tokens from user wallets by the Shop system before token unlock.
    ///@param origin_ Address that is sending tokens.
    ///@param recipient_ Address that is receiving the tokens.
    ///@param nfts_ [List] The collection to transfer. (This contract must already have approval to transfer tokens from origin_)
    ///@param token_ids_ [List] The ID of the token to send.
    ///@param transfer_metadatas_ [List] An optional bytes parameter that is fed to the onERC721Received(...) call, post transfer.
    ///@param subsystem_ The string ID of the Shop subsystem calling this function.
    ///@param metadata_ An optional string parameter that may be populated with arbitrary metadata.
    struct NFTTxData {
        address origin_;
        address recipient_;
        IERC721[] nfts_;
        uint256[] token_ids_;
        bytes[] transfer_metadatas_;
        string subsystem_; 
        string metadata_;
    }

    ///@notice Input data for transfers of ERC1155 tokens from one account to another.
    ///@dev Purpose is to emit a saleReceipt event and to allow transfer of tokens from user wallets by the Shop system before token unlock.
    ///@param origin_ Address that is sending tokens.
    ///@param recipient_ Address that is receiving the tokens.
    ///@param nfts_ [List] The collection to transfer. (This contract must already have approval to transfer tokens from origin_)
    ///@param token_ids_ [List] The ID of the token to send.
    ///@param amounts_ [List] The quantity of tokens to be sent.
    ///@param transfer_metadatas_ [List] An optional bytes parameter that is fed to the onERC721Received(...) call, post transfer.
    ///@param subsystem_ The string ID of the Shop subsystem calling this function.
    ///@param metadata_ An optional string parameter that may be populated with arbitrary metadata.
    struct SFTTxData {
        address origin_;
        address recipient_;
        IERC1155[] sfts_;
        uint256[] token_ids_;
        uint256[] amounts_;
        bytes[] transfer_metadatas_;
        string subsystem_;
        string metadata_;
    }

    ///@notice Emitted when a call to saleTransaction(...) completes.
    event saleReceipt(
        address origin,
        address recipient,
        IERC20[] tokens,
        uint256[] amounts, 
        string subsystem, 
        string metadata,
        uint256 tx_nonce,
        bool tx_group
    );
    
    ///@notice Emitted when a call to nftTransaction(...) completes.
    event nftReceipt(
        address origin,
        address recipient,
        IERC721[] nfts,
        uint256[] token_ids,
        bytes[] transfer_metadatas,
        string subsystem, 
        string metadata,
        uint256 tx_nonce,
        bool tx_group
    );

    ///@notice Emitted when a call to sftTransaction(...) completes.
    event sftReceipt(
        address origin,
        address recipient,
        IERC1155[] sfts,
        uint256[] token_ids,
        uint256[] amounts,
        bytes[] transfer_metadatas,
        string subsystem, 
        string metadata,
        uint256 tx_nonce,
        bool tx_group
    );

    modifier groupTX {
        _tx_group = true;
        _;
        _tx_group = false;
    }

    ///@param permissions_ Address of the protocol permissions registry. Must conform to IPermissionsManager.
    constructor(address permissions_) SCPermissionedAccess(permissions_) { }

    ///@notice Transfers tokens from one account to another.
    ///@param tx_data Input data structure, see {TokenTxData}.
    function saleTransaction (
        TokenTxData memory tx_data
    ) public isSystemsAdmin
    {
        uint256 l = tx_data.tokens_.length;
        require(l == tx_data.amounts_.length, "INPUT MISMATCH");

        for(uint256 i; i < l; i++) {
            bool success = tx_data.tokens_[i].transferFrom(tx_data.origin_, tx_data.recipient_, tx_data.amounts_[i]);
            require(success);
        }

        if(!_tx_group) {
            _tx_nonce++;
        }

        emit saleReceipt(tx_data.origin_, tx_data.recipient_, tx_data.tokens_, tx_data.amounts_, tx_data.subsystem_, tx_data.metadata_, _tx_nonce, _tx_group);
    }

    ///@notice Transfers nfts from one account to another.
    ///@param tx_data Input data structure, see {TokenTxData}.
    function nftTransaction (
        NFTTxData memory tx_data
    ) public isSystemsAdmin
    {
        uint256 l = tx_data.nfts_.length;
        require(l == tx_data.token_ids_.length && l == tx_data.transfer_metadatas_.length, "INPUT MISMATCH");

        for(uint256 i; i < l; i++) {
            tx_data.nfts_[i].safeTransferFrom(tx_data.origin_, tx_data.recipient_, tx_data.token_ids_[i], tx_data.transfer_metadatas_[i]);
        }

        if(!_tx_group) {
            _tx_nonce++;
        }
        
        emit nftReceipt(tx_data.origin_, tx_data.recipient_, tx_data.nfts_, tx_data.token_ids_, tx_data.transfer_metadatas_, tx_data.subsystem_, tx_data.metadata_, _tx_nonce, _tx_group);
    }

    ///@notice Transfers semi-fungibles from one account to another.
    ///@param tx_data Input data structure, see {TokenTxData}.
    function sftTransaction (
        SFTTxData memory tx_data
    ) public isSystemsAdmin
    {
        uint256 l = tx_data.sfts_.length;
        require(l == tx_data.token_ids_.length && 
                l == tx_data.transfer_metadatas_.length &&
                l == tx_data.amounts_.length, "INPUT MISMATCH");

        for(uint256 i; i < l; i++) {
            tx_data.sfts_[i].safeTransferFrom(tx_data.origin_, tx_data.recipient_, tx_data.token_ids_[i], tx_data.amounts_[i], tx_data.transfer_metadatas_[i]);
        }

        if(!_tx_group) {
            _tx_nonce++;
        }
        
        emit sftReceipt(tx_data.origin_, tx_data.recipient_, tx_data.sfts_, tx_data.token_ids_, tx_data.amounts_, tx_data.transfer_metadatas_, tx_data.subsystem_, tx_data.metadata_, _tx_nonce, _tx_group);
    }

    ///@notice Executes a trade transaction that can allow atomic transfers of any number of ERC20, ERC721 and ERC1155 tokens between accounts. 
    ///@dev Typically this will be used to transfer a single type of asset from one user in exchange for a single type of asset from another user.
    ///@dev Can alternatively be used to create complex multi-party trades involving any number of traders and any number of assets of any type, which can allow for an intent execution style multi-asset exchange.
    ///@param token_data_ Transfer data for transferring ERC20 tokens between two of the parties, see {TokenTxData}.
    ///@param nft_data_ Transfer data for transferring ERC721 tokens between two of the parties, see {NFTTxData}.
    ///@param sft_data_ Transfer data for transferring ERC1155 tokens between two of the parties, see {SFTTxData}.
    function tradeTransaction (
        TokenTxData[] memory token_data_,
        NFTTxData[] memory nft_data_,
        SFTTxData[] memory sft_data_
    ) public isSystemsAdmin groupTX
    {
        _tx_nonce++;
        
        uint256 l = token_data_.length;
        for(uint256 i = 0; i < l; i++) {
            saleTransaction(token_data_[i]);
        }

        l = nft_data_.length;
        for(uint256 i = 0; i < l; i++) {
            nftTransaction(nft_data_[i]);
        }

        l = sft_data_.length;
        for(uint256 i = 0; i < l; i++) {
            sftTransaction(sft_data_[i]);
        }
    }

    /// @notice Transfer tokens that have been sent to this contract by mistake.
    /// @dev Only callable by address with Global Admin permissions. Cannot be called to withdraw emissions tokens.
    /// @param tokenAddress_ The address of the token to recover
    /// @param tokenAmount_ The amount of the token to recover
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external isGlobalAdmin {
        IERC20(tokenAddress_).transfer(msg.sender, tokenAmount_);
    }
}