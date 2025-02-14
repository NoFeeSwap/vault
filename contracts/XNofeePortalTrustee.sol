// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofeePortalTrustee} from "./interfaces/IXNofeePortalTrustee.sol";
import {IXNofeePortal} from "./interfaces/IXNofeePortal.sol";

/// @title A nofee owner can deposit their nofees in the XNofee contract to 
/// earn more nofees. To this end, they need to use the 'XNofeePortal' 
/// contract which holds the minted xNofees for a certain period. The xNofees
/// are held in this contract so that the owner can delegate their
/// voting power to themselves or any other account. An instance of this
/// contract is deployed for every account whose xNofees are held by the 
/// portal. The corresponding instance of this contract holds the held 
/// xNofee amount and allows the owner to delegate their nofee voting power.
contract XNofeePortalTrustee is IXNofeePortalTrustee {
  /// @inheritdoc IXNofeePortalTrustee
  IXNofeePortal public immutable override portal;

  constructor() {
    // The XNofeePortal contract deploys this trustee for every owner.
    portal = IXNofeePortal(msg.sender);

    // The XNofeePortal contract is given full access to the xNofees held here.
    portal.xNofee().approve(msg.sender, type(uint256).max);
  }

  /// @inheritdoc IXNofeePortalTrustee
  function delegate(address delegatee) external {
    // Only the owner whose xNofees are held here can run this function though
    // the XNofeePortal contract.
    require(msg.sender == address(portal), OnlyByOwner(msg.sender));

    // The 'delegate' method of the XNofee contract is used to assign a
    // delegatee.
    portal.xNofee().delegate(delegatee);
  }
}