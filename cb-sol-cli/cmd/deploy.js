const ethers = require('ethers');
const {Command} = require('commander');
const crypto = require("crypto");
const constants = require('../constants');
const {setupParentArgs, splitCommaList, isValidAddress} = require("./utils")

const deployCmd = new Command("deploy")
    .description("Deploys contracts via RPC")
    .option('--chainId <value>', 'Chain ID for the instance', constants.DEFAULT_SOURCE_ID)
    .option('--relayers <value>', 'List of initial relayers', splitCommaList, constants.relayerAddresses)
    .option('--relayerThreshold <value>', 'Number of votes required for a proposal to pass', 2)
    .option('--fee <ether>', 'Fee to be taken when making a deposit (decimals allowed)', 0)
    .option('--expiry <blocks>', 'Numer of blocks after which a proposal is considered cancelled', 100)
    .option('--all', 'Deploy all contracts')
    .option('--bridge', 'Deploy bridge contract')
    .option('--erc20Handler', 'Deploy erc20Handler contract')
    .option('--erc721Handler', 'Deploy erc721Handler contract')
    .option('--erc1155Handler', 'Deploy erc1155Handler contract')
    .option('--rollupHandler', 'Deploy rollupHandler contract')
    .option('--genericHandler', 'Deploy genericHandler contract')
    .option('--bridgeAddress <address>', 'Bridge contract address for independent handler deployment', "")
    .option('--erc20', 'Deploy erc20 contract')
    .option('--erc20Symbol <symbol>', 'Name for the erc20 contract', "")
    .option('--erc20Name <name>', 'Symbol for the erc20 contract', "")
    .option('--erc20Decimals <amount>', 'Decimals for erc20 contract', 18)
    .option('--erc721', 'Deploy erc721 contract')
    .option('--erc721Symbol <symbol>', 'Name for the erc721 contract', "")
    .option('--erc721Name <name>', 'Symbol for the erc721 contract', "")
    .option('--erc721BaseUri <uri>', 'Base URI for the erc721 contract', "")
    .option('--erc1155', 'Deploy erc1155 contract')
    .option('--erc1155Symbol <symbol>', 'Name for the erc1155 contract', "")
    .option('--erc1155Name <name>', 'Symbol for the erc1155 contract', "")
    .option('--erc1155BaseUri <uri>', 'Base URI for the erc1155 contract', "")
    .option('--rollupExample', 'Deploy rollupExample contract')
    .option('--rollupResourceID <resourceID>', 'resource for RollupExample contract', "")
    .option('--centAsset', 'Deploy centrifuge asset contract')
    .option('--wetc', 'Deploy wrapped ETC Erc20 contract')
    .option('--config', 'Logs the configuration based on the deployment', false)
    .action(async (args) => {
        await setupParentArgs(args, args.parent)
        let startBal = await args.provider.getBalance(args.wallet.address)
        console.log("Deploying contracts...")
        if(args.all) {
            await deployBridgeContract(args);
            await deployERC20Handler(args);
            await deployERC721Handler(args);
            await deployRollupHandler(args);
            await deployGenericHandler(args);
            await deployERC20(args);
            await deployERC721(args);
            await deployERC1155(args);
            await deployRollupExample(args);
        } else {
            let deployed = false
            if (args.bridge) {
                await deployBridgeContract(args);
                deployed = true
            }
            if (args.erc20Handler) {
                await deployERC20Handler(args);
                deployed = true
            }
            if (args.erc721Handler) {
                await deployERC721Handler(args)
                deployed = true
            }
            if (args.erc1155Handler) {
                await deployERC1155Handler(args)
                deployed = true
            }
            if (args.rollupHandler) {
                await deployRollupHandler(args)
                deployed = true
            }
            if (args.genericHandler) {
                await deployGenericHandler(args)
                deployed = true
            }
            if (args.erc20) {
                await deployERC20(args)
                deployed = true
            }
            if (args.erc721) {
                await deployERC721(args)
                deployed = true
            }
            if (args.erc1155) {
                await deployERC1155(args)
                deployed = true
            }
            if (args.rollupExample) {
                await deployRollupExample(args)
                deployed = true
            }
            if (args.centAsset) {
                await deployCentrifugeAssetStore(args);
                deployed = true
            }
            if (args.wetc) {
                await deployWETC(args)
                deployed = true
            }

            if (!deployed) {
                throw new Error("must specify --all or specific contracts to deploy")
            }
        }

        args.cost = startBal.sub((await args.provider.getBalance(args.wallet.address)))
        displayLog(args)
        if (args.config) {
            createConfig(args)
        }
    })

