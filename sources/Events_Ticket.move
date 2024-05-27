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

    struct Event has key, store {
        id: UID,
        name: vector<u8>,
        desc: vector<u8>,
        wallet_balance: Balance<SUI>,
        start_time: u64,
        end_time: u64,
        organizer: address, // Add organizer to enforce access control
        payment_lock: bool, // Add payment lock to prevent double spending
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

    // Create Event function with organizer
    public fun create_event(name: vector<u8>, desc: vector<u8>, start_time: u64, end_time: u64, ctx: &mut TxContext): Event {
        let organizer = tx_context::sender(ctx);
        let event = Event {
            id: object::new(ctx),
            name,
            desc,
            wallet_balance: balance::zero<SUI>(),
            start_time,
            end_time,
            organizer,
            payment_lock: false, // Initialize payment lock to false
        };

        event
    }

    // Create a ticket assigned to an Event
    public fun create_ticket(event: &mut Event, ticket_price: u64, total_tickets: u64, ctx: &mut TxContext): Ticket {
        assert!(tx_context::sender(ctx) == event.organizer, ErrorNotValidBuyer); // Ensure only organizer can create tickets
        let ticket = Ticket {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            ticket_price,
            total_tickets,
            tickets_sold: 0,
        };

        ticket
    }

    // Buy a ticket for an event
    public fun buy_ticket(ticket: &mut Ticket, event: &mut Event, ctx: &mut TxContext, clock: &Clock, buyer_coin_payment: Coin<SUI>) {
        // check if event is over
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ErrorEventOver);

        // check if ticket is available
        assert!(ticket.tickets_sold < ticket.total_tickets, ErrorTicketNotAvailable);

        // check if buyer has enough balance
        let ticket_price = ticket.ticket_price;
        let buyer = tx_context::sender(ctx);
        assert!(coin::value(&buyer_coin_payment) >= ticket_price, ErrorPaymentNotEnough);

        // prevent double spending by locking payment
        assert!(!event.payment_lock, ErrorNotValidBuyer);
        event.payment_lock = true;

        // transfer buyer_coin_payment to event wallet
        let coin_balance = coin::into_balance(buyer_coin_payment);
        balance::join(&mut event.wallet_balance, coin_balance);

        // increment tickets sold
        ticket.tickets_sold = ticket.tickets_sold + 1;

        // create invoice
        let invoice = Invoice {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            ticket_id: object::uid_to_inner(&ticket.id),
            buyer,
        };

        // share invoice
        transfer::share_object(invoice);

        // unlock payment after transaction completion
        event.payment_lock = false;
    }

    // Get Invoice details
    public fun get_invoice(invoice: &Invoice): (&ID, &ID, &address) {
        let Invoice { event_id, ticket_id, buyer, .. } = invoice;
        (event_id, ticket_id, buyer)
    }

    // Get Invoice with buyer address
    public fun get_invoice_with_buyer(invoice: &Invoice, buyer: address): (&ID, &ID, &address) {
        // check if buyer is valid
        assert!(invoice.buyer == buyer, ErrorNotValidBuyer);
        let Invoice { event_id, ticket_id, buyer, .. } = invoice;
        (event_id, ticket_id, buyer)
    }

    // Get Event details
    public fun get_event(event: &Event): (&vector<u8>, &vector<u8>, &u64, &u64) {
        let Event { name, desc, start_time, end_time, .. } = event;
        (name, desc, start_time, end_time)
    }

    // Retrieve all funds from event wallet after event is over
    public fun retrieve_funds(event: &mut Event, ctx: &mut TxContext, clock: &Clock, receiver: address) {
        // check if event is over
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > event.end_time, ErrorEventNotOver);

        // Ensure only organizer can retrieve funds
        assert!(tx_context::sender(ctx) == event.organizer, ErrorNotValidBuyer);

        // get funds from event wallet
        let amount = balance::value(&event.wallet_balance);
        let take_coin = coin::take(&mut event.wallet_balance, amount, ctx);

        // transfer funds to receiver
        transfer::public_transfer(take_coin, receiver);
    }

    // Refund a ticket
    public fun refund_ticket(ticket: &mut Ticket, event: &mut Event, invoice: Invoice, ctx: &mut TxContext, clock: &Clock) {
        // check if event is over
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < event.end_time, ErrorEventOver);

        // check if ticket is available
        assert!(ticket.tickets_sold > 0, ErrorTicketNotAvailable);

        // check if buyer is valid
        assert!(invoice.buyer == tx_context::sender(ctx), ErrorNotValidBuyer);

        let Invoice { id, ticket_id, buyer, .. } = invoice;

        // decrement tickets sold
        ticket.tickets_sold = ticket.tickets_sold - 1;

        // refund buyer
        let ticket_price = ticket.ticket_price;
        let refund_coin = coin::take(&mut event.wallet_balance, ticket_price, ctx);
        transfer::public_transfer(refund_coin, buyer);

        // delete invoice
        object::delete(id);
    }

    // Cancel an event
    public fun cancel_event(event: &mut Event, ctx: &mut TxContext,invoice: Invoice, clock: &Clock) {
        // Ensure only organizer can cancel the event
        assert!(tx_context::sender(ctx) == event.organizer, ErrorNotValidBuyer);

        // Get the current time
        let current_time = clock::timestamp_ms(clock);
        let Invoice { id , .. } = invoice;
        // Check if the event is already over
        assert!(current_time < event.end_time, ErrorEventOver);

        // Refund all buyers
        // Implementation of refunding all buyers would go here

        // Delete the event
        object::delete(id);
    }
}
