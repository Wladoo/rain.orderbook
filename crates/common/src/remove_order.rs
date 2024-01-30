use crate::transaction::{TransactionArgs, TransactionArgsError};
use alloy_ethers_typecast::transaction::{
    WritableClientError, WriteTransaction, WriteTransactionStatus,
};
use alloy_primitives::hex::FromHexError;

use rain_orderbook_bindings::IOrderBookV3::removeOrderCall;
use rain_orderbook_subgraph_queries::types::{
    order::Order as OrderDetail, order_traits::OrderDetailError,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum RemoveOrderArgsError {
    #[error(transparent)]
    WritableClientError(#[from] WritableClientError),
    #[error(transparent)]
    TransactionArgs(#[from] TransactionArgsError),
    #[error(transparent)]
    FromHexError(#[from] FromHexError),
    #[error(transparent)]
    OrderDetailError(#[from] OrderDetailError),
}

#[derive(Serialize, Deserialize, Clone)]
pub struct RemoveOrderArgs {
    pub order: OrderDetail,
}

impl From<OrderDetail> for RemoveOrderArgs {
    fn from(order: OrderDetail) -> Self {
        Self { order }
    }
}

impl TryInto<removeOrderCall> for RemoveOrderArgs {
    type Error = OrderDetailError;

    fn try_into(self) -> Result<removeOrderCall, OrderDetailError> {
        Ok(removeOrderCall {
            order: self.order.try_into()?,
        })
    }
}

impl RemoveOrderArgs {
    pub async fn execute<S: Fn(WriteTransactionStatus<removeOrderCall>)>(
        self,
        transaction_args: TransactionArgs,
        transaction_status_changed: S,
    ) -> Result<(), RemoveOrderArgsError> {
        let ledger_client = transaction_args
            .clone()
            .try_into_ledger_client()
            .await
            .map_err(RemoveOrderArgsError::TransactionArgs)?;

        let remove_order_call: removeOrderCall = self.try_into()?;
        let params = transaction_args
            .try_into_write_contract_parameters(
                remove_order_call,
                transaction_args.orderbook_address,
            )
            .await
            .map_err(RemoveOrderArgsError::TransactionArgs)?;

        WriteTransaction::new(ledger_client.client, params, 4, transaction_status_changed)
            .execute()
            .await
            .map_err(RemoveOrderArgsError::WritableClientError)?;

        Ok(())
    }
}