const createConfig = (args) => {
    const config = {};
    config.name = "eth";
    config.chainId = args.chainId;
    config.endpoint = args.url;
    config.bridge = args.bridgeAddress;
    config.erc20Handler = args.erc20HandlerContract;
    config.erc721Handler = args.erc721HandlerContract;
    config.erc1155Handler = args.erc1155HandlerContract;
    config.genericHandler = args.genericHandlerContract;
    config.rollupHandler = args.rollupHandlerContract;
    config.gasLimit = args.gasLimit.toNumber();
    config.maxGasPrice = args.gasPrice.toNumber();
    config.startBlock = "0"
    config.http = "false"
    config.relayers = args.relayers;
    const data = JSON.stringify(config, null, 4);
    console.log("EVM Configuration, please copy this into your ChainBridge config file:")
    console.log(data)
}

const displayLog = (args) => {
    console.log(`
================================================================
Url:        ${args.url}
Deployer:   ${args.wallet.address}
Gas Limit:   ${ethers.utils.bigNumberify(args.gasLimit)}
Gas Price:   ${ethers.utils.bigNumberify(args.gasPrice)}
Deploy Cost: ${ethers.utils.formatEther(args.cost)}

Options
=======
Chain Id:    ${args.chainId}
Threshold:   ${args.relayerThreshold}
Relayers:    ${args.relayers}
Bridge Fee:  ${args.fee}
Expiry:      ${args.expiry}

Contract Addresses
================================================================
Bridge:             ${args.bridgeAddress ? args.bridgeAddress : "Not Deployed"}
----------------------------------------------------------------
Erc20 Handler:      ${args.erc20HandlerContract ? args.erc20HandlerContract : "Not Deployed"}
----------------------------------------------------------------
Erc721 Handler:     ${args.erc721HandlerContract? args.erc721HandlerContract : "Not Deployed"}
----------------------------------------------------------------
Erc1155 Handler:    ${args.erc1155HandlerContract? args.erc1155HandlerContract : "Not Deployed"}
----------------------------------------------------------------
Rollup Handler:     ${args.rollupHandlerContract? args.rollupHandlerContract : "Not Deployed"}
----------------------------------------------------------------
Generic Handler:    ${args.genericHandlerContract ? args.genericHandlerContract : "Not Deployed"}
----------------------------------------------------------------
Erc20:              ${args.erc20Contract ? args.erc20Contract : "Not Deployed"}
----------------------------------------------------------------
Erc721:             ${args.erc721Contract ? args.erc721Contract : "Not Deployed"}
----------------------------------------------------------------
Erc1155:            ${args.erc1155Contract ? args.erc1155Contract : "Not Deployed"}
----------------------------------------------------------------
RollupExample:      ${args.rollupExampleContract ? args.rollupExampleContract : "Not Deployed"}
ResourceID:         ${args.rollupExampleResourceID ? args.rollupExampleResourceID : "Not Deployed"}
----------------------------------------------------------------
Centrifuge Asset:   ${args.centrifugeAssetStoreContract ? args.centrifugeAssetStoreContract : "Not Deployed"}
----------------------------------------------------------------
WETC:               ${args.WETCContract ? args.WETCContract : "Not Deployed"}
================================================================
        `)
}


async function deployBridgeContract(args) {
    // Create an instance of a Contract Factory
    let factory = new ethers.ContractFactory(constants.ContractABIs.Bridge.abi, constants.ContractABIs.Bridge.bytecode, args.wallet);

    // Deploy
    let contract = await factory.deploy(
        args.chainId,
        args.relayers,
        args.relayerThreshold,
        ethers.utils.parseEther(args.fee.toString()),
        args.expiry,
        { gasPrice: args.gasPrice, gasLimit: args.gasLimit}
    );
    await contract.deployed();
    args.bridgeAddress = contract.address
    console.log("✓ Bridge contract deployed")
}

async function deployERC20(args) {
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc20Mintable.abi, constants.ContractABIs.Erc20Mintable.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress, args.erc20Name, args.erc20Symbol, args.erc20Decimals, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc20Contract = contract.address
    console.log("✓ ERC20 contract deployed")
}

