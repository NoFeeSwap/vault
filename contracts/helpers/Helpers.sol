// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {Nofee} from "@governance/Nofee.sol";

contract NofeeHelper is Nofee {
  constructor(
    address account,
    address minter_,
    uint mintingAllowedAfter_
  ) Nofee(account, minter_, mintingAllowedAfter_) {}
}