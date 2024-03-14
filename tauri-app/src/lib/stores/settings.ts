import { asyncDerived, derived, get } from '@square/svelte-store';
import { cachedWritableStore, cachedWritableStringOptional } from '$lib/storesGeneric/cachedWritableStore';
import  find from 'lodash/find';
import * as chains from 'viem/chains';
import { textFileStore } from '$lib/storesGeneric/textFileStore';
import { invoke } from '@tauri-apps/api';
import { type ConfigString, type OrderbookRef, type OrderbookString } from '$lib/typeshare/configString';
import { getBlockNumberFromRpc } from '$lib/services/chain';
import { toasts } from './toasts';
import { pickBy } from 'lodash';

const emptyConfig = {
  deployments: {},
  networks: {},
  orderbooks: {},
  orders: {},
  subgraphs: {},
  tokens: {},
  deployers: {},
  scenarios: {},
  charts: {}
} as ConfigString;

// dotrain text store
export const dotrainFile = textFileStore('Rain', ['rain']);

// general
export const settingsText = cachedWritableStore<string>('settings', "", (s) => s, (s) => s);
export const settingsFile = textFileStore('Orderbook Settings Yaml', ['yml', 'yaml'], get(settingsText));
export const settings = asyncDerived([settingsText, dotrainFile], async ([$settingsText]): Promise<ConfigString> => {
  try {
    const config: ConfigString = await invoke("parse_config", {text: $settingsText});
    return config;
  } catch(e) {
    toasts.error(e as string);
    return emptyConfig;
  }
}, { initial: emptyConfig });

// networks
export const activeNetworkRef = cachedWritableStringOptional("settings.activeNetworkRef");
export const activeNetwork = asyncDerived([settings, activeNetworkRef], async ([$settings, $activeNetworkRef]) => {
  await settings.load();
  return ($activeNetworkRef !== undefined && $settings.networks !== undefined) ? $settings.networks[$activeNetworkRef] : undefined;
});
export const rpcUrl = derived(activeNetwork, ($activeNetwork) => $activeNetwork?.rpc);
export const chainId = derived(activeNetwork, ($activeNetwork) => $activeNetwork?.['chain-id']);
export const activeChain = derived(chainId, ($activeChainId) => find(Object.values(chains), (c) => c.id === $activeChainId));
export const activeChainHasBlockExplorer = derived(activeChain, ($activeChain) => {
  return $activeChain && $activeChain?.blockExplorers?.default !== undefined;
});
export const activeChainLatestBlockNumber = derived(activeNetwork, ($activeNetwork) => $activeNetwork !== undefined ? getBlockNumberFromRpc($activeNetwork.rpc) : 0);

// orderbook
export const activeOrderbookRef = cachedWritableStringOptional("settings.activeOrderbookRef");
export const activeNetworkOrderbooks = derived([settings, activeNetworkRef], ([$settings, $activeNetworkRef]) => $settings?.orderbooks ? pickBy($settings.orderbooks, (orderbook) => orderbook.network === $activeNetworkRef) as Record<OrderbookRef, OrderbookString> : {} as Record<OrderbookRef, OrderbookString>);
export const activeOrderbook =  derived([settings, activeOrderbookRef], ([$settings, $activeOrderbookRef]) => ($settings?.orderbooks !== undefined && $activeOrderbookRef !== undefined) ? $settings.orderbooks[$activeOrderbookRef] : undefined);
export const subgraphUrl = derived(activeOrderbook, ($activeOrderbook) => $activeOrderbook?.subgraph);
export const orderbookAddress = derived(activeOrderbook, ($activeOrderbook) => $activeOrderbook?.address);

export const hasRequiredSettings = derived([activeNetworkRef, activeOrderbookRef], ([$activeNetworkRef, $activeOrderbookRef]) => $activeNetworkRef !== undefined && $activeOrderbookRef !== undefined);

// deployments
export const deployments = derived([settings, activeNetworkRef, activeOrderbookRef], ([$settings, $activeNetworkRef, $activeOrderbookRef]) => pickBy($settings.deployments, (v) => $settings.orders?.[v.order].network === $activeNetworkRef && $settings.orders?.[v.order].orderbook === $activeOrderbookRef));
export const activeDeploymentRef = cachedWritableStringOptional("settings.activeDeploymentRef");
export const activeDeployment = derived([deployments, activeDeploymentRef], ([$deployments, $activeDeploymentRef]) => ($activeDeploymentRef !== undefined && $deployments !== undefined) ? $deployments[$activeDeploymentRef] : undefined);

// When networks / orderbooks settings updated, reset active network / orderbooks
settings.subscribe(async ($settings) => {
  await settings.load();
  const $activeNetworkRef = get(activeNetworkRef);
  const $activeOrderbookRef = get(activeOrderbookRef);

  if(!$settings.networks || $activeNetworkRef === undefined || !Object.keys($settings.networks).includes($activeNetworkRef)) {
    resetActiveNetworkRef();
  }

  if(!$settings.orderbooks || $activeOrderbookRef === undefined || !Object.keys($settings.orderbooks).includes($activeOrderbookRef)) {
    resetActiveOrderbookRef();
  }
});

// When active network is updated to undefined, reset active orderbook
activeNetworkRef.subscribe(($activeNetworkRef)  => {
  if($activeNetworkRef === undefined) {
    resetActiveOrderbookRef();
  }
});

// When active network is updated to not include active orderbook, reset active orderbook
activeNetworkOrderbooks.subscribe(async ($activeNetworkOrderbooks) => {
  const $activeOrderbookRef = get(activeOrderbookRef);

  if($activeOrderbookRef !== undefined && !Object.keys($activeNetworkOrderbooks).includes($activeOrderbookRef)) {
    resetActiveOrderbookRef();
  }
});

// reset active orderbook to first available, otherwise undefined
function resetActiveOrderbookRef() {
  const $activeNetworkOrderbooks = get(activeNetworkOrderbooks);
  const $activeNetworkOrderbookRefs = Object.keys($activeNetworkOrderbooks);

  if($activeNetworkOrderbookRefs.length > 0) {
    activeOrderbookRef.set($activeNetworkOrderbookRefs[0]);
  } else {
    activeOrderbookRef.set(undefined);
  }
}


// reset active orderbook to first available, otherwise undefined
function resetActiveNetworkRef() {
  const $networks = get(settings).networks;

  if($networks !== undefined && Object.keys($networks).length > 0) {
    activeNetworkRef.set(Object.keys($networks)[0]);
  } else {
    activeNetworkRef.set(undefined);
  }
}