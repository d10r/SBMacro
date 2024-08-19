// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISuperfluid, ISuperToken, IERC20, IERC20Metadata, ISuperfluidPool }
    from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { MacroForwarder } from "@superfluid-finance/ethereum-contracts/contracts/utils/MacroForwarder.sol";
import { ITorex } from "../src/interfaces/ITorex.sol";
import { SBMacro } from "../src/SBMacro.sol";

/**
 * Fork test.
 * Configuration to be provided via env vars RPC, HOST_ADDR, TOREX_ADDR, MACRO_FWD_ADDR.
 */
contract SBMacroTest is Test {
    ISuperfluid host;
    ITorex torex;
    ISuperToken inToken;
    MacroForwarder macroFwd;
    address alice = address(0x721);
    int96 constant DEFAULT_FLOWRATE = 42e15;
    address DEFAULT_DISTRIBUTOR = address(0x69);
    address DEFAULT_REFERRER = address(0x70);

    constructor() {
        string memory rpc = vm.envString("RPC");
        vm.createSelectFork(rpc);
        address hostAddr = vm.envAddress("HOST_ADDR");
        host = ISuperfluid(hostAddr);
        address torexAddr = vm.envAddress("TOREX_ADDR");
        torex = ITorex(torexAddr);
        address macroFwdAddr = vm.envOr("MACRO_FWD_ADDR", 0xFd017DBC8aCf18B06cff9322fA6cAae2243a5c95);
        macroFwd = MacroForwarder(macroFwdAddr);
    }

    function setUp() public {
        (inToken,) = torex.getPairedTokens();
        // can't directly deal SuperTokens (see https://github.com/foundry-rs/forge-std/issues/570), thus using upgrade()
        address underlyingToken = inToken.getUnderlyingToken();
        deal(underlyingToken, alice, 1e12 ether); // make her a trillionaire
    }

    function testWithoutUpgrade() external {
        SBMacro m = new SBMacro();

        vm.startPrank(alice);
        address underlyingToken = inToken.getUnderlyingToken();
        IERC20(underlyingToken).approve(address(inToken), type(uint256).max);
        inToken.upgrade(1000 ether);

        macroFwd.runMacro(m, abi.encode(address(torex), DEFAULT_FLOWRATE, DEFAULT_DISTRIBUTOR, DEFAULT_REFERRER, 0));
        vm.stopPrank();

        ISuperfluidPool outTokenDistributionPool = torex.outTokenDistributionPool();
        assertGt(outTokenDistributionPool.getUnits(alice), 0, "no outTokenDistributionPool units assigned");
        // TODO: verify distributor, referrer
    }

    function testWithExactUpgradeAmount() public {
        SBMacro m = new SBMacro();

        vm.startPrank(alice);
        address underlyingToken = inToken.getUnderlyingToken();
        IERC20(underlyingToken).approve(address(inToken), type(uint256).max);

        vm.expectRevert(); // revert bcs sender got no SuperTokens and upgradeAmount is 0
        macroFwd.runMacro(m, abi.encode(address(torex), DEFAULT_FLOWRATE, DEFAULT_DISTRIBUTOR, DEFAULT_REFERRER, 0));

        uint256 upgradeAmount = 1000 ether;
        (uint256 underlyingAmount,) = inToken.toUnderlyingAmount(upgradeAmount);
        uint256 uBalanceBefore = IERC20(underlyingToken).balanceOf(alice);
        macroFwd.runMacro(m, abi.encode(address(torex), DEFAULT_FLOWRATE, DEFAULT_DISTRIBUTOR, DEFAULT_REFERRER, 1000 ether));
        uint256 uBalanceAfter = IERC20(underlyingToken).balanceOf(alice);
        vm.stopPrank();

        assertEq(uBalanceBefore - uBalanceAfter, underlyingAmount, "wrong underlying token amount after upgrade");
    }

    function testWithMaxUpgradeAmount(uint256 allowance) public {
        // set the floor high enough to avoid failure due to insufficient funds for buffer and backcharging
        vm.assume(allowance > 1000 ether);
        SBMacro m = new SBMacro();

        vm.startPrank(alice);
        address underlyingToken = inToken.getUnderlyingToken();
        IERC20(underlyingToken).approve(address(inToken), allowance);
        uint256 uBalanceBefore = IERC20(underlyingToken).balanceOf(alice);
        macroFwd.runMacro(m, abi.encode(address(torex), DEFAULT_FLOWRATE, DEFAULT_DISTRIBUTOR, DEFAULT_REFERRER, type(uint256).max));
        uint256 uBalanceAfter = IERC20(underlyingToken).balanceOf(alice);
        vm.stopPrank();

        // note that this is underlying token amount, may have different decimals than SuperToken
        // This assertion may fail if the underlying token has MORE decimals than the SuperToken (more than 18!)
        // Since that's a very exotic case and it's a limitation of the test and not of the macro, so be it.
        uint256 expectedUpgradedAmount = Math.min(uBalanceBefore, allowance);
        assertEq(uBalanceBefore - uBalanceAfter, expectedUpgradedAmount, "wrong underlying token amount after upgrade");
    }
}
