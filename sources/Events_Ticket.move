module Events_Ticket::Events_Ticket {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, sender};

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
        ticket_price: u64,
        total_tickets: u64,
        tickets_sold: u64
    }

    struct EventCap has key, store {
        id: UID,
        to: ID
    }

    struct Ticket has key, store {
        id: UID,
        event_id: ID,
        owner: address
       
    }

    public fun create_event(name: String, desc: String, start_time: u64, end_time: u64, ticket_price: u64, total_tickets: u64, tickets_sold: u64, ctx: &mut TxContext) : (Event, EventCap) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let event = Event {
            id: id_,
            name,
            desc,
            wallet_balance: balance::zero<SUI>(),
            start_time,
            end_time,
            ticket_price,
            total_tickets,
            tickets_sold
        };
        let cap = EventCap {
            id: object::new(ctx),
            to: inner_
        };
        (event, cap)
    }
    // Buy a ticket for an event
    public fun buy_ticket(event: &mut Event, clock: &Clock, coin: Coin<SUI>, ctx: &mut TxContext) : Ticket {
        // check if event is over
        assert!(clock::timestamp_ms(clock) < event.end_time, ErrorEventOver);
        // check the balance 
        assert!(coin::value(&coin) >= event.ticket_price, ErrorPaymentNotEnough);
        // transfer coin to event wallet
        coin::put(&mut event.wallet_balance, coin);
        // increment tickets sold
        event.tickets_sold = event.tickets_sold + 1;

        let ticket = Ticket {
            id: object::new(ctx),
            event_id: object::uid_to_inner(&event.id),
            owner: sender(ctx)
        };
        ticket
    }

    // // Get Event details
    // public fun get_event(event: &Event) : (&String, &String, &u64, &u64) {
    //     let Event {id, name, desc, wallet_balance, start_time, end_time} = event;
    //     let _id = id;
    //     let _wallet_balance = wallet_balance;
    //     (name, desc, start_time, end_time)
    // }

    // Retrieve all funds from event wallet after event is over
    public fun withdraw(cap: &EventCap, event: &mut Event, ctx: &mut TxContext, clock: &Clock, reciever: address) {
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
    public fun refund_ticket(self: &mut Event, c: &Clock, ctx: &mut TxContext) : Coin<SUI> {
        // check if event is over
        assert!(clock::timestamp_ms(c) < self.end_time, ErrorEventOver);
        // decrement tickets sold
        self.tickets_sold = self.tickets_sold - 1;
        // refund buyer
        let refund_coin = coin::take(&mut self.wallet_balance, self.ticket_price, ctx);
        refund_coin
    }   
}
