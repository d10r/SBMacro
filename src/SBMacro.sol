// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.26;

import { ISuperfluid, BatchOperation, IConstantFlowAgreementV1, IGeneralDistributionAgreementV1, ISuperToken, ISuperfluidPool, IERC20 }
    from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IUserDefinedMacro } from "@superfluid-finance/ethereum-contracts/contracts/utils/MacroForwarder.sol";
import { ITorex } from "./interfaces/ITorex.sol";

/**
 * User defined macro for SuperBoring.
 * How to use this contract:
 * - Deploy to a network with Superfluid and the MacroForwarder available
 * - Make a call to the MacroForwarder contract:
 * ```
 * macroFwd.runMacro(sbMacroAddr, abi.encode(torexAddr, flowRate, distributor, referrer, upgradeAmount));
 * ```
 *
 * Macro Arguments:
 * - `torexAddr`: address of the Torex contract. The token address is derived from this (inToken).
 * - `flowRate`: flowrate to be set for the flow to the Torex contract. The pre-existing flowrate must be 0 (no flow).
 * - `distributor`: address of the distributor, or zero address if none.
 * - `referrer`: address of the referrer, or zero address if none.
 * - `upgradeAmount`: amount (18 decimals) to upgrade from underlying to SuperToken.
 *   - if 0, no upgrade is performed.
 *   - if `type(uint256).max`, the maximum possible amount is upgraded (current allowance).
 *   - otherwise, the specified amount is upgraded. Requires sufficient underlying balance and allowance, otherwise the transaction will revert.
 */
contract SBMacro is IUserDefinedMacro {

    /// @dev Invoked by the MacroForwarder contract, with relayed transaction sender
    function buildBatchOperations(ISuperfluid host, bytes memory params, address msgSender)
        external override view
        returns (ISuperfluid.Operation[] memory operations)
    {
        // parse params
        (address torexAddr, int96 flowRate, address distributor, address referrer, uint256 upgradeAmount) =
            abi.decode(params, (address, int96, address, address, uint256));

        // get token address from Torex
        ITorex torex = ITorex(torexAddr);
        (ISuperToken inToken,) = torex.getPairedTokens();

        // build batch operations
        operations = new ISuperfluid.Operation[](4);

        // op[0]: upgrade
        if (upgradeAmount == type(uint256).max) {
            IERC20 underlyingToken = IERC20(inToken.getUnderlyingToken());
            uint256 underlyingUpgradeAmount = Math.min(
                underlyingToken.balanceOf(msgSender),
                underlyingToken.allowance(msgSender, address(inToken))
            );
            (upgradeAmount,) = _fromUnderlyingAmount(inToken, underlyingUpgradeAmount);
        }
        operations[0] = ISuperfluid.Operation({
            operationType : BatchOperation.OPERATION_TYPE_SUPERTOKEN_UPGRADE,
            target: address(inToken),
            data: abi.encode(upgradeAmount)
        });

        // op[1]: approve Torex to use SuperToken
        operations[1] = ISuperfluid.Operation({
            operationType : BatchOperation.OPERATION_TYPE_ERC20_APPROVE,
            target: address(inToken),
            data: abi.encode(
                address(torex),
                torex.estimateApprovalRequired(flowRate)
            )
        });

        // op[2]: create flow
        {
            IConstantFlowAgreementV1 cfa = IConstantFlowAgreementV1(address(host.getAgreementClass(
                keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
            )));
            operations[2] = ISuperfluid.Operation({
                operationType : BatchOperation.OPERATION_TYPE_SUPERFLUID_CALL_AGREEMENT,
                target: address(cfa),
                data: abi.encode(
                    abi.encodeCall(
                        cfa.createFlow,
                        (
                            inToken,
                            address(torex), // receiver
                            flowRate,
                            new bytes(0) // ctx
                        )
                    ), // calldata
                    abi.encode(distributor, referrer) // userdata
                )
            });
        }

        // op[3]: connect outTokenDistributionPool
        {
            IGeneralDistributionAgreementV1 gda = IGeneralDistributionAgreementV1(address(host.getAgreementClass(
                keccak256("org.superfluid-finance.agreements.GeneralDistributionAgreement.v1")
            )));
            ISuperfluidPool outTokenDistributionPool = torex.outTokenDistributionPool();
            operations[3] = ISuperfluid.Operation({
                operationType : BatchOperation.OPERATION_TYPE_SUPERFLUID_CALL_AGREEMENT,
                target: address(gda),
                data: abi.encode(
                    abi.encodeCall(
                        gda.connectPool,
                        (
                            outTokenDistributionPool,
                            new bytes(0) // ctx
                        )
                    ), // calldata
                    new bytes(0) // userdata
                )
            });
        }

        return operations;
    }

    uint8 private constant _STANDARD_DECIMALS = 18;
    // this should be in SuperToken.sol
    function _fromUnderlyingAmount(ISuperToken superToken, uint256 amount)
        private view
        returns (uint256 superTokenAmount, uint256 adjustedAmount)
    {
        uint256 factor;
        uint8 _underlyingDecimals = superToken.getUnderlyingDecimals();
        if (_underlyingDecimals < _STANDARD_DECIMALS) {
            factor = 10 ** (_STANDARD_DECIMALS - _underlyingDecimals);
            superTokenAmount = amount * factor;
            adjustedAmount = amount;
        } else if (_underlyingDecimals > _STANDARD_DECIMALS) {
            factor = 10 ** (_underlyingDecimals - _STANDARD_DECIMALS);
            superTokenAmount = amount / factor;
            adjustedAmount = superTokenAmount * factor;
        } else {
            superTokenAmount = adjustedAmount = amount;
        }
    }
}