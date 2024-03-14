use alloy_primitives::{Address, U256};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use typeshare::typeshare;
use url::Url;

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone, Default)]
#[serde(rename_all = "kebab-case")]
pub struct ConfigString {
    #[serde(default)]
    pub networks: HashMap<String, NetworkString>,
    #[serde(default)]
    pub subgraphs: HashMap<String, Url>,
    #[serde(default)]
    pub orderbooks: HashMap<String, OrderbookString>,
    #[serde(default)]
    pub tokens: HashMap<String, TokenString>,
    #[serde(default)]
    pub deployers: HashMap<String, DeployerString>,
    #[serde(default)]
    pub orders: HashMap<String, OrderString>,
    #[serde(default)]
    pub scenarios: HashMap<String, ScenarioString>,
    #[serde(default)]
    pub charts: HashMap<String, ChartString>,
    #[serde(default)]
    pub deployments: HashMap<String, DeploymentString>,
}

#[typeshare]
pub type SubgraphRef = String;

#[typeshare]
pub type ScenarioRef = String;

#[typeshare]
pub type NetworkRef = String;

#[typeshare]
pub type DeployerRef = String;

#[typeshare]
pub type OrderRef = String;

#[typeshare]
pub type OrderbookRef = String;

#[typeshare]
pub type TokenRef = String;

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct NetworkString {
    pub rpc: Url,
    #[typeshare(typescript(type = "number"))]
    pub chain_id: u64,
    pub label: Option<String>,
    #[typeshare(typescript(type = "number"))]
    pub network_id: Option<u64>,
    pub currency: Option<String>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct OrderbookString {
    pub address: Address,
    pub network: Option<NetworkRef>,
    pub subgraph: Option<SubgraphRef>,
    pub label: Option<String>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct TokenString {
    pub network: NetworkRef,
    pub address: Address,
    pub decimals: Option<u8>,
    pub label: Option<String>,
    pub symbol: Option<String>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct DeployerString {
    pub address: Address,
    pub network: Option<NetworkRef>,
    pub label: Option<String>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct DeploymentString {
    pub scenario: ScenarioRef,
    pub order: OrderRef,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct IOString {
    pub token: TokenRef,
    #[typeshare(typescript(type = "bigint"))]
    pub vault_id: U256,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct OrderString {
    pub inputs: Vec<IOString>,
    pub outputs: Vec<IOString>,
    pub network: NetworkRef,
    pub deployer: Option<DeployerRef>,
    pub orderbook: Option<OrderbookRef>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct ScenarioString {
    #[serde(default)]
    pub bindings: HashMap<String, String>,
    #[typeshare(typescript(type = "number"))]
    pub runs: Option<u64>,
    pub deployer: Option<DeployerRef>,
    pub scenarios: Option<HashMap<String, ScenarioString>>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct ChartString {
    pub scenario: Option<ScenarioRef>,
    pub plots: HashMap<String, PlotString>,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct PlotString {
    pub data: DataPointsString,
    pub plot_type: String,
}

#[typeshare]
#[derive(Debug, Serialize, Deserialize, Clone)]
#[serde(rename_all = "kebab-case")]
pub struct DataPointsString {
    pub x: String,
    pub y: String,
}

impl TryFrom<String> for ConfigString {
    type Error = serde_yaml::Error;
    fn try_from(val: String) -> Result<ConfigString, Self::Error> {
        serde_yaml::from_str(&val)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_yaml_into_configstrings() {
        let yaml_data = r#"
networks:
    mainnet:
        rpc: https://mainnet.node
        chain_id: 1
        label: Mainnet
        network_id: 1
        currency: ETH
    testnet:
        rpc: https://testnet.node
        chain_id: 2
        label: Testnet
        network_id: 2
        currency: ETH

subgraphs:
    mainnet: https://mainnet.subgraph
    testnet: https://testnet.subgraph

orderbooks:
    mainnetOrderbook:
        address: 0x123
        network: mainnet
        subgraph: mainnet
        label: Mainnet Orderbook
    testnetOrderbook:
        address: 0x456
        network: testnet
        subgraph: testnet
        label: Testnet Orderbook

tokens:
    eth:
        network: mainnet
        address: 0xdef
        decimals: 18
        label: Ethereum
        symbol: ETH
    dai:
        network: mainnet
        address: 0xghi
        decimals: 18
        label: Dai
        symbol: DAI

deployers:
    mainDeployer:
        address: 0xjkl
        network: mainnet
        label: Main Deployer
    testDeployer:
        address: 0xmnop
        network: testnet
        label: Test Deployer

orders:
    buyETH:
        inputs:
            - token: eth
              vault_id: 2
            - token: dai
              vault_id: 0x1
        outputs:
            - token: dai
              vault_id: 3
        network: mainnet
        deployer: mainDeployer
        orderbook: mainnetOrderbook

scenarios:
    mainScenario:
        bindings:
            key1: value1
            key2: value2
        runs: 100
        network: mainnet
        deployer: mainDeployer
        scenarios:
            subScenario1:
                bindings:
                    key3: value3
            subScenario2:
                bindings:
                    key4: value4
charts:
    mainChart:
        scenario: mainScenario
        plots:
            plot1:
                data:
                    x: dataX
                    y: dataY
                plot_type: line
            plot2:
                data:
                    x: dataX2
                    y: dataY2
                plot_type: bar
deployments:
    first-deployment:
        scenario: mainScenario
        order: sellETH
    second-deployment:
        scenario: mainScenario
        order: buyETH"#
            .to_string();

        let config: ConfigString = yaml_data.try_into().unwrap();

        // Asserting a few values to verify successful parsing
        assert_eq!(
            config.clone().networks.get("mainnet").unwrap().rpc,
            Url::parse("https://mainnet.node").unwrap()
        );
        assert_eq!(
            config.networks.get("mainnet").unwrap().label,
            Some("Mainnet".into())
        );
        assert_eq!(
            config.subgraphs.get("mainnet"),
            Some(&Url::parse("https://mainnet.subgraph").unwrap())
        );
        assert_eq!(
            config.orderbooks.get("mainnetOrderbook").unwrap().address,
            "0x123".parse::<Address>().unwrap()
        );
        assert_eq!(config.tokens.get("eth").unwrap().decimals, Some(18));
    }
}
