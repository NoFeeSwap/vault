// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IERC6909} from "@openzeppelin/interfaces/draft-IERC6909.sol";
import {INofee} from "@governance/interfaces/INofee.sol";
import {IXNofee} from "./IXNofee.sol";
import {IXNofeePortalTrustee} from "./IXNofeePortalTrustee.sol";

/// @notice Interface for the XNofeePortal contract.
interface IXNofeePortal is IERC6909 {
  /// @notice Thrown if attempting to withdraw/redeem xNofees after the cliff
  /// period.
  error Matured(uint256 id);

  /// @notice Thrown if attempting to transform xNofees prior to the cliff
  /// period.
  error NotMatured(uint256 id);

  /// @notice Emitted when a new XNofeePortalTrustee contract is deployed. The
  /// trustee contract holds the held xNofees and enables the owner to
  /// delegate voting power while the xNofees are held.
  /// @param owner The owner of the trustee contract, whose xNofees are held by
  /// the trustee.
  /// @param trustee The trustee contract that holds the held xNofees.
  event TrusteeDeployed(
    address indexed owner,
    IXNofeePortalTrustee indexed trustee
  );

  /// @notice The underlying nofee assets.
  function nofee() external returns (INofee);

  /// @notice The xNofee contract.
  function xNofee() external returns (IXNofee);

  /// @notice Equal to '10 ** (xNofee.decimals() - nofee.decimals())'.
  function offset() external returns (uint256);

  /// @notice The number of blocks where xNofees are held.
  function cliff() external returns (uint256);

  /// @notice The initialisation code hash of the trustee contract.
  function TRUSTEE_CREATION_CODE_HASH() external returns (bytes32);

  /// @notice A trustee contract is deployed for each address that mints 
  /// xNofee. The trustee contract holds the held xNofees, allowing the owner
  /// to continue delegating votes. The corresponding trustee's xNofee balance
  /// as managed by this contract.
  /// @param owner The owner of the corresponding XNofees.
  function trusteeBalance(address owner) external returns (uint256);

  /// @notice Sum of balances of each 'owner' across all ids.
  /// @param owner The owner of the corresponding XNofees.
  function totalBalance(address owner) external returns (uint256);

  /// @notice Calculates the deterministic address of the XNofeePortalTrustee
  /// contract corresponding to each owner.
  /// @param owner The owner associated with the trustee contract.
  function trusteeOf(
    address owner
  ) external returns (IXNofeePortalTrustee trustee);
  
  /// @notice Allows an on-chain or off-chain user to simulate the effects of
  /// their deposit at the current block, given current on-chain conditions.
  /// @param assets The number of assets to be deposited.
  /// @return shares The resulting number of shares.
  function previewDeposit(uint256 assets) external returns (uint256 shares);
  
  /// @notice Allows an on-chain or off-chain user to simulate the effects of
  /// their mint at the current block, given current on-chain conditions.
  /// @param shares The number of shares to be mint.
  /// @return assets The corresponding number of assets.
  function previewMint(uint256 shares) external returns (uint256 assets);

  /// @notice Returns the number of shares burnt corresponding to an early
  /// withdrawal.
  /// @param id The tokenId to be withdrawn.
  /// @param assets The number of assets to be deposited.
  /// @return shares The resulting number of shares.
  function previewWithdraw(
    uint256 id,
    uint256 assets
  ) external returns (uint256 shares);
  
  /// @notice Returns the number of assets burnt corresponding to an early
  /// redeem.
  /// @param id The tokenId to be redeem.
  /// @param shares The number of shares to be minted.
  /// @return assets The corresponding amount of assets.
  function previewRedeem(
    uint256 id,
    uint256 shares
  ) external returns (uint256 assets);

  /// @notice Transfers the accrued assets of the given address to the
  /// corresponding trustee and delegates voting power to the given address.
  /// @param assets The number of assets to be deposited.
  /// @param receiver The recipient of the resulting multi-tokens.
  /// @return id The resulting tokenId.
  /// @return shares The resulting number of shares.
  function deposit(
    uint256 assets,
    address receiver
  ) external returns (
    uint256 id,
    uint256 shares
  );

  /// @notice Mints exactly shares Vault xNofee shares by depositing nofees.
  /// The resulting xNofees are held by this contract.
  /// @param shares The number of shares to be minted.
  /// @param receiver The recipient of the resulting multi-tokens.
  /// @return id The resulting tokenId.
  /// @return assets The corresponding amount of assets.
  function mint(
    uint256 shares,
    address receiver
  ) external returns (
    uint256 id,
    uint256 assets
  );

  /// @notice Burns shares from owner and sends exactly assets of nofee to
  /// receiver. The conversion rate at the time of minting is used.
  /// @param id The tokenId to be withdrawn.
  /// @param assets The amount of assets to be withdrawn.
  /// @param receiver The recipient of the resulting assets.
  /// @param owner The owner of the multi-tokens to be withdrawn.
  /// @return shares The number of shares to be withdrawn.
  function withdraw(
    uint256 id,
    uint256 assets,
    address receiver,
    address owner
  ) external returns (
    uint256 shares
  );

  /// @notice Burns exactly xNofee shares from owner and sends assets of nofee
  /// to receiver. The conversion rate at the time of minting is used.
  /// @param id The tokenId to be redeemed.
  /// @param shares The number of shares to be redeemed.
  /// @param receiver The recipient of the resulting assets.
  /// @param owner The owner of the multi-tokens to be redeemed.
  /// @return assets The resulting amount of assets.
  function redeem(
    uint256 id,
    uint256 shares,
    address receiver,
    address owner
  ) external returns (
    uint256 assets
  );

  /// @notice Unlocks xNofees from this contracts custody and sends them to
  /// receiver.
  /// @param id The tokenId to be transformed to xNofee.
  /// @param shares The number of shares to be transformed.
  /// @param receiver The recipient of the resulting xNofees.
  /// @param owner The owner of the multi-tokens to be transformed.
  function transform(
    uint256 id,
    uint256 shares,
    address receiver,
    address owner
  ) external;

  /// @notice Transfers the accrued assets of the given address to the
  /// corresponding XNofeePortalTrustee and delegates voting power to the given
  /// address.
  /// @param delegatee The address to be appointed as the delegatee.
  function delegate(address delegatee) external;

  /// @notice Transfers the xNofees from trustee back to 'this'.
  function transferFromTrustee() external;
}