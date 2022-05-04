const {Command} = require('commander');
const constants = require('../constants');
const ethers = require('ethers');
const {setupParentArgs, waitForTx, log, expandDecimals} = require("./utils")

const transferCmd = new Command("transfer")
    .description("execute transfer on rollupExample")
    .option('--token <value>', 'TokenId to transfer', 10)
    .option('--recipient <address>', 'Recipient', "")
    .option('--rollupExample <address>', 'RollupExample contract address', "")
    .action(async function (args) {
        await setupParentArgs(args, args.parent.parent)

        const exampleInstance = new ethers.Contract(args.rollupExample, constants.ContractABIs.RollupExample.abi, args.wallet);
        let recipient = args.recipient;
        if (recipient == "") {
            recipient = args.wallet.address;
        }
        log(args, `transfer tokens(${args.token}) to ${recipient} on contract ${args.rollupExample}`);
        const tx = await exampleInstance.transfer(args.token, recipient);
        await waitForTx(args.provider, tx.hash);
    })

const subRollupCmd = new Command("rollup")
    .description("trigger rollup")
    .option('--rollupExample <address>', 'RollupExample contract address', "")
    .option('--batch <batch>', 'RollupExample contract address', 100)
    .option('--destDomainId <domainId>', 'RollupExample contract address', 0)
    .option('--resourceID <resourceID>', 'resourceID', "")
    .action(async function (args) {
        await setupParentArgs(args, args.parent.parent)

        const exampleInstance = new ethers.Contract(args.rollupExample, constants.ContractABIs.RollupExample.abi, args.wallet);
        const tx = await exampleInstance.rollupToOtherChain(args.destDomainId, args.resourceID, args.batch);
        await waitForTx(args.provider, tx.hash);
    })

const rollupCmd = new Command("rollup")
    .option('-d, decimals <number>', "The number of decimal places for the erc20 token", 18)
    
rollupCmd.addCommand(transferCmd)
rollupCmd.addCommand(subRollupCmd)

module.exports = rollupCmd