#!/bin/bash -e

# Usage:
# 	* Deploy bridge + erc20Handler + erc20Token
#     ./cli.sh [ropsten | kovan | bsctestnet] deploy
#	  * collect the address to accounts.sh
#	* Configure Contract
#	  ./cli.sh [ropsten | kovan | bsctestnet] init
#	  * mint erc20 token to test account, approve to erc20Handler
#     * mint erc20 token to erc20Handler
#	  * register resourceID + erc20Token to bridge
#	* Make a deposit
#	  ./cli.sh [ropsten | kovan | bsctestnet] deposit [ropsten | kovan | bsctestnet] ${recipient}
# Example:
#	> ./cli.sh kovan deploy
#	> ./cli.sh bsctestnet deploy
#	> # fill the addresses to accounts.sh 
#	> ./cli.sh kovan init
#	> ./cli.sh bsctestnet init
#	> ./cli.sh kovan deposit bsctestnet ${recipient address}

source ./env.sh

export THRESHOLD=1
export GAS_PRICE=40000000000
export GAS_LIMIT=100000
export GAS_LIMIT_2=200000
export GAS_LIMIT_DEPLOY=4000000
if [[ "$AMOUNT" == "" ]]; then
	export AMOUNT=0.001
fi

function _to_list() {
	if [[ "$1" == "" ]]; then
		awk -F, '{for (i = 1; i<=NF; i++) print $i}'
	else 
		awk -F, '{for (i = 1; i<=NF; i++) print $i}' | head -n $1
	fi
}

function upper() {
	echo $1 | awk '{print toupper($0)}'
}

function env_value() {
	eval echo '$'$1'_'$2
}

function _env() {
	network=$(upper $1)
	export CHAIN_ID=$(env_value CHAIN_ID $network)
	export DOMAIN_ID=$(env_value DOMAIN_ID $network)
	if [[ "$DOMAIN_ID" == "" ]]; then
		export DOMAIN_ID=$CHAIN_ID
	fi
	export NETWORK_NAME=$network
	export NETWORK_RPC=$(env_value NETWORK_RPC $network)

	export ERC20_SYMBOL=$TOKEN
	export ERC20_NAME=$(env_value ERC20_NAME $ERC20_SYMBOL)
	export ERC20_ADDR=$(env_value ERC20_ADDR_${ERC20_SYMBOL} $network)
	export ERC20_HANDLER=$(env_value ERC20_HANDLER $network)

	export ERC721_SYMBOL=$NFT
	export ERC721_NAME=$(env_value ERC721_NAME $ERC721_SYMBOL)
	export ERC721_BASEURI=$(env_value ERC721_BASEURI $ERC721_SYMBOL)
	export ERC721_ADDR=$(env_value ERC721_ADDR_${ERC721_SYMBOL} $network)
	export ERC721_HANDLER=$(env_value ERC721_HANDLER $network)

	export ROLLUP_SYMBOL=$ROLLUP
	export ROLLUP_HANDLER=$(env_value ROLLUP_HANDLER $network)
	export ROLLUP_ADDR=$(env_value ROLLUP_ADDR_${ROLLUP_SYMBOL} $network)
	# echo ROLLUP_ADDR_${ROLLUP_SYMBOL} $network;

	export RESOURCE_ID=$(env_value RESOURCE_ID $ERC20_SYMBOL)
	export NFT_RESOURCE_ID=$(env_value RESOURCE_ID $ERC721_SYMBOL)
	export ROLLUP_RESOURCE_ID=$(env_value RESOURCE_ID $ROLLUP_SYMBOL)
	export BRIDGE_ADDR=$(env_value BRIDGE_ADDR $network)
	if [[ "$CHAIN_ID" == "" ]]; then
		echo "invalid network: $1" >&2
		exit 1
	fi
}

function _mint_erc20_one() {
	_PK=$1 _call erc20 mint --amount 1000000 --erc20Address ${ERC20_ADDR} --recipient "$2"
}

function _mint_erc721_one() {
	_PK=$1 _call erc721 mint --erc721Address ${ERC721_ADDR} --id $3 --recipient $2
}

