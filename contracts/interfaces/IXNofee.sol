// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {INofee} from "@governance/interfaces/INofee.sol";
import {IXNofeePortal} from "./IXNofeePortal.sol";
import {IXNofeeTrustee} from "./IXNofeeTrustee.sol";

/// @notice Interface for the XNofee contract.
interface IXNofee is IERC4626 {
  /// @notice Thrown when any account other than the portal attempts to
  /// deposit/mint.
  error OnlyThroughPortal(address attemptingAddress);

  /// @notice Emitted when a new XNofeeTrustee contract is deployed. The
  /// trustee contract holds the deposited nofees and enables the owner to
  /// delegate voting power while the nofees are held.
  /// @param owner The account whose nofees are held by the trustee contract.
  /// @param trustee The trustee contract that holds the deposited nofees.
  event TrusteeDeployed(
    address indexed owner,
    IXNofeeTrustee indexed trustee
  );

  /// @notice The portal contract which is allowed to deposit/mint.
  function portal() external returns (IXNofeePortal);

  /// @notice The initialisation code hash of the trustee contract.
  function TRUSTEE_CREATION_CODE_HASH() external returns (bytes32);

  /// @notice The total number of nofees across all trustee contracts.
  function totalNofeeTrusted() external returns (uint256);

  /// @notice A trustee contract is deployed for each address that mints 
  /// xNofee. The trustee contract holds the held tokens, allowing the owner
  /// to continue delegating votes.
  /// @param owner The owner of the corresponding XNofees.
  /// @return balance The corresponding trustee's nofee balance as managed by
  /// this contract.
  function trusteeBalance(address owner) external returns (uint256 balance);

  /// @notice Calculates the deterministic address of the trustee contract
  /// corresponding to each owner.
  /// @param owner The owner of the corresponding XNofees.
  /// @param trustee The trustee contract associated with owner.
  function trusteeOf(address owner) external returns (IXNofeeTrustee trustee);

  /// @notice Transfers the accrued assets of the given address to the
  /// corresponding trustee and delegates voting power to the given address.
  /// @param delegatee The address to be appointed as the delegatee.
  function delegate(address delegatee) external;

  /// @notice Transfers all of the assets from trustee contract associated with
  /// 'msg.sender' back to 'this'.
  function transferFromTrustee() external;
}