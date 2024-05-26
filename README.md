

# Events Ticket System

This project is a blockchain-based event ticketing system built on the SUI platform. The system allows for the creation of events, the sale of tickets, and the handling of ticket purchases and refunds using SUI coins. The use of blockchain ensures transparency, security, and immutability of transactions.

## Features

- **Create Event**: Organizers can create events with specific start and end times.
- **Create Ticket**: Tickets can be created and assigned to an event with a set price and quantity.
- **Buy Ticket**: Users can purchase tickets for events using SUI coins.
- **Get Invoice Details**: Retrieve details of a ticket purchase.
- **Retrieve Funds**: Event organizers can retrieve funds from the event wallet after the event has ended.
- **Refund Ticket**: Users can request a refund for their ticket before the event ends.

## Error Codes

- `ErrorEventOver (0)`: The event has already ended.
- `ErrorEventNotOver (1)`: The event has not ended yet.
- `ErrorPaymentNotEnough (2)`: The payment provided is not enough to cover the ticket price.
- `ErrorTicketNotAvailable (3)`: No tickets are available for the event.
- `ErrorNotValidBuyer (4)`: The buyer is not valid or not the original purchaser.

## Structs

### Event

- `id: UID`
- `name: vector<u8>`
- `desc: vector<u8>`
- `wallet_balance: Balance<SUI>`
- `start_time: u64`
- `end_time: u64`

### Ticket

- `id: UID`
- `event_id: ID`
- `ticket_price: u64`
- `total_tickets: u64`
- `tickets_sold: u64`

### Invoice

- `id: UID`
- `event_id: ID`
- `ticket_id: ID`
- `buyer: address`

## Functions

### Create Event

Creates a new event.

```move
public fun create_event(name: vector<u8>, desc: vector<u8>, start_time: u64, end_time: u64, ctx: &mut TxContext): Event
```
### Create Ticket

Creates a new ticket assigned to an event.

```move

public fun create_ticket(event: &mut Event, ticket_price: u64, total_tickets: u64, ctx: &mut TxContext): Ticket
```
### Buy Ticket

Allows a user to purchase a ticket for an event.

```move

public fun buy_ticket(ticket: &mut Ticket, event: &mut Event, ctx: &mut TxContext, clock: &Clock, buyer_coin_payment: Coin<SUI>)
```
### Get Invoice Details

Retrieves details of a specific invoice.

```move

public fun get_invoice(invoice: &Invoice): (&ID, &ID, &address)

```

### Get Invoice with Buyer Address

Retrieves invoice details, ensuring the buyer is valid.

```move

public fun get_invoice_with_buyer(invoice: &Invoice, buyer: address): (&ID, &ID, &address)
```
### Get Event Details

Retrieves details of a specific event.

```move
public fun get_event(event: &Event): (&vector<u8>, &vector<u8>, &u64, &u64)
```
### Retrieve Funds

Allows event organizers to retrieve funds from the event wallet after the event has ended.

```move
public fun retrieve_funds(event: &mut Event, ctx: &mut TxContext, clock: &Clock, receiver: address)
```
### Refund Ticket

Allows a user to request a refund for their ticket before the event ends.

```move

public fun refund_ticket(ticket: &mut Ticket, event: &mut Event, invoice: Invoice, ctx: &mut TxContext, clock: &Clock)
```
## Getting Started

### Clone the repository:

   ``` bash
   git clone https://github.com/Q4Qoph/Events_Ticket
   cd Events_Ticket
```
### Compile and Deploy:
Follow the SUI platform instructions to compile and deploy the smart contracts.

### Interact with the Contracts:

Use the SUI platform tools to interact with the deployed contracts, create events, tickets, and process ticket sales and refunds.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.
License

This project is licensed under the MIT License - see the LICENSE file for details.


This README provides a clear overview of the project's purpose, key features, error 
