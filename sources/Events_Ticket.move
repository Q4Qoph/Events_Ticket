module Events_Ticket::Events_Ticket {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const ERROR_EVENT_OVER: u64 = 0;
    const ERROR_EVENT_NOT_OVER: u64 = 1;
    const ERROR_PAYMENT_NOT_ENOUGH: u64 = 2;
    const ERROR_TICKET_NOT_AVAILABLE: u64 = 3;
    const ERROR_NOT_VALID_BUYER: u64 = 4;
    const ERROR_INSUFFICIENT_EVENT_FUNDS: u64 = 5;

    struct Event has key, store {
        id: UID,
        name: vector<u8>,
        desc: vector<u8>,
        wallet_balance: Balance<SUI>,
        start_time: u64,
        end_time: u64,
    }

    struct Ticket has key, store {
        id: UID,
        event_id: ID,
        ticket_price: u64,
        total_tickets: u64,
        tickets_sold: u64,
    }

    struct Invoice has key, store {
        id: UID,
        event_id: ID,
        ticket_id: ID,
        buyer: address,
    }

    /// Create a new event
    public fun create_event(name: vector<u8>, desc: vector<u8>, start_time: u64, end_time: u64, ctx: &mut TxContext): Event {
        Event {
            id: object::new(ctx),
            name,
            desc,
            wallet_balance: balance::zero<SUI>(),
            start_time,
            end_time,
        }
    }

    /// Create a ticket assigned to an event
    public fun create_ticket(event: &mut Event, ticket_price: u64, total_tickets: u64, ctx: &mut TxContext): Ticket {
        Ticket {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            ticket_price,
            total_tickets,
            tickets_sold: 0,
        }
    }

    /// Buy a ticket for an event
    public fun buy_ticket(ticket: &mut Ticket, event: &mut Event, ctx: &mut TxContext, clock: &Clock, buyer_coin_payment: Coin<SUI>) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ERROR_EVENT_OVER);
        assert!(ticket.tickets_sold < ticket.total_tickets, ERROR_TICKET_NOT_AVAILABLE);
        assert!(coin::value(&buyer_coin_payment) >= ticket.ticket_price, ERROR_PAYMENT_NOT_ENOUGH);

        let coin_balance = coin::into_balance(buyer_coin_payment);
        balance::join(&mut event.wallet_balance, coin_balance);
        ticket.tickets_sold = ticket.tickets_sold + 1;

        let invoice = Invoice {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            ticket_id: object::uid_to_inner(&ticket.id),
            buyer: tx_context::sender(ctx),
        };

        transfer::share_object(invoice);
    }

    /// Get invoice details
    public fun get_invoice(invoice: &Invoice): (&ID, &ID, &address) {
        (invoice.event_id, invoice.ticket_id, &invoice.buyer)
    }

    /// Get invoice details with buyer validation
    public fun get_invoice_with_buyer(invoice: &Invoice, buyer: address): (&ID, &ID, &address) {
        assert!(invoice.buyer == buyer, ERROR_NOT_VALID_BUYER);
        (invoice.event_id, invoice.ticket_id, &invoice.buyer)
    }

    /// Get event details
    public fun get_event(event: &Event): (&vector<u8>, &vector<u8>, &u64, &u64) {
        (&event.name, &event.desc, &event.start_time, &event.end_time)
    }

    /// Retrieve all funds from event wallet after event is over
    public fun retrieve_funds(event: &mut Event, ctx: &mut TxContext, clock: &Clock, receiver: address) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > event.end_time, ERROR_EVENT_NOT_OVER);

        let amount = balance::value(&event.wallet_balance);
        let take_coin = coin::take(&mut event.wallet_balance, amount, ctx);
        transfer::public_transfer(take_coin, receiver);
    }

    /// Refund a ticket
    public fun refund_ticket(ticket: &mut Ticket, event: &mut Event, invoice: Invoice, ctx: &mut TxContext, clock: &Clock) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ERROR_EVENT_OVER);
        assert!(ticket.tickets_sold > 0, ERROR_TICKET_NOT_AVAILABLE);
        assert!(invoice.buyer == tx_context::sender(ctx), ERROR_NOT_VALID_BUYER);

        let ticket_price = ticket.ticket_price;
        assert!(balance::value(&event.wallet_balance) >= ticket_price, ERROR_INSUFFICIENT_EVENT_FUNDS);

        ticket.tickets_sold = ticket.tickets_sold - 1;

        let refund_coin = coin::take(&mut event.wallet_balance, ticket_price, ctx);
        transfer::public_transfer(refund_coin, invoice.buyer);

        object::delete(invoice.id);
    }

    /// Check if tickets are available for an event
    public fun check_ticket_availability(ticket: &Ticket): bool {
        ticket.tickets_sold < ticket.total_tickets
    }

    /// Get the current balance of an event wallet
    public fun get_event_wallet_balance(event: &Event): u64 {
        balance::value(&event.wallet_balance)
    }

    /// Get ticket details
    public fun get_ticket_details(ticket: &Ticket): (&ID, &u64, &u64, &u64) {
        (&ticket.event_id, &ticket.ticket_price, &ticket.total_tickets, &ticket.tickets_sold)
    }

    /// Get the number of tickets sold
    public fun get_tickets_sold(ticket: &Ticket): u64 {
        ticket.tickets_sold
    }
}
