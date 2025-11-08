// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDecisionGraph {
    function addNode(uint256 proposalId, string calldata conclusion, uint256 voteWeight, uint256 timestamp) external returns (uint256 nodeId);
    function addEdge(uint256 fromNode, uint256 toNode, uint256 weight) external returns (bool success);
    function getNodePriority(uint256 nodeId) external view returns (uint256 priority);
    function isModerator(address user) external view returns (bool);
}