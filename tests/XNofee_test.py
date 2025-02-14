# Copyright 2025, NoFeeSwap LLC - All rights reserved.
import pytest
import brownie
from sympy import Integer
from brownie import accounts, NofeeHelper, XNofee, XNofeePortal

address0 = '0x0000000000000000000000000000000000000000'

@pytest.fixture(autouse=True)
def deployment(fn_isolation, chain):
    root = accounts[0]
    other = accounts[1]
    owner = accounts[2]

    token = NofeeHelper.deploy(root, address0, chain[-1].timestamp + 3600, {'from': root})
    offsetDecimal = 6

    return root, other, owner, token, offsetDecimal

def test_deployment(deployment, chain, request, worker_id):
    root, other, owner, token, offsetDecimal = deployment

    portalCliff = chain[-1].number + 100

    xToken = XNofee.deploy(portalCliff, token.address, {'from': root})

    assert xToken.name() == "XNofee"
    assert xToken.symbol() == "XNOFEE"
    assert xToken.decimals() == token.decimals() + offsetDecimal
    assert xToken.asset() == token.address

    portal = XNofeePortal.at(xToken.portal())

    assert portal.nofee() == token.address
    assert portal.xNofee() == xToken.address
    assert portal.offset() == 10 ** offsetDecimal
    assert portal.cliff() == portalCliff

