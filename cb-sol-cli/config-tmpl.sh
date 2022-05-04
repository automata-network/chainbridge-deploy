#!/bin/bash

function _tmpl_header() {
    cat <<EOF
{
	"msghub": {
		"retryTime": 10,
		"retryInternalSecs": 5
	},
EOF
}

function _tmpl_chain_header() {
	cat <<EOF
   	"chains": [
EOF
}

function _tmpl_footer() {
    cat <<EOF
    ]
}
EOF
}

function _tmpl_keys() {
	cat <<EOF
	"keys": {
EOF
}

function _tmpl_chain_keys_chain() {
	cat <<EOF
			$1{
				"id": ${DOMAIN_ID},
				"privateKey": "$2"
			}
EOF
}

function _tmpl_chain() {
    cat <<EOF
        $1{
			"name": "${NETWORK_NAME}",
			"type": "ethereum",
			"id": ${DOMAIN_ID},
			"blockStorePath": "chainbridge.${NETWORK_NAME}.db",
			"blockConfirmations": 4,
			"pollingIntervalSecs": 5,
			"cacheTtl": 300,
			"endpoint": "${NETWORK_RPC}",
			"opts": {
				"chainId": ${CHAIN_ID},
				"privateKey": "$2",
				"bridge": "${BRIDGE_ADDR}",
				"erc20Handler": "${ERC20_HANDLER}",
				"erc721Handler": "${ERC721_HANDLER}",
				"rollupHandler": "${ROLLUP_HANDLER}",
				"gasLimit": "1000000",
				"defaultGasPrice": "20000000"
			}
	    }
EOF
}
