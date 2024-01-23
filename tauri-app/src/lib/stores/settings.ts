import { isUrlValid } from '$lib/utils/url';
import { writable, derived, get } from 'svelte/store';
import every from 'lodash/every';
import { isAddress } from 'viem';
import { invoke } from '@tauri-apps/api';

export const rpcUrl = writable(localStorage.getItem("settings.rpcUrl") || '');
export const chainId = writable(parseInt(localStorage.getItem("settings.chainId") || '1'))
export const subgraphUrl = writable(localStorage.getItem("settings.subgraphUrl") || '');
export const orderbookAddress = writable(localStorage.getItem("settings.orderbookAddress") || '');
export const walletAddress = writable(localStorage.getItem("settings.walletAddress") || '')
export const walletDerivationIndex = writable(parseInt(localStorage.getItem("settings.walletDerivationIndex") || '0'))

async function updateChainId() {
  const val: number = await invoke('get_chainid', {rpcUrl: get(rpcUrl)});
  chainId.set(val);
}

rpcUrl.subscribe(value => {
  localStorage.setItem("settings.rpcUrl", value || '');
  updateChainId();
});
chainId.subscribe(value => {
  localStorage.setItem("settings.chainId", (value || 0).toString());
});
subgraphUrl.subscribe(value => {
  localStorage.setItem("settings.subgraphUrl", value || '');
});
orderbookAddress.subscribe(value => {
  localStorage.setItem("settings.orderbookAddress", value || '');
});
walletAddress.subscribe(value => {
  localStorage.setItem("settings.walletAddress", value || '');
});
walletDerivationIndex.subscribe(value => {
  localStorage.setItem("settings.walletDerivationIndex", (value || 0).toString());
});

export const isRpcUrlValid = derived(rpcUrl, (val) => isUrlValid(val));
export const isSubgraphUrlValid = derived(subgraphUrl, (val) => isUrlValid(val));
export const isOrderbookAddressValid = derived(orderbookAddress, (val) => isAddress(val));
export const isWalletAddressValid = derived(walletAddress, (val) => isAddress(val));

export const isSettingsDefined = derived([rpcUrl, subgraphUrl, orderbookAddress], (vals) => every(vals.map((v) => v && v.trim().length > 0)));
export const isSettingsValid = derived([isRpcUrlValid, isSubgraphUrlValid], (vals) => every(vals));
export const isSettingsDefinedAndValid = derived([isSettingsDefined, isSettingsValid], (vals) => every(vals));