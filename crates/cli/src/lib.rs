use crate::commands::{Order, OrderClear, OrderTake, Vault};
use crate::execute::Execute;
use anyhow::Result;
use clap::Subcommand;

mod commands;
mod execute;
mod status;
mod subgraph;
mod transaction;

#[derive(Subcommand)]
pub enum Orderbook {
    #[command(subcommand)]
    Order(Order),

    #[command(subcommand)]
    Vault(Box<Vault>),

    #[command(subcommand)]
    OrderClear(OrderClear),

    #[command(subcommand)]
    OrderTake(OrderTake),
}

impl Orderbook {
    pub async fn execute(self) -> Result<()> {
        match self {
            Orderbook::Order(order) => order.execute().await,
            Orderbook::Vault(vault) => (*vault).execute().await,
            Orderbook::OrderClear(order_clear) => (order_clear).execute().await,
            Orderbook::OrderTake(order_take) => (order_take).execute().await,
        }
    }
}
