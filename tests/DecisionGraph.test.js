const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DecisionGraph", function () {
  let decisionGraph, liquidVote, owner, moderator;

  beforeEach(async function () {
    [owner, moderator] = await ethers.getSigners();

    // Deploy LiquidVote (dummy za test)
    const LiquidVote = await ethers.getContractFactory("LiquidVote");
    liquidVote = await LiquidVote.deploy(ethers.ZeroAddress);  // Dummy
    await liquidVote.waitForDeployment();

    // Deploy DecisionGraph
    const DecisionGraph = await ethers.getContractFactory("DecisionGraph");
    decisionGraph = await DecisionGraph.deploy(await liquidVote.getAddress());
    await decisionGraph.waitForDeployment();

    // Izvoli moderatorja
    await decisionGraph.electModerator(moderator.address);
  });

  describe("Node Addition", function () {
    it("Should add node (simulirano iz LiquidVote)", async function () {
      // Simuliraj klic iz LiquidVote
      const nodeId = await decisionGraph.addNode(1, "Test Conclusion", 100, Math.floor(Date.now() / 1000));
      expect(await decisionGraph.nodes(nodeId)).to.not.be.null;
      expect(await decisionGraph.getNodePriority(nodeId)).to.be.gt(0);
    });

    it("Should revert if not from LiquidVote", async function () {
      await expect(decisionGraph.addNode(1, "Test", 100, Math.floor(Date.now() / 1000))).to.be.revertedWith("Only LiquidVote can add nodes");
    });
  });

  describe("Edge Addition", function () {
    it("Should add edge by moderator", async function () {
      await decisionGraph.connect(moderator).addEdge(1, 2, 500);
      expect(await decisionGraph.edges(1)).to.have.length(1);
    });

    it("Should revert if not moderator", async function () {
      await expect(decisionGraph.addEdge(1, 2, 500)).to.be.revertedWith("Not moderator");
    });
  });

  describe("Priority Calculation", function () {
    it("Should calculate priority", async function () {
      const timestamp = Math.floor(Date.now() / 1000);
      const nodeId = await decisionGraph.addNode(1, "Test", 1000, timestamp);  // Simulirano
      expect(await decisionGraph.getNodePriority(nodeId)).to.be.approximately(700, 100);  // Približno
    });
  });
});