async function deployRollupExample(args) {
    if (!args.rollupResourceID) {
        args.rollupResourceID = "0x" + crypto.randomBytes(32).toString('hex');
    }
    console.log(args.rollupResourceID, !args.rollupResourceID);
    const factory = new ethers.ContractFactory(constants.ContractABIs.RollupExample.abi, constants.ContractABIs.RollupExample.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.rollupExampleContract = contract.address;
    args.rollupExampleResourceID = args.rollupResourceID;
    console.log("✓ RollupExample contract deployed")
}

async function deployERC20Handler(args) {
    if (!isValidAddress(args.bridgeAddress)) {
        console.log("ERC20Handler contract failed to deploy due to invalid bridge address")
        return
    }
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc20Handler.abi, constants.ContractABIs.Erc20Handler.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc20HandlerContract = contract.address
    console.log("✓ ERC20Handler contract deployed")
}

async function deployRollupHandler(args) {
    if (!isValidAddress(args.bridgeAddress)) {
        console.log("RollupHandler contract failed to deploy due to invalid bridge address")
        return
    }
    const factory = new ethers.ContractFactory(constants.ContractABIs.RollupHandler.abi, constants.ContractABIs.RollupHandler.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.rollupHandlerContract = contract.address
    console.log("✓ RollupHandler contract deployed")
}

async function deployERC721(args) {
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc721Mintable.abi, constants.ContractABIs.Erc721Mintable.bytecode, args.wallet);
    const contract = await factory.deploy(args.erc721Name, args.erc721Symbol, args.erc721BaseUri, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc721Contract = contract.address
    console.log("✓ ERC721 contract deployed")
}

async function deployERC721Handler(args) {
    if (!isValidAddress(args.bridgeAddress)) {
        console.log("ERC721Handler contract failed to deploy due to invalid bridge address")
        return
    }
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc721Handler.abi, constants.ContractABIs.Erc721Handler.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress,{ gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc721HandlerContract = contract.address
    console.log("✓ ERC721Handler contract deployed")
}

async function deployERC1155(args) {
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc1155Mintable.abi, constants.ContractABIs.Erc1155Mintable.bytecode, args.wallet);
    const contract = await factory.deploy(args.erc1155Name, args.erc1155Symbol, args.erc1155BaseUri, { gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc1155Contract = contract.address
    console.log("✓ ERC1155 contract deployed")
}

async function deployERC1155Handler(args) {
    if (!isValidAddress(args.bridgeAddress)) {
        console.log("ERC1155Handler contract failed to deploy due to invalid bridge address")
        return
    }
    const factory = new ethers.ContractFactory(constants.ContractABIs.Erc1155Handler.abi, constants.ContractABIs.Erc1155Handler.bytecode, args.wallet);
    const contract = await factory.deploy(args.bridgeAddress,{ gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.erc1155HandlerContract = contract.address
    console.log("✓ ERC1155Handler contract deployed")
}

async function deployGenericHandler(args) {
    if (!isValidAddress(args.bridgeAddress)) {
        console.log("GenericHandler contract failed to deploy due to invalid bridge address")
        return
    }
    const factory = new ethers.ContractFactory(constants.ContractABIs.GenericHandler.abi, constants.ContractABIs.GenericHandler.bytecode, args.wallet)
    const contract = await factory.deploy(args.bridgeAddress, { gasPrice: args.gasPrice, gasLimit: args.gasLimit})
    await contract.deployed();
    args.genericHandlerContract = contract.address
    console.log("✓ GenericHandler contract deployed")
}

async function deployCentrifugeAssetStore(args) {
    const factory = new ethers.ContractFactory(constants.ContractABIs.CentrifugeAssetStore.abi, constants.ContractABIs.CentrifugeAssetStore.bytecode, args.wallet);
    const contract = await factory.deploy({ gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.centrifugeAssetStoreContract = contract.address
    console.log("✓ CentrifugeAssetStore contract deployed")
}

async function deployWETC(args) {
    const factory = new ethers.ContractFactory(constants.ContractABIs.WETC.abi, constants.ContractABIs.WETC.bytecode, args.wallet);
    const contract = await factory.deploy({ gasPrice: args.gasPrice, gasLimit: args.gasLimit});
    await contract.deployed();
    args.WETCContract = contract.address
    console.log("✓ WETC contract deployed")
}

module.exports = deployCmd
