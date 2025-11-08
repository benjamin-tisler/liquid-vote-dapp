// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidVote.sol";  // Import za klic nazaj

contract DecisionGraph is Ownable {
    struct Node {
        uint256 id;
        string conclusion;
        uint256 voteWeight;
        uint256 timestamp;
        uint256 priority;  // Dinamično izračunana
    }

    struct Edge {
        uint256 from;
        uint256 to;
        uint256 weight;  // 0-1000 (scaled 0-1)
    }

    mapping(uint256 => Node) public nodes;
    mapping(uint256 => Edge[]) public edges;  // from => array of edges
    mapping(address => bool) public moderators;
    uint256 public nextNodeId = 1;

    LiquidVote public liquidVote;  // Naslov povezanega glasovanja
    uint256 public constant MAX_EDGES_PER_NODE = 50;
    uint256 public constant DAMPING_FACTOR = 850;  // Za PageRank (0.85 * 1000)

    event NodeAdded(uint256 indexed nodeId, string conclusion, uint256 voteWeight);
    event EdgeAdded(uint256 indexed from, uint256 indexed to, uint256 weight);
    event ModeratorElected(address indexed moderator);

    modifier onlyModerator() {
        require(moderators[msg.sender] || owner() == msg.sender, "Not moderator");
        _;
    }

    constructor(address _liquidVote) Ownable(msg.sender) {
        require(_liquidVote != address(0), "Invalid LiquidVote address");  // Validacija
        liquidVote = LiquidVote(_liquidVote);
    }

    // Dodaj vozlišče (kliče ga LiquidVote)
    function addNode(
        uint256 proposalId,
        string calldata conclusion,
        uint256 voteWeight,
        uint256 timestamp
    ) external returns (uint256 nodeId) {
        require(msg.sender == address(liquidVote), "Only LiquidVote can add nodes");  // Validacija
        require(proposalId > 0, "Invalid proposal ID");  // Validacija
        require(bytes(conclusion).length > 0 && bytes(conclusion).length <= 500, "Invalid conclusion");  // Validacija
        require(voteWeight > 0, "Invalid vote weight");  // Validacija
        require(timestamp > 0 && timestamp <= block.timestamp, "Invalid timestamp");  // Validacija

        nodeId = nextNodeId++;
        Node storage n = nodes[nodeId];
        n.id = nodeId;
        n.conclusion = conclusion;
        n.voteWeight = voteWeight;
        n.timestamp = timestamp;
        n.priority = calculateInitialPriority(voteWeight, timestamp);

        emit NodeAdded(nodeId, conclusion, voteWeight);
        return nodeId;
    }

    // Dodaj rob (meta-glasovanje)
    function addEdge(uint256 from, uint256 to, uint256 weight) external onlyModerator returns (bool) {
        require(from > 0 && from < nextNodeId, "Invalid from node");  // Validacija
        require(to > 0 && to < nextNodeId && to != from, "Invalid to node");  // Validacija
        require(weight <= 1000 && weight >= 0, "Weight out of bounds");  // Validacija
        require(edges[from].length < MAX_EDGES_PER_NODE, "Too many edges");

        edges[from].push(Edge(from, to, weight));
        
        // Posodobi prioritete prizadetih vozlišč
        updatePriority(to);
        updatePriority(from);

        emit EdgeAdded(from, to, weight);
        return true;
    }

    // Izvoli moderatorja (prek uteži iz LiquidVote)
    function electModerator(address candidate) external onlyOwner {
        require(candidate != address(0), "Invalid candidate");  // Validacija
        require(liquidVote.calculateEffectiveWeight(candidate, 0) > 5, "Insufficient weight");
        moderators[candidate] = true;
        emit ModeratorElected(candidate);
    }

    // Izračunaj začetno prioriteto
    function calculateInitialPriority(uint256 voteWeight, uint256 timestamp) internal view returns (uint256) {
        require(voteWeight > 0, "Invalid voteWeight");  // Validacija (čeprav internal)
        uint256 freshness = calculateFreshness(timestamp);
        return (voteWeight * 400 + freshness * 300) / 1000;  // Popravek: Dodana svežina
    }

    // Posodobi prioriteto (PageRank-like, poenostavljeno)
    function updatePriority(uint256 nodeId) public {
        require(nodeId > 0 && nodeId < nextNodeId, "Invalid node ID");  // Validacija
        uint256 pagerank = 100;  // Base
        // Iteriraj nad vhodnimi robovi (poenostavljeno, omejeno za gas)
        for (uint256 i = 1; i <= nextNodeId && i < 100; i++) {  // Omejitev za gas
            if (i == nodeId) continue;
            for (uint256 j = 0; j < edges[i].length; j++) {
                if (edges[i][j].to == nodeId) {
                    pagerank += (nodes[i].priority * edges[i][j].weight) / 1000;
                }
            }
        }
        pagerank = (pagerank * DAMPING_FACTOR) / 1000 + 100;

        Node storage n = nodes[nodeId];
        n.priority = (n.voteWeight * 400 + pagerank * 300 + calculateFreshness(n.timestamp) * 300) / 1000;
    }

    function calculateFreshness(uint256 timestamp) internal view returns (uint256) {
        require(timestamp > 0, "Invalid timestamp");  // Validacija
        uint256 daysOld = (block.timestamp - timestamp) / 1 days;
        return (daysOld < 365) ? (1000 - (daysOld * 1000 / 365)) : 0;
    }

    // Getter za prioriteto
    function getNodePriority(uint256 nodeId) external view returns (uint256) {
        require(nodeId > 0 && nodeId < nextNodeId, "Invalid node ID");  // Validacija
        return nodes[nodeId].priority;
    }

    // Preveri moderatorja
    function isModerator(address user) external view returns (bool) {
        require(user != address(0), "Invalid user");  // Validacija
        return moderators[user];
    }
}