// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { ISuperfluid, BatchOperation, IConstantFlowAgreementV1, IGeneralDistributionAgreementV1, ISuperToken, ISuperfluidPool }
    from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IUserDefinedMacro } from "@superfluid-finance/ethereum-contracts/contracts/utils/MacroForwarder.sol";
import { ITorex } from "./interfaces/ITorex.sol";

/**
 * TODO:
 * - check if there's a free slot before connectPool()
 * - shall we also connect boringPool (for the future, when the pods are abandoned)?
 */
contract SBMacro is IUserDefinedMacro {

    function buildBatchOperations(ISuperfluid host, bytes memory params, address /*msgSender*/)
        external override view
        returns (ISuperfluid.Operation[] memory operations)
    {
        // parse params
        (address torexAddr, int96 flowRate, address distributor, address referrer) =
            abi.decode(params, (address, int96, address, address));

        IConstantFlowAgreementV1 cfa = IConstantFlowAgreementV1(address(host.getAgreementClass(
            keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
        )));
        IGeneralDistributionAgreementV1 gda = IGeneralDistributionAgreementV1(address(host.getAgreementClass(
            keccak256("org.superfluid-finance.agreements.GeneralDistributionAgreement.v1")
        )));

        ITorex torex = ITorex(torexAddr);

        (ISuperToken inToken,) = torex.getPairedTokens();

        // 1.1 approval for backcharging
        ISuperfluid.Operation memory approveTorexOp = ISuperfluid.Operation({
            operationType : BatchOperation.OPERATION_TYPE_ERC20_APPROVE,
            target: address(inToken),
            data: abi.encode(
                address(torex),
                torex.estimateApprovalRequired(flowRate)
            )
        });

        // 1.2 create flow
        ISuperfluid.Operation memory createFlowOp = ISuperfluid.Operation({
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

        // 2. connect pools
        // 2.1 outTokenDistributionPool
        ISuperfluidPool outTokenDistributionPool = torex.outTokenDistributionPool();
        ISuperfluid.Operation memory connectOutTokenDistributionPoolOp = ISuperfluid.Operation({
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

        // construct batch operations
        operations = new ISuperfluid.Operation[](3);

        operations[0] = approveTorexOp;
        operations[1] = createFlowOp;
        operations[2] = connectOutTokenDistributionPoolOp;

        return operations;
    }
}