function mint_erc721() {
	if [[ "$1" == "" ]]; then
		echo "usage: mint_erc721 <token>"
		exit 1
	fi
	dest=$(echo $TESTS | _to_list 1)
	echo $dest
	_mint_erc721_one ${DEPLOY_ACCOUNT_PRIVATE_KEY} $dest $1
	approve_nft $1
}

function approve_nft() {
	if [[ "$1" == "" ]]; then
		echo "usage: approve_nft <token>"
		exit 1
	fi
	

	pk=$(echo $TESTS_PRIVATE_KEY | _to_list 1)
	_approve_erc721 $pk $1
}

function mint_erc20() {
	if [[ "$1" == "" ]]; then
		echo $TESTS | _to_list | while read to; do
			_mint_erc20_one ${DEPLOY_ACCOUNT_PRIVATE_KEY} $to
		done
	else
		_mint_erc20_one ${DEPLOY_ACCOUNT_PRIVATE_KEY} $1
	fi
}

function mint_erc20_to_handler() {
	_mint_erc20_one ${DEPLOY_ACCOUNT_PRIVATE_KEY} $ERC20_HANDLER
}

function erc20_balance() {
	addr=$1
	if [[ "$addr" == "" ]]; then
		echo "usage: $0 erc20_balance <addr>"
		return 1
	fi
	_call erc20 balance --address $addr --erc20Address ${ERC20_ADDR}
}

function _approve_erc721() {
	_PK=$1 _call erc721 approve --id $2 --recipient ${ERC721_HANDLER} --erc721Address ${ERC721_ADDR}
}

function _approve() {
	_PK=$1 _call erc20 approve --amount 1000000000 --erc20Address ${ERC20_ADDR} --recipient ${ERC20_HANDLER}
}

function approve() {
	echo $TESTS_PRIVATE_KEY | _to_list | while read pk; do
		_approve $pk
	done
}

