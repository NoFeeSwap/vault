// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofeePortal} from "./IXNofeePortal.sol";

/// @notice Interface for the XNofeePortalTrustee contract.
interface IXNofeePortalTrustee {
  /// @notice Thrown when any account other than the XNofee owner attempts to 
  /// delegate the tokens held by this contract.
  error OnlyByOwner(address attemptingAddress);

  /// @notice The address of the XNofeePortal contract which is permitted to
  /// move xNofees from one trustee to another.
  function portal() external returns (IXNofeePortal);

  /// @notice Delegates the voting power of the xNofees held by this contract
  /// to an arbitrary 'delegatee' as assigned by the owner of the corresponding 
  /// xNofees.
  /// @param delegatee The address to which the voting power will be delegated.
  function delegate(address delegatee) external;
}