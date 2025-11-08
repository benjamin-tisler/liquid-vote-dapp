// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDecisionGraph.sol";

contract LiquidVote is Ownable {
    struct Proposal {
        uint256 id;
        string description;
        bool isActive;
        uint256 endTime;
        uint256 totalWeight;
        mapping(bool => uint256) votes;  // true=DA, false=NE
        uint256 finalizeDelay;  // Dodano: Zakasnitev pred finalizacijo
    }

    struct User {
        uint256 baseWeight;
        uint256 trustScore;
        mapping(uint256 => address) delegations;  // proposalId => delegate
        uint256 lastActive;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => User) public users;
    mapping(uint256 => address) public proposalOwner;  // Kdo je vložil predlog
    mapping(address => bool) public governanceMembers;  // Dodano: Člani governance za addTrust
    mapping(address => mapping(uint256 => bool)) public hasVoted;  // Dodano: Preverba glasovanja

    IDecisionGraph public decisionGraph;  // Naslov povezanega grafa
    uint256 public nextProposalId = 1;
    uint256 public constant MIN_WEIGHT = 1;
    uint256 public constant MAX_TRUST = 10;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant FINALIZE_DELAY = 1 days;  // Dodano: 24-urni delay

    event ProposalCreated(uint256 indexed id, string description, uint256 endTime);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool vote, uint256 effectiveWeight);
    event DelegationSet(address indexed delegator, uint256 indexed proposalId, address delegate);
    event DecisionAddedToGraph(uint256 indexed proposalId, uint256 indexed nodeId);
    event TrustAdded(address indexed user, uint256 newScore);  // Dodano: Event za trust
    event GovernanceMemberAdded(address indexed member);  // Dodano: Event za governance

    modifier onlyActiveProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId < nextProposalId, "Invalid proposal ID");  // Validacija
        require(proposals[proposalId].isActive, "Proposal not active");
        _;
    }

    modifier onlyGovernance() {  // Dodano: Modifier za governance
        require(governanceMembers[msg.sender], "Not governance member");
        _;
    }

    constructor(address _decisionGraph) Ownable(msg.sender) {
        require(_decisionGraph != address(0), "Invalid DecisionGraph address");  // Validacija
        decisionGraph = IDecisionGraph(_decisionGraph);
    }

    // Ustvari nov predlog
    function createProposal(string calldata _description) external returns (uint256) {
        require(bytes(_description).length > 0 && bytes(_description).length <= 1000, "Invalid description");  // Validacija
        uint256 proposalId = nextProposalId++;
        Proposal storage p = proposals[proposalId];
        p.id = proposalId;
        p.description = _description;
        p.isActive = true;
        p.endTime = block.timestamp + VOTING_PERIOD;
        p.finalizeDelay = FINALIZE_DELAY;  // Nastavi delay
        proposalOwner[proposalId] = msg.sender;

        emit ProposalCreated(proposalId, _description, p.endTime);
        return proposalId;
    }

    // Nastavi delegacijo (specifično ali splošno)
    function setDelegation(uint256 proposalId, address delegate) external {
        require(delegate != address(0), "Invalid delegate");  // Validacija
        if (proposalId == 0) {  // Splošna delegacija (proposalId=0 pomeni vse)
            users[msg.sender].delegations[0] = delegate;
        } else {
            require(proposalId > 0 && proposalId < nextProposalId, "Invalid proposal ID");  // Validacija
            users[msg.sender].delegations[proposalId] = delegate;
        }
        emit DelegationSet(msg.sender, proposalId, delegate);
    }

    // Izračunaj efektivno utež uporabnika (ITERATIVNA, ne rekurzivna - popravek)
    function calculateEffectiveWeight(address user, uint256 proposalId) public view returns (uint256) {
        require(user != address(0), "Invalid user");  // Validacija
        if (proposalId != 0) require(proposalId < nextProposalId, "Invalid proposal ID");  // Validacija

        User storage u = users[user];
        uint256 base = u.baseWeight + u.trustScore;
        uint256 activity = (block.timestamp - u.lastActive < 365 days) ? 1 : 0;

        // Iterativno zbiranje delegacij (max depth 3 za preprečevanje zank)
        uint256 delegated = 0;
        address current = user;
        uint256 depth = 0;
        mapping(uint256 => address) storage delMap = u.delegations;
        while (depth < 3) {
            uint256 delKey = (proposalId == 0 ? 0 : proposalId);
            address del = delMap[delKey];
            if (del == address(0) || del == current) break;  // Prekini zanko
            current = del;
            User storage delUser = users[current];
            delegated += (delUser.baseWeight + delUser.trustScore) / 2;  // Polovična utež
            delMap = delUser.delegations;  // Posodobi za naslednjo iteracijo
            depth++;
        }

        return base + delegated + activity;
    }

    // Glasuj (en glas na osebo)
    function castVote(uint256 proposalId, bool vote) external onlyActiveProposal(proposalId) {
        require(block.timestamp < proposals[proposalId].endTime, "Voting ended");
        require(!hasVoted[msg.sender][proposalId], "Already voted");  // Dodano: Preverba
        
        uint256 weight = calculateEffectiveWeight(msg.sender, proposalId);
        require(weight >= MIN_WEIGHT, "Insufficient weight");
        
        hasVoted[msg.sender][proposalId] = true;
        proposals[proposalId].votes[vote] += weight;
        proposals[proposalId].totalWeight += weight;
        users[msg.sender].lastActive = block.timestamp;

        emit VoteCast(msg.sender, proposalId, vote, weight);
    }

    // Zaključi glasovanje in dodaj v graf (z dodanim delay)
    function finalizeProposal(uint256 proposalId) external onlyOwner onlyActiveProposal(proposalId) {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.endTime + p.finalizeDelay, "Finalize delay not passed");  // Dodano: Delay
        p.isActive = false;

        uint256 yesVotes = p.votes[true];
        bool passed = (yesVotes * 100) > (p.totalWeight * 50);  // >50%
        string memory conclusion = passed ? "Sprejeto: DA" : "Zavrnjeno: NE";

        uint256 nodeId = decisionGraph.addNode(
            proposalId,
            conclusion,
            p.totalWeight,
            block.timestamp
        );

        emit DecisionAddedToGraph(proposalId, nodeId);
    }

    // Dodaj trust (omejeno na governance)
    function addTrust(address user) external onlyGovernance {  // Spremenjeno: Iz onlyOwner v onlyGovernance
        require(user != address(0), "Invalid user");  // Validacija
        uint256 newScore = users[user].trustScore + 1;
        users[user].trustScore = (newScore > MAX_TRUST) ? MAX_TRUST : newScore;
        emit TrustAdded(user, users[user].trustScore);
    }

    // Dodaj člana governance (samo owner)
    function addGovernanceMember(address member) external onlyOwner {
        require(member != address(0), "Invalid member");  // Validacija
        governanceMembers[member] = true;
        emit GovernanceMemberAdded(member);
    }

    // Getter za rezultat
    function getProposalResult(uint256 proposalId) external view returns (bool passed, uint256 yesPercent) {
        require(proposalId > 0 && proposalId < nextProposalId, "Invalid proposal ID");  // Validacija
        uint256 total = proposals[proposalId].totalWeight;
        if (total == 0) return (false, 0);
        uint256 yes = proposals[proposalId].votes[true];
        passed = yes > total / 2;
        yesPercent = (yes * 100) / total;
    }
}