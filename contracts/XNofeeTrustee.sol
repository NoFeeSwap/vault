// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofeeTrustee} from "./interfaces/IXNofeeTrustee.sol";
import {IXNofee} from "./interfaces/IXNofee.sol";
import {INofee} from "@governance/interfaces/INofee.sol";

/// @title A nofee owner can deposit their nofees in the XNofee contract to 
/// earn more nofees. While nofees are deposited, the owner can delegate their
/// voting power to themselves or any other account. To that end, an instance
/// of this contract is deployed for every account that deposits to the XNofee 
/// contract. The corresponding instance of this contract holds the deposited 
/// nofee amount and allows the owner of the corresponding xNofees to delegate 
/// their nofee voting power while nofees are held here.
contract XNofeeTrustee is IXNofeeTrustee {
  /// @inheritdoc IXNofeeTrustee
  IXNofee public immutable override xNofee;

  constructor() {
    // The XNofee contract deploys this trustee for every xNofee owner.
    xNofee = IXNofee(msg.sender);

    // The XNofee contract is given full access to the nofees held here.
    INofee(xNofee.asset()).approve(msg.sender, type(uint256).max);
  }

  /// @inheritdoc IXNofeeTrustee
  function delegate(address delegatee) external override {
    // Only the owner whose nofees are held here can run this function though
    // the XNofee contract.
    require(msg.sender == address(xNofee), OnlyByOwner(msg.sender));

    // The 'delegate' method of the Nofee contract is used to assign a
    // delegatee.
    INofee(xNofee.asset()).delegate(delegatee);
  }
}