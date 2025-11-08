const hre = require("hardhat");

async function main() {
  console.log("Deploying contracts...");

  // Deploy DecisionGraph
  const DecisionGraph = await hre.ethers.getContractFactory("DecisionGraph");
  const decisionGraph = await DecisionGraph.deploy();
  await decisionGraph.waitForDeployment();
  console.log("DecisionGraph deployed to:", await decisionGraph.getAddress());

  // Deploy LiquidVote
  const LiquidVote = await hre.ethers.getContractFactory("LiquidVote");
  const liquidVote = await LiquidVote.deploy(await decisionGraph.getAddress());
  await liquidVote.waitForDeployment();
  console.log("LiquidVote deployed to:", await liquidVote.getAddress());

  // Dodaj governance (uporabi deployer kot governance)
  const [deployer] = await hre.ethers.getSigners();
  await liquidVote.addGovernanceMember(deployer.address);
  console.log("Governance member added:", deployer.address);

  console.log("Deployment complete!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});