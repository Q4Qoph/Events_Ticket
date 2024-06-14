module Events_Ticket::Events_Ticket {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const ErrorEventOver: u64 = 0;
    const ErrorEventNotOver: u64 = 1;
    const ErrorPaymentNotEnough: u64 = 2;
    const ErrorTicketNotAvailable: u64 = 3;
    const ErrorNotValidBuyer: u64 = 4;
    const ErrorUnauthorized: u64 = 5;

    struct Event has key, store {
        id: UID,
        name: vector<u8>,
        desc: vector<u8>,
        wallet_balance: Balance<SUI>,
        start_time: u64,
        end_time: u64,
        organizer: address,
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
    public entry fun create_event(
        name: vector<u8>, 
        desc: vector<u8>, 
        start_time: u64, 
        end_time: u64, 
        ctx: &mut TxContext
    ): Event {
        let event = Event {
            id: object::new(ctx),
            name,
            desc,
            wallet_balance: balance::zero<SUI>(),
            start_time,
            end_time,
            organizer: tx_context::sender(ctx),
        };
        event
    }

    /// Create a ticket assigned to an Event
    public entry fun create_ticket(
        event: &mut Event, 
        ticket_price: u64, 
        total_tickets: u64, 
        ctx: &mut TxContext
    ): Ticket {
        let ticket = Ticket {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            ticket_price,
            total_tickets,
            tickets_sold: 0,
        };
        ticket
    }

    /// Buy a ticket for an event
    public entry fun buy_ticket(
        ticket: &mut Ticket, 
        event: &mut Event, 
        ctx: &mut TxContext, 
        clock: &Clock,
        buyer_coin_payment: Coin<SUI>
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ErrorEventOver);
        assert!(ticket.tickets_sold < ticket.total_tickets, ErrorTicketNotAvailable);
        assert!(coin::value(&buyer_coin_payment) >= ticket.ticket_price, ErrorPaymentNotEnough);

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

    /// Get Invoice details 
    public fun get_invoice(invoice: &Invoice): (&ID, &ID, &address) {
        (invoice.event_id, invoice.ticket_id, &invoice.buyer)
    }

    /// Get Invoice with buyer address
    public fun get_invoice_with_buyer(invoice: &Invoice, buyer: address): (&ID, &ID, &address) {
        assert!(invoice.buyer == buyer, ErrorNotValidBuyer);
        (invoice.event_id, invoice.ticket_id, &invoice.buyer)
    }

    /// Get Event details
    public fun get_event(event: &Event): (&vector<u8>, &vector<u8>, &u64, &u64, &address) {
        (event.name, event.desc, &event.start_time, &event.end_time, &event.organizer)
    }

    /// Retrieve all funds from event wallet after event is over
    public entry fun retrieve_funds(
        event: &mut Event, 
        ctx: &mut TxContext, 
        clock: &Clock, 
        receiver: address
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > event.end_time, ErrorEventNotOver);
        assert!(tx_context::sender(ctx) == event.organizer, ErrorUnauthorized);

        let amount = balance::value(&event.wallet_balance);
        let take_coin = coin::take(&mut event.wallet_balance, amount, ctx);
        transfer::public_transfer(take_coin, receiver);
    }

    /// Refund a ticket
    public entry fun refund_ticket(
        ticket: &mut Ticket, 
        event: &mut Event, 
        invoice: Invoice, 
        ctx: &mut TxContext, 
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ErrorEventOver);
        assert!(ticket.tickets_sold > 0, ErrorTicketNotAvailable);
        assert!(invoice.buyer == tx_context::sender(ctx), ErrorNotValidBuyer);

        ticket.tickets_sold = ticket.tickets_sold - 1;

        let ticket_price = ticket.ticket_price;
        let refund_coin = coin::take(&mut event.wallet_balance, ticket_price, ctx);
        transfer::public_transfer(refund_coin, invoice.buyer);

        object::delete(invoice.id);
    }

    /// Update event details
    public entry fun update_event_details(
        event: &mut Event, 
        name: vector<u8>, 
        desc: vector<u8>, 
        start_time: u64, 
        end_time: u64, 
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == event.organizer, ErrorUnauthorized);

        event.name = name;
        event.desc = desc;
        event.start_time = start_time;
        event.end_time = end_time;
    }

    /// Check ticket availability
    public fun check_ticket_availability(ticket: &Ticket): bool {
        ticket.tickets_sold < ticket.total_tickets
    }

    /// Get the number of tickets sold
    public fun get_tickets_sold(ticket: &Ticket): u64 {
        ticket.tickets_sold
    }
}
