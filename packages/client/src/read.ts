/**
 * This file purpose is to implement a client capable of calling methods on a given
 * Blockchain Node and to redirect the request to a Gateway whenever necessary.
 */

import { createPublicClient, http } from 'viem'
import { normalize } from 'viem/ens'

import { getChain } from './client'
import { readEnvSchema } from './env'

const {
  CHAIN_ID,
  RPC_URL,
  GATEWAY_URL: gatewayUrls,
  UNIVERSAL_RESOLVER_ADDRESS: universalResolverAddress,
} = readEnvSchema.parse(process.env)

const chain = getChain(CHAIN_ID)
console.log(`Connecting to ${chain?.name}.`)

const client = createPublicClient({
  chain,
  transport: http(RPC_URL),
})

// eslint-disable-next-line
const _ = (async () => {
  const name = normalize('blockful.eth')

  const twitter = await client.getEnsText({
    name,
    key: 'com.twitter',
    universalResolverAddress,
    gatewayUrls,
  })
  const avatar = await client.getEnsAvatar({
    name,
    universalResolverAddress,
    gatewayUrls,
  })
  const address = await client.getEnsAddress({
    name,
    universalResolverAddress,
    gatewayUrls,
  })
  const addressBtc = await client.getEnsAddress({
    name,
    coinType: 1,
    universalResolverAddress,
    gatewayUrls,
  })
  const domainName = await client.getEnsName({
    address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    universalResolverAddress,
    gatewayUrls,
  })

  console.log({
    twitter,
    avatar,
    address,
    addressBtc,
    name: domainName,
  })
})()