def test_XNofee(deployment, chain, request, worker_id):
    root, other, owner, token, offsetDecimal = deployment

    portalCliff = chain[-1].number + 100

    # XNofee is deployed.
    xToken = XNofee.deploy(portalCliff, token.address, {'from': root})
    portal = XNofeePortal.at(xToken.portal())

    # 'root' gives other some nofees.
    assets0 = 10000
    shares0 = portal.previewDeposit(assets0)
    token.transfer(other.address, assets0, {'from': root})

    # 'other' invests those nofees through portal and gives them to 'owner'.
    token.approve(portal.address, assets0, {'from': other})
    id0 = ((1 + chain[-1].number) << 224) + (xToken.totalAssets() << 128) + xToken.totalSupply()

    tx = portal.deposit(assets0, owner, {'from': other})
    id, shares = tx.return_value
    assert id == id0
    assert shares == shares0
    assert portal.totalBalance(owner) == shares0
    assert portal.balanceOf(owner, id0) == shares0
    assert xToken.balanceOf(portal) == shares0
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert xToken.totalSupply() == shares0
    assert xToken.totalAssets() == assets0
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0
    with brownie.reverts('NotMatured: ' + str(id0)):
        portal.transform(id0, shares0 // 2, other, owner, {'from': owner})

    # 'root' makes a contribution.
    contribution0 = 100000
    token.transfer(xToken.address, contribution0, {'from': root})
    assert xToken.totalAssets() == assets0 + contribution0

    # 'owner' transfers some of the shares to 'other'.
    shares4 = 2500
    tx = portal.transfer(other, id0, shares4, {'from': owner})
    assert portal.totalBalance(owner) == shares0 - shares4
    assert portal.balanceOf(owner, id0) == shares0 - shares4
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares0
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert xToken.totalSupply() == shares0
    assert xToken.totalAssets() == assets0 + contribution0
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0 - shares4

    # 'root' makes a contribution.
    contribution1 = 10000
    token.transfer(xToken.address, contribution1, {'from': root})
    assert xToken.totalAssets() == assets0 + contribution0 + contribution1

    # 'root' gives other some nofees.
    assets1 = 90000
    shares1 = portal.previewDeposit(assets1)
    token.transfer(other.address, assets1, {'from': root})

    # 'other' invests those nofees through portal and gives them to 'owner'.
    token.approve(portal.address, assets1, {'from': other})
    id1 = ((1 + chain[-1].number) << 224) + (xToken.totalAssets() << 128) + xToken.totalSupply()
    tx = portal.deposit(assets1, owner, {'from': other})
    id, shares = tx.return_value
    assert id == id1
    assert shares == shares1
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4
    assert portal.balanceOf(owner, id0) == shares0 - shares4
    assert portal.balanceOf(owner, id1) == shares1
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares0 + shares1
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert xToken.totalSupply() == shares0 + shares1
    assert xToken.totalAssets() == assets0 + assets1 + contribution0 + contribution1
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4

    # 'root' makes a contribution.
    contribution2 = 120000
    token.transfer(xToken.address, contribution2, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + contribution0 + contribution1 + contribution2

    # 'owner' withdraws some tokens and gives the resulting assets to 'other'.
    assets5 = 1050
    shares5 = portal.previewWithdraw(id1, assets5, {'from': owner})
    tx = portal.approve(root, id1, shares5, {'from': owner})
    tx = portal.withdraw(id1, assets5, other, owner, {'from': root})
    shares = tx.return_value
    assert shares == shares5
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4 - shares5
    assert portal.balanceOf(owner, id0) == shares0 - shares4
    assert portal.balanceOf(owner, id1) == shares1 - shares5
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares0 + shares1 - shares5
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.balanceOf(other) == assets5
    assert xToken.totalSupply() == shares0 + shares1 - shares5
    assert xToken.totalAssets() == assets0 + assets1 - assets5 + contribution0 + contribution1 + contribution2
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4 - shares5

    # 'root' makes a contribution.
    contribution3 = 123000
    token.transfer(xToken.address, contribution3, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 - assets5 + contribution0 + contribution1 + contribution2 + contribution3

    # 'owner' redeems some shares and gives the resulting assets to 'other'.
    shares6 = 170000000
    assets6 = portal.previewRedeem(id0, shares6, {'from': owner})
    tx = portal.approve(root, id0, shares6, {'from': owner})
    tx = portal.withdraw(id0, assets6, other, owner, {'from': root})
    shares = tx.return_value
    assert shares == shares6
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4 - shares5 - shares6
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares0 + shares1 - shares5 - shares6
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.balanceOf(other) == assets5 + assets6
    assert xToken.totalSupply() == shares0 + shares1 - shares5 - shares6
    assert xToken.totalAssets() == assets0 + assets1 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0 + shares1 - shares4 - shares5 - shares6

    # 'root' makes a contribution.
    contribution4 = 123000
    token.transfer(xToken.address, contribution4, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4

    # 'root' gives other some nofees.
    assets2 = 70000
    shares2 = portal.previewDeposit(assets2)
    token.transfer(other.address, assets2, {'from': root})

    # 'other' invests those nofees through portal and gives them to 'owner'.
    token.approve(portal.address, assets2, {'from': other})
    id2 = ((1 + chain[-1].number) << 224) + (xToken.totalAssets() << 128) + xToken.totalSupply()
    tx = portal.deposit(assets2, owner, {'from': other})
    id, shares = tx.return_value
    assert id == id2
    assert shares == shares2
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5
    assert portal.balanceOf(owner, id2) == shares2
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares0 + shares1 + shares2 - shares5 - shares6
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert xToken.totalSupply() == shares0 + shares1 + shares2 - shares5 - shares6
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4
    assert portal.trusteeBalance(owner) == 0
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6

    # 'root' makes a contribution.
    contribution5 = 123000
    token.transfer(xToken.address, contribution5, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5

    # 'owner' delegates to 'root'.
    tx = portal.delegate(root, {'from': owner})
    assert id == id2
    assert shares == shares2
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5
    assert portal.balanceOf(owner, id2) == shares2
    assert portal.totalBalance(other) == shares4
    assert portal.balanceOf(other, id0) == shares4
    assert xToken.balanceOf(portal) == shares4
    assert xToken.balanceOf(portal.trusteeOf(owner)) == shares0 + shares1 + shares2 - shares5 - shares6 - shares4
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.delegates(xToken.trusteeOf(portal.trusteeOf(owner))) == root.address
    assert xToken.totalSupply() == shares0 + shares1 + shares2 - shares5 - shares6
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5
    assert portal.trusteeBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6

    # 'root' makes a contribution.
    contribution6 = 10023000
    token.transfer(xToken.address, contribution6, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6

    # 'owner' transfers some of the shares to 'other'.
    shares7 = 3500
    tx = portal.transfer(other, id1, shares7, {'from': owner})
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5 - shares7
    assert portal.balanceOf(owner, id2) == shares2
    assert portal.totalBalance(other) == shares4 + shares7
    assert portal.balanceOf(other, id0) == shares4
    assert portal.balanceOf(other, id1) == shares7
    assert xToken.balanceOf(portal) == shares4 + shares7
    assert xToken.balanceOf(portal.trusteeOf(owner)) == shares0 + shares1 + shares2 - shares5 - shares6 - shares4 - shares7
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.delegates(xToken.trusteeOf(portal.trusteeOf(owner))) == root.address
    assert xToken.totalSupply() == shares0 + shares1 + shares2 - shares5 - shares6
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6
    assert portal.trusteeBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7

    # 'root' makes a contribution.
    contribution7 = 17023000
    token.transfer(xToken.address, contribution7, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7

    # 'owner' withdraws some tokens and gives the resulting assets to 'other'.
    assets8 = 1530
    shares8 = portal.previewWithdraw(id2, assets8, {'from': owner})
    tx = portal.approve(root, id2, shares8, {'from': owner})
    tx = portal.withdraw(id2, assets8, other, owner, {'from': root})
    shares = tx.return_value
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5 - shares7
    assert portal.balanceOf(owner, id2) == shares2 - shares8
    assert portal.totalBalance(other) == shares4 + shares7
    assert portal.balanceOf(other, id0) == shares4
    assert portal.balanceOf(other, id1) == shares7
    assert xToken.balanceOf(portal) == shares4 + shares7
    assert xToken.balanceOf(portal.trusteeOf(owner)) == shares0 + shares1 + shares2 - shares5 - shares6 - shares4 - shares7 - shares8
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.delegates(xToken.trusteeOf(portal.trusteeOf(owner))) == root.address
    assert token.balanceOf(other) == assets5 + assets6 + assets8
    assert xToken.totalSupply() == shares0 + shares1 + shares2 - shares5 - shares6 - shares8
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 - assets8 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7
    assert portal.trusteeBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8

    # 'root' makes a contribution.
    contribution8 = 7023000
    token.transfer(xToken.address, contribution8, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 - assets8 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7 + contribution8

    # 'owner' redeems some shares and gives the resulting assets to 'other'.
    shares9 = 159000000
    assets9 = portal.previewRedeem(id2, shares9, {'from': owner})
    tx = portal.approve(root, id2, shares9, {'from': owner})
    tx = portal.redeem(id2, shares9, other, owner, {'from': root})
    shares = tx.return_value
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5 - shares7
    assert portal.balanceOf(owner, id2) == shares2 - shares8 - shares9
    assert portal.totalBalance(other) == shares4 + shares7
    assert portal.balanceOf(other, id0) == shares4
    assert portal.balanceOf(other, id1) == shares7
    assert xToken.balanceOf(portal) == shares4 + shares7
    assert xToken.balanceOf(portal.trusteeOf(owner)) == shares0 + shares1 + shares2 - shares5 - shares6 - shares4 - shares7 - shares8 - shares9
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.delegates(xToken.trusteeOf(portal.trusteeOf(owner))) == root.address
    assert token.balanceOf(other) == assets5 + assets6 + assets8 + assets9
    assert xToken.totalSupply() == shares0 + shares1 + shares2 - shares5 - shares6 - shares8 - shares9
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 - assets8 - assets9 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7 + contribution8
    assert portal.trusteeBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9

    # 'root' makes a contribution.
    contribution9 = 702300050
    token.transfer(xToken.address, contribution9, {'from': root})
    assert xToken.totalAssets() == assets0 + assets1 + assets2 - assets5 - assets6 - assets8 - assets9 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7 + contribution8 + contribution9

    # 'root' gives other some nofees.
    assets3 = 110000
    shares3 = portal.previewDeposit(assets3)
    token.transfer(other.address, assets3, {'from': root})

    # 'other' invests those nofees through portal and gives them to 'owner'.
    token.approve(portal.address, assets3, {'from': other})
    id3 = ((1 + chain[-1].number) << 224) + (xToken.totalAssets() << 128) + xToken.totalSupply()
    tx = portal.deposit(assets3, owner, {'from': other})
    id, shares = tx.return_value
    assert id == id3
    assert shares == shares3
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 + shares3 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9
    assert portal.balanceOf(owner, id0) == shares0 - shares4 - shares6
    assert portal.balanceOf(owner, id1) == shares1 - shares5 - shares7
    assert portal.balanceOf(owner, id2) == shares2 - shares8 - shares9
    assert portal.balanceOf(owner, id3) == shares3
    assert portal.totalBalance(other) == shares4 + shares7
    assert portal.balanceOf(other, id0) == shares4
    assert portal.balanceOf(other, id1) == shares7
    assert xToken.balanceOf(portal) == shares3 + shares4 + shares7
    assert xToken.balanceOf(portal.trusteeOf(owner)) == shares0 + shares1 + shares2 - shares5 - shares6 - shares4 - shares7 - shares8 - shares9
    assert token.balanceOf(xToken) == xToken.totalAssets() - xToken.totalNofeeTrusted()
    assert token.delegates(xToken.trusteeOf(portal.trusteeOf(owner))) == root.address
    assert token.balanceOf(other) == assets5 + assets6 + assets8 + assets9
    assert xToken.totalSupply() == shares0 + shares1 + shares2 + shares3 - shares5 - shares6 - shares8 - shares9
    assert xToken.totalAssets() == assets0 + assets1 + assets2 + assets3 - assets5 - assets6 - assets8 - assets9 + contribution0 + contribution1 + contribution2 + contribution3 + contribution4 + contribution5 + contribution6 + contribution7 + contribution8 + contribution9
    assert portal.trusteeBalance(owner) == shares0 + shares1 + shares2 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9
    assert portal.totalBalance(owner) == shares0 + shares1 + shares2 + shares3 - shares4 - shares5 - shares6 - shares7 - shares8 - shares9

    # 'owner' and 'other' transform all of their portal shares.
    chain.mine(portalCliff)
    with brownie.reverts('Matured: ' + str(id0)):
        portal.withdraw(id0, portal.previewWithdraw(id0, portal.balanceOf(owner, id0)), other, owner, {'from': owner})
    with brownie.reverts('Matured: ' + str(id0)):
        portal.redeem(id0, portal.balanceOf(owner, id0), other, owner, {'from': owner})
    portal.transform(id0, portal.balanceOf(owner, id0), owner, owner, {'from': owner})
    portal.transform(id1, portal.balanceOf(owner, id1), owner, owner, {'from': owner})
    portal.transform(id2, portal.balanceOf(owner, id2), owner, owner, {'from': owner})
    portal.transform(id3, portal.balanceOf(owner, id3), owner, owner, {'from': owner})
    portal.transform(id0, portal.balanceOf(other, id0), other, other, {'from': other})
    portal.transform(id1, portal.balanceOf(other, id1), other, other, {'from': other})
    portal.transform(id2, portal.balanceOf(other, id2), other, other, {'from': other})
    portal.transform(id3, portal.balanceOf(other, id3), other, other, {'from': other})
    assert xToken.balanceOf(portal) == 0

    # 'owner' and 'other' burn all xNofees.
    ratio = Integer(xToken.totalSupply() + (10 ** 6)) / Integer(xToken.totalAssets() + 1)

    xToken.redeem(xToken.balanceOf(owner), owner, owner, {'from': owner})
    xToken.redeem(xToken.balanceOf(other), other, other, {'from': other})

    assert ratio >= Integer(10 ** 6) / Integer(xToken.totalAssets() + 1)
    if xToken.totalAssets() != 0:
        assert ratio < Integer(10 ** 6) / Integer(xToken.totalAssets())