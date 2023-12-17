const hre = require("hardhat")

async function main() {
  const MyCNS = await hre.ethers.getContractFactory("CNSRegistry")
  const myCNS = await MyCNS.deploy()

  await myCNS.deployed()

  console.log("MyNFT deployed to:", myCNS.address)
  storeContractData(myCNS)
}
//function to store contract data in the src folder, source data include the abi and contract addresss
function storeContractData(contract) {
  const fs = require("fs")
  const contractsDir = __dirname + "/../src/contracts"

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir)
  }

  fs.writeFileSync(
    contractsDir + "/MyNFT-address.json",
    JSON.stringify({ MyNFT: contract.address }, undefined, 2)
  )

  const CNSRegistryArtifact = artifacts.readArtifactSync("CNSRegistry")

  fs.writeFileSync(
    contractsDir + "/MyNFT.json",
    JSON.stringify(CNSRegistryArtifact, null, 2)
  )
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
