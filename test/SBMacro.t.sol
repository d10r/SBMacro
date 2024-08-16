// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ISuperfluid, ISuperToken, IERC20, ISuperfluidPool }
    from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { MacroForwarder } from "@superfluid-finance/ethereum-contracts/contracts/utils/MacroForwarder.sol";
import { ITorex } from "../src/interfaces/ITorex.sol";
import { SBMacro } from "../src/SBMacro.sol";

// fork test
contract SBMacroTest is Test {
    ISuperfluid host;
    ITorex torex;
    ISuperToken inToken;
    MacroForwarder macroFwd;
    address alice = address(0x721);

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
        deal(underlyingToken, alice, 1000 ether);
        vm.startPrank(alice);
        IERC20(underlyingToken).approve(address(inToken), type(uint256).max);
        inToken.upgrade(1000 ether);
        vm.stopPrank();
    }

    function testMacro() external {
        int96 flowRate = 42e15;
        address distributor = address(0x69);
        address referrer = address(0x70);
        SBMacro m = new SBMacro();

        vm.startPrank(alice);
        macroFwd.runMacro(m, abi.encode(address(torex), flowRate, distributor, referrer));
        vm.stopPrank();

        // what do we expect? outTokenPool units
        ISuperfluidPool outTokenDistributionPool = torex.outTokenDistributionPool();
        assertGt(outTokenDistributionPool.getUnits(alice), 0, "no outTokenDistributionPool units assigned");

        // TODO: verify distributor, referrer
    }
}
