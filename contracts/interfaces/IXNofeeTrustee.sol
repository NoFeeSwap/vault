// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofee} from "./IXNofee.sol";

/// @notice Interface for the XNofee contract.
interface IXNofeeTrustee {
  /// @notice Thrown when any account other than the XNofee owner attempts to 
  /// delegate the tokens held by this contract.
  error OnlyByOwner(address attemptingAddress);

  /// @notice The address of the XNofee contract which is permitted to move
  /// nofees from one trustee to another upon transfer of the 
  /// corresponding xNofees.
  function xNofee() external returns (IXNofee);

  /// @notice Delegates the voting power of the nofees held by this contract to
  /// the 'delegatee' assigned by the corresponding xNofees owner.
  /// @param delegatee The address to which the voting power will be delegated.
  function delegate(address delegatee) external;
}