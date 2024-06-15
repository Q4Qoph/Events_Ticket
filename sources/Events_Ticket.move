module Events_Ticket::Events_Ticket {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use std::string::{String};

    const ErrorEventOver: u64 = 0;
    const ErrorEventNotOver: u64 = 1;
    const ErrorPaymentNotEnough: u64 = 2;
    const ErrorTicketNotAvailable: u64 = 3;
    const ErrorNotValidBuyer: u64 = 4;
    const Error_not_owner: u64 = 5;

    struct Event has key, store {
        id: UID,
        name: String,
        desc: String,
        wallet_balance: Balance<SUI>,
        start_time: u64,
        end_time: u64,
    }

    struct EventCap has key, store {
        id: UID,
        to: ID
    }

    struct Ticket has key, store {
        id: UID,
        event_id: ID,
        ticket_price: u64,
        total_tickets: u64,
        tickets_sold: u64,
    }

    public fun create_event(name: String, desc: String, start_time: u64, end_time: u64, ctx: &mut TxContext) : (Event, EventCap) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let event = Event {
            id: id_,
            name,
            desc,
            wallet_balance: balance::zero<SUI>(),
            start_time,
            end_time,
        };
        let cap = EventCap {
            id: object::new(ctx),
            to: inner_
        };
        (event, cap)
    }

    // Create a ticket assigned to an Event
    public fun create_ticket(event: &mut Event, ticket_price: u64, total_tickets: u64, ctx: &mut TxContext): Ticket {
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
        

        // transfer buyer_coin_payment to event wallet
        let coin_balance = coin::into_balance(buyer_coin_payment);
        balance::join(&mut event.wallet_balance, coin_balance);

        // increment tickets sold
        ticket.tickets_sold = ticket.tickets_sold + 1;
    }

    // Get Event details
    public fun get_event(event: &Event) : (&String, &String, &u64, &u64) {
        let Event {id, name, desc, wallet_balance, start_time, end_time} = event;
        let _id = id;
        let _wallet_balance = wallet_balance;
        (name, desc, start_time, end_time)
    }

    // Retrieve all funds from event wallet after event is over
    public fun retrieve_funds(cap: &EventCap, event: &mut Event, ctx: &mut TxContext, clock: &Clock, reciever: address) {
        assert!(object::id(event) == cap.to, Error_not_owner);
        // check if event is over
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > event.end_time, ErrorEventNotOver);

        // get funds from event wallet
        let amount = balance::value(&event.wallet_balance);
        let take_coin = coin::take(&mut event.wallet_balance, amount, ctx);

        // transfer funds to reciever
        transfer::public_transfer(take_coin, reciever);
    }

    // Refund a ticket
    public fun refund_ticket(ticket: &mut Ticket, event: &mut Event, c: &Clock, ctx: &mut TxContext) : Coin<SUI> {
        // check if event is over
        let current_time = clock::timestamp_ms(c);
        assert!(current_time < event.end_time, ErrorEventOver);
        // check if ticket is available
        assert!(ticket.tickets_sold > 0, ErrorTicketNotAvailable);
        // decrement tickets sold
        ticket.tickets_sold = ticket.tickets_sold - 1;
        // refund buyer
        let ticket_price = ticket.ticket_price;
        let refund_coin = coin::take(&mut event.wallet_balance, ticket_price, ctx);
        refund_coin
    
    }   
}
