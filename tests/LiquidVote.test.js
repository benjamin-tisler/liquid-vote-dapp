const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidVote", function () {
  let liquidVote, decisionGraph, owner, user1, user2, governance;

  beforeEach(async function () {
    [owner, user1, user2, governance] = await ethers.getSigners();

    // Deploy DecisionGraph
    const DecisionGraph = await ethers.getContractFactory("DecisionGraph");
    decisionGraph = await DecisionGraph.deploy(owner.address);
    await decisionGraph.waitForDeployment();

    // Deploy LiquidVote
    const LiquidVote = await ethers.getContractFactory("LiquidVote");
    liquidVote = await LiquidVote.deploy(await decisionGraph.getAddress());
    await liquidVote.waitForDeployment();

    // Dodaj governance
    await liquidVote.addGovernanceMember(governance.address);
  });

  describe("Deployment", function () {
    it("Should set the right decisionGraph", async function () {
      expect(await liquidVote.decisionGraph()).to.equal(await decisionGraph.getAddress());
    });
  });

  describe("Proposal Creation", function () {
    it("Should create a proposal", async function () {
      const tx = await liquidVote.createProposal("Test Proposal");
      await tx.wait();
      const proposalId = 1;
      expect(await liquidVote.proposalOwner(proposalId)).to.equal(owner.address);
      expect(await liquidVote.proposals(proposalId)).to.not.be.null;
    });

    it("Should revert with invalid description", async function () {
      await expect(liquidVote.createProposal("")).to.be.revertedWith("Invalid description");
    });
  });

  describe("Voting", function () {
    it("Should allow voting with weight", async function () {
      await liquidVote.connect(governance).addTrust(user1.address);  // Dodaj trust

      const tx = await liquidVote.createProposal("Test");
      const proposalId = 1;
      await tx.wait();

      const voteTx = await liquidVote.connect(user1).castVote(proposalId, true);
      await voteTx.wait();

      expect(await liquidVote.hasVoted(user1.address, proposalId)).to.be.true;
    });

    it("Should calculate effective weight correctly", async function () {
      await liquidVote.connect(governance).addTrust(user1.address);
      expect(await liquidVote.calculateEffectiveWeight(user1.address, 0)).to.equal(2);  // base 1 + trust 1
    });

    it("Should revert if already voted", async function () {
      const tx = await liquidVote.createProposal("Test");
      const proposalId = 1;
      await tx.wait();

      await liquidVote.connect(user1).castVote(proposalId, true);
      await expect(liquidVote.connect(user1).castVote(proposalId, false)).to.be.revertedWith("Already voted");
    });
  });

  describe("Delegation", function () {
    it("Should set delegation", async function () {
      await liquidVote.connect(user1).setDelegation(0, user2.address);  // Splošna
      expect(await liquidVote.users(user1.address)).to.not.be.null;
    });

    it("Should revert invalid delegate", async function () {
      await expect(liquidVote.connect(user1).setDelegation(0, ethers.ZeroAddress)).to.be.revertedWith("Invalid delegate");
    });
  });

  describe("Finalize", function () {
    it("Should finalize after delay", async function () {
      // Uporabi hardhat network za napredovanje časa
      const tx = await liquidVote.createProposal("Test");
      const proposalId = 1;
      await tx.wait();

      // Glasuj
      await liquidVote.connect(user1).castVote(proposalId, true);

      // Napreduj čas mimo endTime + delay
      await ethers.provider.send("evm_increaseTime", [4 * 24 * 60 * 60]);  // 4 dni
      await ethers.provider.send("evm_mine");

      await expect(liquidVote.finalizeProposal(proposalId)).to.emit(liquidVote, "DecisionAddedToGraph");
    });

    it("Should revert before delay", async function () {
      const tx = await liquidVote.createProposal("Test");
      const proposalId = 1;
      await tx.wait();

      await ethers.provider.send("evm_increaseTime", [3 * 24 * 60 * 60]);  // 3 dni (samo endTime)
      await ethers.provider.send("evm_mine");

      await expect(liquidVote.finalizeProposal(proposalId)).to.be.revertedWith("Finalize delay not passed");
    });
  });

  describe("Governance and Trust", function () {
    it("Should add trust only by governance", async function () {
      await liquidVote.connect(governance).addTrust(user1.address);
      expect(await liquidVote.users(user1.address)).to.have.property("trustScore", 1);

      await expect(liquidVote.connect(user1).addTrust(user2.address)).to.be.revertedWith("Not governance member");
    });
  });
});