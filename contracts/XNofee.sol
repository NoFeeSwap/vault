// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofee} from "./interfaces/IXNofee.sol";
import {IXNofeeTrustee} from "./interfaces/IXNofeeTrustee.sol";
import {IXNofeePortal} from "./interfaces/IXNofeePortal.sol";
import {INofee} from "@governance/interfaces/INofee.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {ERC4626Permit} from "./ERC4626Permit.sol";
import {XNofeeTrustee} from "./XNofeeTrustee.sol";
import {XNofeePortal} from "./XNofeePortal.sol";

/// @title This contract holds nofees and mints xNofee for the owner of the 
/// deposited tokens. Upon withdrawal, the owner receives more nofees
/// than initially deposited due to nofee payments from the
/// 'IncentivePoolFactory' contract to this contract.
contract XNofee is IXNofee, ERC4626Permit {
  
  /// @inheritdoc IXNofee
  IXNofeePortal public immutable override portal;

  /// @inheritdoc IXNofee
  bytes32 public immutable override TRUSTEE_CREATION_CODE_HASH = keccak256(
    abi.encodePacked(type(XNofeeTrustee).creationCode)
  );

  /// @inheritdoc IXNofee
  uint256 public override totalNofeeTrusted;

  /// @inheritdoc IXNofee
  mapping(address owner => uint256) public override trusteeBalance;

  constructor(
    uint256 portalCliff,
    INofee nofee
  ) ERC4626Permit(address(nofee), "XNofee") ERC20("XNofee", "XNOFEE") {
    portal = new XNofeePortal(portalCliff, _decimalsOffset(), nofee);
  }

  /// @inheritdoc IERC4626
  function totalAssets() public view override (
    ERC4626,
    IERC4626
  ) returns (uint256) {
    return super.totalAssets() + totalNofeeTrusted;
  }

  /// @inheritdoc IXNofee
  function trusteeOf(
    address owner
  ) public view override returns (
    IXNofeeTrustee trustee
  ) {
    return IXNofeeTrustee(
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                uint8(0xFF),
                this,
                keccak256(abi.encodePacked(owner)),
                TRUSTEE_CREATION_CODE_HASH
              )
            )
          )
        )
      )
    );
  }

  /// @inheritdoc IXNofee
  function delegate(address delegatee) external override {
    uint256 amount;
    unchecked {
      amount = previewRedeem(
        balanceOf(msg.sender)
      ) - trusteeBalance[msg.sender];
    }

    // The trustee address for 'owner' is calculated.
    IXNofeeTrustee trustee = trusteeOf(msg.sender);
    bool deploy;
    assembly {
      deploy := iszero(extcodesize(trustee))
    }

    // In this case, the trustee contract should be deployed.
    if (deploy) {
      new XNofeeTrustee{salt: keccak256(abi.encodePacked(msg.sender))}();

      // An event is emitted to announce the deployment of a trustee contract
      // for 'owner'.
      emit TrusteeDeployed(msg.sender, IXNofeeTrustee(trustee));
    }

    if (amount != 0) {
      INofee(asset()).transfer(address(trustee), amount);
      unchecked {
        totalNofeeTrusted += amount;
        trusteeBalance[msg.sender] += amount;
      }
    }

    IXNofeeTrustee(trustee).delegate(delegatee);
  }

  /// @inheritdoc IXNofee
  function transferFromTrustee() external override {
    _transferFromTrustee(msg.sender, trusteeBalance[msg.sender]);
  }

  /// @notice Transfers a `value` amount of tokens from `from` to `to`, or
  /// alternatively mints (or burns) if `from` (or `to`) is the zero address.
  function _update(
    address from,
    address to,
    uint256 value
  ) internal override {
    super._update(from, to, value);
    uint256 oldTrusteeBalance = trusteeBalance[from];
    uint256 newTrusteeBalance = previewRedeem(balanceOf(from));
    if (oldTrusteeBalance > newTrusteeBalance) {
      unchecked {
        _transferFromTrustee(from, oldTrusteeBalance - newTrusteeBalance);
      }
    }
  }

  /// @notice Transfers assets from the trustee contract of 'owner' to
  /// 'receiver'.
  function _transferFromTrustee(
    address from,
    uint256 amount
  ) internal {
    INofee(asset()).transferFrom(
      address(trusteeOf(from)),
      address(this),
      amount
    );
    unchecked {
      trusteeBalance[from] -= amount;
      totalNofeeTrusted -= amount;
    }
  }

  /// @notice Deposit/mint common workflow.
  function _deposit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares
  ) internal override {
    require(caller == address(portal), OnlyThroughPortal(caller));
    super._deposit(caller, receiver, assets, shares);
  }

  function _decimalsOffset() internal pure override returns (uint8) {
    return 6;
  }
}