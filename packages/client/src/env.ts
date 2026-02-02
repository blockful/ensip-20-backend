import { z } from 'zod'
import { config } from 'dotenv'
import { isAddress, getAddress, isHex } from 'viem'

config({ path: process.env.ENV_FILE || '../.env' })

export const readEnvSchema = z.object({
  CHAIN_ID: z.coerce.number().default(31337),
  RPC_URL: z.url().default('http://127.0.0.1:8545/'),
  GATEWAY_URL: z
    .url()
    .default('http://127.0.0.1:3000/{sender}/{data}.json')
    .transform((val) => [val]),
  UNIVERSAL_RESOLVER_ADDRESS: z
    .string()
    .refine((val) => isAddress(val, { strict: false }), 'Invalid address')
    .transform((val) => getAddress(val))
    .optional(),
})

export const writeEnvSchema = z
  .object({
    RESOLVER_ADDRESS: z
      .string()
      .refine((val) => isAddress(val, { strict: false }), 'Invalid address')
      .transform((val) => getAddress(val)),
    L2_RPC_URL: z.url().optional().default('http://127.0.0.1:8545/'),
    PRIVATE_KEY: z
      .string()
      .min(64)
      .max(66)
      .refine((val) => isHex(val), 'Private key must be a valid hex string'),
  })
  .extend(readEnvSchema.shape)