function gen_config() {
	n=$1
	if [[ "$n" == "" ]]; then
		n=1
	fi
	source ./config-tmpl.sh
	pk=$(echo $RELAYERS_PRIVATE_KEY | _to_list $n | tail -n 1)
	_tmpl_header
	_tmpl_keys
	__comma1=""
	__idx="0"
	echo $RELAYERS_PRIVATE_KEY | _to_list | while read role; do
		cat <<EOF
		$__comma1"relayer-$__idx": [
EOF
		echo $NETWORKS | _to_list | while read name; do
			_env $name
			_tmpl_chain_keys_chain "$__comma" $role
			if [[ "$__comma" == "" ]]; then
				__comma=,
			fi
		done
		echo "		]"
		if [[ "$__comma1" == "" ]]; then
			__comma1=,
		fi
		__idx=$(expr $__idx + 1)
	done
	echo "	},"
	_tmpl_chain_header
	__comma=""
	echo $NETWORKS | _to_list | while read name; do 
		_env $name
		_tmpl_chain "$__comma" $pk
		if [[ "$__comma" == "" ]]; then
			__comma=,
		fi
	done
	_tmpl_footer
}

function add_resource() {
	_GL=${GAS_LIMIT_2} _call bridge register-resource --bridge ${BRIDGE_ADDR} --handler ${ERC20_HANDLER} --targetContract ${ERC20_ADDR} --resourceId ${RESOURCE_ID} 
}

function add_nft_resource() {
	_GL=${GAS_LIMIT_2} _call bridge register-resource --bridge ${BRIDGE_ADDR} --handler ${ERC721_HANDLER} --targetContract ${ERC721_ADDR} --resourceId ${NFT_RESOURCE_ID} 
}

function add_rollup_resource() {
	_GL=${GAS_LIMIT_2} _call bridge register-resource --bridge ${BRIDGE_ADDR} --handler ${ROLLUP_HANDLER} --targetContract ${ROLLUP_ADDR} --resourceId ${ROLLUP_RESOURCE_ID} 
}

function deploy() {
	if [[ "$DEPLOY_ACCOUNT_PRIVATE_KEY" == "" ]]; then
		echo "missing env DEPLOY_ACCOUNT_PRIVATE_KEY" >&2
		return 1
	fi
	_GL=${GAS_LIMIT_DEPLOY} _call deploy --bridge --rollupHandler --rollupExample --rollupResourceID ${ROLLUP_RESOURCE_ID} --erc20Handler --erc20 --chainId ${DOMAIN_ID} --relayerThreshold ${THRESHOLD} --relayers ${RELAYERS} --erc20Symbol ${ERC20_SYMBOL} --erc20Name ${ERC20_NAME} --expiry 10000000 --erc721Handler --erc721Symbol ${ERC721_SYMBOL} --erc721Name ${ERC721_NAME} --erc721BaseUri ${ERC721_BASEURI} --erc721
}

function deploy_rollup() {
	if [[ "$DEPLOY_ACCOUNT_PRIVATE_KEY" == "" ]]; then
		echo "missing env DEPLOY_ACCOUNT_PRIVATE_KEY" >&2
		return 1
	fi
	_GL=${GAS_LIMIT_DEPLOY} _call deploy --bridge --rollupHandler --rollupExample --rollupResourceID ${ROLLUP_RESOURCE_ID} --chainId ${DOMAIN_ID} --relayerThreshold ${THRESHOLD} --relayers ${RELAYERS} --expiry 10000000
}

function add_nft_handler() {
	if [[ "$DEPLOY_ACCOUNT_PRIVATE_KEY" == "" ]]; then
		echo "missing env DEPLOY_ACCOUNT_PRIVATE_KEY" >&2
		return 1
	fi
	_GL=${GAS_LIMIT_DEPLOY} _call deploy --erc721Handler --chainId ${DOMAIN_ID} --bridgeAddress ${BRIDGE_ADDR}
}

function add_nft() {
	if [[ "$DEPLOY_ACCOUNT_PRIVATE_KEY" == "" ]]; then
		echo "missing env DEPLOY_ACCOUNT_PRIVATE_KEY" >&2
		return 1
	fi
	_GL=${GAS_LIMIT_DEPLOY} _call deploy --erc721 --chainId ${DOMAIN_ID} --erc721Symbol ${ERC721_SYMBOL} --erc721Name ${ERC721_NAME} --erc721BaseUri ${ERC721_BASEURI}
}

function add_token() {
	if [[ "$DEPLOY_ACCOUNT_PRIVATE_KEY" == "" ]]; then
		echo "missing env DEPLOY_ACCOUNT_PRIVATE_KEY" >&2
		return 1
	fi
	_GL=${GAS_LIMIT_DEPLOY} _call deploy --erc20 --chainId ${DOMAIN_ID} --relayerThreshold ${THRESHOLD} --relayers ${RELAYERS} --erc20Symbol ${ERC20_SYMBOL} --erc20Name ${ERC20_NAME}
}

function init_nft() {
	echo 'add nft resource'
	add_nft_resource
	echo 'setup burnable'
	_call bridge set-burn --bridge ${BRIDGE_ADDR} --handler ${ERC721_HANDLER} --tokenContract ${ERC721_ADDR}
	echo 'add minter'
	_call erc721 add-minter --erc721Address ${ERC721_ADDR} --minter ${ERC721_HANDLER}
}


function init() {
	init_erc20
	init_nft
}

function init_erc20() {
	echo 'mint erc20...'
	mint_erc20
	echo 'approve'
	approve
	echo 'mint to erc20 handler...'
	mint_erc20_to_handler
	echo 'add resource mapping'
	add_resource
}

function _call() {
	if [[ "$_PK" == "" ]]; then
		export _PK=${DEPLOY_ACCOUNT_PRIVATE_KEY}
	fi
	if [[ "$_GL" == "" ]]; then
		export _GL=${GAS_LIMIT}
	fi
	if [[ "$DEBUG" != "" ]]; then
		echo ./index.js --privateKey $_PK --url ${NETWORK_RPC} --gasLimit $_GL --gasPrice ${GAS_PRICE} $@
	else
		./index.js --privateKey $_PK --url ${NETWORK_RPC} --gasLimit $_GL --gasPrice ${GAS_PRICE} $@
	fi
}

function withdraw() {
	recipient=$1
	amountOrId=$2
	if [[ "$amountOrId" == "" ]]; then
		echo "$0 $NETWORK_NAME withdraw \${recipient} \${amountOrId}"
		return 1
	fi
	_call admin withdraw --bridge ${BRIDGE_ADDR} --handler ${ERC20_HANDLER} --tokenContract ${ERC20_ADDR} --amountOrId $amountOrId --recipient $recipient
}

function set_threshold() {
	if [[ "$1" == "" ]]; then
		echo "usage: $0 set_threshold {size}" >&1
		return 1
	fi
	_call admin set-threshold --bridge ${BRIDGE_ADDR} --threshold $1
}

function add_relayer() {
	if [[ "$1" == "" ]]; then
		echo "usage: $0 add_relayer {idx}" >&1
		return 1
	fi
	relayer=$(echo $RELAYERS | _to_list $1 | tail -n 1)
	_call admin add-relayer --bridge ${BRIDGE_ADDR} --relayer $relayer
}

function mint_deposit_nft() {
	mint_erc721 $3
	deposit_nft $@
}

function approve_deposit_nft() {
	approve_nft $3
	deposit_nft $@
}

function rollup_transfer() {
	if [[ "$2" == "" ]]; then
		echo "usage $0"' deposit ${destNetworkName} ${recipient} ${tokenId}' >&2
		return 1
	fi
	recipient=$1
	tokenId=$2
	pk=$(echo $DEPLOY_ACCOUNT_PRIVATE_KEY | _to_list 1)
	_PK=$pk _GL=${GAS_LIMIT_2} _call rollup transfer --rollupExample ${ROLLUP_ADDR} --recipient ${recipient} --token ${tokenId}
}

function rollup() {
	dest=$(env_value DOMAIN_ID $(upper $1))
	if [[ "$dest" == "" ]]; then
		dest=$(env_value CHAIN_ID $(upper $1))
	fi
	# pk=$(echo $DEPLOY_ACCOUNT_PRIVATE_KEY | _to_list 1)
	_GL=${GAS_LIMIT_2} _call rollup rollup --rollupExample ${ROLLUP_ADDR} --destDomainId $dest --resourceID ${ROLLUP_RESOURCE_ID}
}

function _domain_id() {
	dest=$(env_value DOMAIN_ID $(upper $1))
	if [[ "$dest" == "" ]]; then
		dest=$(env_value CHAIN_ID $(upper $1))
	fi
	echo $dest
}

function erc20_rollup() {
	dest=$(_domain_id $1)
	_call erc20 rollup --resourceID ${RESOURCE_ID} --batch 100 --destDomainId $dest --address ${ERC20_ADDR}
}


function deposit_nft() {
	if [[ "$2" == "" ]]; then
		echo "usage $0"' deposit ${destNetworkName} ${recipient}' >&2
		return 1
	fi
	dest=$(env_value DOMAIN_ID $(upper $1))
	if [[ "$dest" == "" ]]; then
		dest=$(env_value CHAIN_ID $(upper $1))
	fi
	recipient=$2
	tokenId=$3
	echo $TESTS_PRIVATE_KEY | _to_list 1 | while read pk; do
		_PK=$pk _GL=${GAS_LIMIT_2} _call erc721 deposit --resourceId ${NFT_RESOURCE_ID} --bridge ${BRIDGE_ADDR} --dest $dest --recipient $recipient --id $tokenId
	done
}

function deposit() {
	if [[ "$2" == "" ]]; then
		echo "usage $0"' deposit ${destNetworkName} ${recipient}' >&2
		return 1
	fi
	dest=$(env_value DOMAIN_ID $(upper $1))
	if [[ "$dest" == "" ]]; then
		dest=$(env_value CHAIN_ID $(upper $1))
	fi
	recipient=$2
	echo $TESTS_PRIVATE_KEY | _to_list 1 | while read pk; do
		_PK=$pk _GL=${GAS_LIMIT_2} _call erc20 deposit --resourceId ${RESOURCE_ID} --bridge ${BRIDGE_ADDR} --dest $dest --recipient $recipient --amount $AMOUNT
	done
}

if [[ "$1" == "" ]]; then
	echo "usage: $0 \$network" >&2
	exit 1
fi


_env $1
shift
$@
