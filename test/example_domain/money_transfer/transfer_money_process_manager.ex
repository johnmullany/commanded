defmodule Commanded.ExampleDomain.TransferMoneyProcessManager do
  use Commanded.ProcessManagers.ProcessManager, fields: [
    debit_account: nil,
    credit_account: nil,
    amount: nil,
    status: nil
  ]

  alias Commanded.ExampleDomain.TransferMoneyProcessManager
  alias Commanded.ExampleDomain.MoneyTransfer.Events.{MoneyTransferRequested}
  alias Commanded.ExampleDomain.BankAccount.Events.{MoneyDeposited,MoneyWithdrawn}
  alias Commanded.ExampleDomain.BankAccount.Commands.{DepositMoney,WithdrawMoney}

  def interested?(%MoneyTransferRequested{transfer_uuid: transfer_uuid}), do: {:start, transfer_uuid}
  def interested?(%MoneyWithdrawn{transfer_uuid: transfer_uuid}), do: {:continue, transfer_uuid}
  def interested?(%MoneyDeposited{transfer_uuid: transfer_uuid}), do: {:continue, transfer_uuid}
  def interested?(_event), do: false

  def handle(%TransferMoneyProcessManager{process_uuid: transfer_uuid} = transfer, %MoneyTransferRequested{debit_account: debit_account, amount: amount} = money_transfer_requested) do
    transfer =
      transfer
      |> dispatch(%WithdrawMoney{account_number: debit_account, transfer_uuid: transfer_uuid, amount: amount})
      |> update(money_transfer_requested)

    {:ok, transfer}
  end

  def handle(%TransferMoneyProcessManager{process_uuid: transfer_uuid, state: state} = transfer, %MoneyWithdrawn{} = money_withdrawn) do
    transfer =
      transfer
      |> dispatch(%DepositMoney{account_number: state.credit_account, transfer_uuid: transfer_uuid, amount: state.amount})
      |> update(money_withdrawn)

    {:ok, transfer}
  end

  def handle(%TransferMoneyProcessManager{} = transfer, %MoneyDeposited{} = money_deposited) do
    {:ok, update(transfer, money_deposited)}
  end

  # ignore any other events
  def handle(transfer, _event), do: {:ok, transfer}

  ## state mutators

  def apply(%TransferMoneyProcessManager.State{} = transfer, %MoneyTransferRequested{debit_account: debit_account, credit_account: credit_account, amount: amount}) do
    %TransferMoneyProcessManager.State{transfer |
      debit_account: debit_account,
      credit_account: credit_account,
      amount: amount,
      status: :withdraw_money_from_debit_account
    }
  end

  def apply(%TransferMoneyProcessManager.State{} = transfer, %MoneyWithdrawn{}) do
    %TransferMoneyProcessManager.State{transfer |
      status: :deposit_money_in_credit_account
    }
  end

  def apply(%TransferMoneyProcessManager.State{} = transfer, %MoneyDeposited{}) do
    %TransferMoneyProcessManager.State{transfer |
      status: :transfer_complete
    }
  end
end
