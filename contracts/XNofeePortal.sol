// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity 0.8.28;

import {IXNofeePortal} from "./interfaces/IXNofeePortal.sol";
import {IXNofee} from "./interfaces/IXNofee.sol";
import {IXNofeePortalTrustee} from "./interfaces/IXNofeePortalTrustee.sol";
import {INofee} from "@governance/interfaces/INofee.sol";
import {ERC6909} from "@openzeppelin/token/ERC6909/draft-ERC6909.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {XNofeePortalTrustee} from "./XNofeePortalTrustee.sol";

/// @title This contract holds xNofees and mints ERC6909 for the owner of the 
/// deposited tokens. The owner may take the held xNofees after the cliff
/// period
contract XNofeePortal is IXNofeePortal, ERC6909 {
  using Math for uint256;

  /// @inheritdoc IXNofeePortal
  INofee public immutable override nofee;

  /// @inheritdoc IXNofeePortal
  IXNofee public immutable override xNofee;

  /// @inheritdoc IXNofeePortal
  uint256 public immutable override offset;

  /// @inheritdoc IXNofeePortal
  uint256 public immutable override cliff;

  /// @inheritdoc IXNofeePortal
  bytes32 public immutable override TRUSTEE_CREATION_CODE_HASH = keccak256(
    abi.encodePacked(type(XNofeePortalTrustee).creationCode)
  );

  /// @inheritdoc IXNofeePortal
  mapping(address owner => uint256) public override trusteeBalance;

  /// @inheritdoc IXNofeePortal
  mapping(address owner => uint256) public override totalBalance;

  constructor(
    uint256 _cliff,
    uint8 _decimalsOffset,
    INofee _nofee
  ) {
    xNofee = IXNofee(msg.sender);
    nofee = INofee(_nofee);
    offset = 10 ** _decimalsOffset;
    cliff = _cliff;
  }
  
  /// @inheritdoc IXNofeePortal
  function trusteeOf(
    address owner
  ) public view override returns (
    IXNofeePortalTrustee trustee
  ) {
    return IXNofeePortalTrustee(
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

  /// @inheritdoc IXNofeePortal
  function previewDeposit(
    uint256 assets
  ) public view override returns (uint256) {
    return xNofee.previewDeposit(assets);
  }

  /// @inheritdoc IXNofeePortal
  function previewMint(uint256 shares) public view override returns (uint256) {
    return xNofee.previewMint(shares);
  }

  /// @inheritdoc IXNofeePortal
  function previewWithdraw(
    uint256 id,
    uint256 assets
  ) public view override returns (uint256) {
    (uint256 totalAssets, uint256 totalShares) = _decodeId(id);
    return assets.mulDiv(
      totalShares + offset,
      totalAssets + 1,
      Math.Rounding.Ceil
    );
  }

  /// @inheritdoc IXNofeePortal
  function previewRedeem(
    uint256 id,
    uint256 shares
  ) public view override returns (uint256) {
    (uint256 totalAssets, uint256 totalShares) = _decodeId(id);
    return shares.mulDiv(
      totalAssets + 1,
      totalShares + offset,
      Math.Rounding.Floor
    );
  }

  /// @inheritdoc IXNofeePortal
  function deposit(
    uint256 assets,
    address receiver
  ) external override returns (
    uint256 id,
    uint256 shares
  ) {
    shares = previewDeposit(assets);
    id = _mint(receiver, shares);
    nofee.transferFrom(msg.sender, address(this), assets);
    nofee.approve(address(xNofee), assets);
    xNofee.deposit(assets, address(this));
  }

  /// @inheritdoc IXNofeePortal
  function mint(
    uint256 shares,
    address receiver
  ) external override returns (
    uint256 id,
    uint256 assets
  ) {
    assets = previewMint(shares);
    id = _mint(receiver, shares);
    nofee.transferFrom(msg.sender, address(this), assets);
    nofee.approve(address(xNofee), assets);
    xNofee.mint(shares, address(this));
  }

  /// @inheritdoc IXNofeePortal
  function withdraw(
    uint256 id,
    uint256 assets,
    address receiver,
    address owner
  ) external override returns (
    uint256 shares
  ) {
    require(block.number <= (id >> 224) + cliff, Matured(id));

    shares = previewWithdraw(id, assets);

    _withdraw(id, assets, shares, receiver, owner);
  }

  /// @inheritdoc IXNofeePortal
  function redeem(
    uint256 id,
    uint256 shares,
    address receiver,
    address owner
  ) external override returns (
    uint256 assets
  ) {
    require(block.number <= (id >> 224) + cliff, Matured(id));

    assets = previewRedeem(id, shares);

    _withdraw(id, assets, shares, receiver, owner);
  }

  /// @inheritdoc IXNofeePortal
  function transform(
    uint256 id,
    uint256 shares,
    address receiver,
    address owner
  ) external override {
    require(block.number > (id >> 224) + cliff, NotMatured(id));

    _spendAllowance(owner, msg.sender, id, shares);

    _burn(owner, id, shares);

    xNofee.transfer(receiver, shares);
  }

  /// @inheritdoc IXNofeePortal
  function delegate(address delegatee) external override {
    uint256 amount;
    unchecked {
      amount = totalBalance[msg.sender] - trusteeBalance[msg.sender];
    }

    IXNofeePortalTrustee trustee = trusteeOf(msg.sender);
    bool deploy;
    assembly {
      deploy := iszero(extcodesize(trustee))
    }

    if (deploy) {
      new XNofeePortalTrustee{
        salt: keccak256(abi.encodePacked(msg.sender))
      }();

      emit TrusteeDeployed(msg.sender, trustee);
    }

    if (amount != 0) {
      xNofee.transfer(address(trustee), amount);
      unchecked {
        trusteeBalance[msg.sender] += amount;
      }
    }

    trustee.delegate(delegatee);
  }

  /// @inheritdoc IXNofeePortal
  function transferFromTrustee() external override {
    _transferFromTrustee(msg.sender, trusteeBalance[msg.sender]);
  }

  function _update(
    address from,
    address to,
    uint256 id,
    uint256 amount
  ) internal override {
    super._update(from, to, id, amount);
    unchecked {
      if (from != address(0)) {
        uint256 oldTrusteeBalance = trusteeBalance[from];
        uint256 newTotalBalance = totalBalance[from] - amount;
        totalBalance[from] = newTotalBalance;
        if (newTotalBalance < oldTrusteeBalance) {
          _transferFromTrustee(from, oldTrusteeBalance - newTotalBalance);
        }
      }
      if (to != address(0)) {
        totalBalance[to] += amount;
      }
    }
  }

  function _withdraw(
    uint256 id,
    uint256 assets,
    uint256 shares,
    address receiver,
    address owner
  ) internal {
    _spendAllowance(owner, msg.sender, id, shares);

    _burn(owner, id, shares);

    unchecked {
      nofee.transfer(
        address(xNofee),
        xNofee.redeem(shares, address(this), address(this)) - assets
      );      
    }

    nofee.transfer(receiver, assets);
  }

  function _spendAllowance(
    address owner,
    address spender,
    uint256 id,
    uint256 amount
  ) internal override {
    if (owner != msg.sender) {
      if (!isOperator(owner, msg.sender)) {
        super._spendAllowance(owner, msg.sender, id, amount);
      }
    }
  }

  function _mint(
    address receiver,
    uint256 amount
  ) internal returns (
    uint256 id
  ) {
    id = (
      block.number << 224
    ) | (
      (xNofee.totalAssets() & type(uint96).max) << 128
    ) | (
      xNofee.totalSupply() & type(uint128).max
    );
    _mint(receiver, id, amount);
  }

  function _transferFromTrustee(
    address from,
    uint256 amount
  ) internal {
    xNofee.transferFrom(address(trusteeOf(from)), address(this), amount);
    unchecked {
      trusteeBalance[from] -= amount;
    }
  }

  function _decodeId(
    uint256 id
  ) internal pure returns (
    uint256 totalAssets,
    uint256 totalShares
  ) {
    totalAssets = (id >> 128) & type(uint96).max;
    totalShares = id & type(uint128).max;
  }
}