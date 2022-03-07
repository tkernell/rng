// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface IAutopay {
    function tip(
        address _token,
        bytes32 _queryId,
        uint256 _amount,
        bytes calldata _queryData
    ) external;
}
