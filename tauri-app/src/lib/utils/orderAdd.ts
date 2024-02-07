import { get } from 'svelte/store';
import { invoke } from '@tauri-apps/api';
import { rpcUrl, orderbookAddress, walletDerivationIndex } from '$lib/stores/settings';
import { chainId } from '$lib/stores/chain';

export async function orderAdd(dotrain: string) {
  await invoke("order_add", {
    addOrderArgs: {
      dotrain,
    },
    transactionArgs: {
      rpc_url: get(rpcUrl),
      orderbook_address: get(orderbookAddress),
      derivation_index: get(walletDerivationIndex),
      chain_id: get(chainId),
    },
  });
}