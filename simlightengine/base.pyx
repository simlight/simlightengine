# -*- coding: utf-8 -*-
from cpython.ref cimport PyObject
from cython.operator cimport dereference, preincrement 
from libc.stdlib cimport malloc, free
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.pair cimport pair


cpdef enum Side:
    BUY = 1
    SELL = 2


ctypedef double price_t
ctypedef long long nprice_t
ctypedef double qty_t
ctypedef unsigned long long id_t
ctypedef Side side_t
ctypedef PyObject* PyObjectPtr

DEF EPSILON = 1e-10
DEF MAX_NPRICE = 9223372036854775807
DEF MIN_NPRICE = -9223372036854775807


cdef struct OrderInfo:
    id_t order_id
    price_t price
    qty_t qty
    side_t side
    qty_t cum_qty
    qty_t leaves_qty

ctypedef OrderInfo* OrderInfoPtr
ctypedef map[id_t, OrderInfo] queue_t


cdef struct TradeInfo:
    id_t trade_id
    price_t trade_price
    qty_t trade_qty


cpdef enum OrdStatus:
    NEW = 2
    REPLACED = 3
    PARTIALLY_FILLED = 4
    CANCELED = 5
    FILLED = 8


cdef class ExecutionReport:
    """Execution report.

    In an execution report, the attribute `order_status` is
    used to convey the current state of the order.
    """

    cdef public:
        OrdStatus order_status
        str instmt
        OrderInfo order_info
        TradeInfo trade_info

    def __init__(self,
                 OrdStatus order_status,
                 str instmt,
                 OrderInfo order_info,
                 TradeInfo trade_info):
        self.order_status = order_status
        self.instmt = instmt
        self.order_info = order_info
        self.trade_info = trade_info

#     cpdef dict __dict__(self):
#         r = {
#             'order_status': self.order_status,
#             'instmt': self.instmt
#         }

#         if self.order_info is None:
#             r = dict(r, **self.order_info)

#         if self.trade_info is None:
#             r = dict(r, **self.trade_info)

#         return r
       
#     def __str__(self):
#         return str(self.__dict__())

#     def __repr__(self):
#         return self.__str__()


cdef class OrderBook:
    """Order book.

    The object is an order book of a particular instrument and
    it contains bid and ask queues.
    """

    cdef:
        str instmt
        double tick_size
        map[nprice_t, queue_t] bids
        map[nprice_t, queue_t] asks
        id_t curr_order_id
        id_t curr_trade_id

    def __init__(self, str instmt, double tick_size):
        self.tick_size = tick_size
        self.bids = map[nprice_t, queue_t]()
        self.asks = map[nprice_t, queue_t]()
        self.curr_order_id = 0
        self.curr_trade_id = 0

    @property
    def instmt(self):
        return self.instmt

    @property
    def tick_size(self):
        return self.tick_size

    cdef normalize_price(self, price_t price):
        return <nprice_t>(price / self.tick_size + EPSILON)

    cdef id_t get_order_id(self):
        self.curr_order_id += 1
        return self.curr_order_id

    cdef id_t get_trade_id(self):
        self.curr_trade_id += 1
        return self.curr_trade_id

    cdef nprice_t get_market_nprice(self, side):
        if side == Side.BUY:
            if self.asks.size() > 0:
                return dereference(self.asks.begin()).first

            return MAX_NPRICE
        else:
            if self.bids.size() > 0:
                return dereference(self.bids.rbegin()).first

            return MIN_NPRICE

    cdef queue_t* get_market_prices(self, side):
        if side == Side.BUY:
            return &(dereference(self.asks.begin()).second)
        else:
            return &(dereference(self.bids.rbegin()).second)

    cdef OrderInfoPtr get_market_order(self, side):
        return &(dereference(
            dereference(self.get_market_prices(side)).begin()).second)

    cdef void erase_market_order(self, side):
        dereference(self.get_market_prices(side)).erase(
            dereference(self.get_market_prices(side)).begin())

    cdef void erase_empty_market_level(self, side):
        if dereference(self.get_market_prices(side)).size() == 0:
            if side == Side.BUY:
                self.asks.erase(self.get_market_nprice(side))
            else:
                self.bids.erase(self.get_market_nprice(side))

    cpdef list add_order(self,
                         price_t price,
                         qty_t qty,
                         side_t side):
        cdef:
            nprice_t nprice, best_nprice
            qty_t cum_qty, leaves_qty, matched_qty, original_leaves_qty
            id_t order_id, nbbo_order_id
            map[nprice_t, queue_t].iterator level_it
            OrderInfoPtr order_info, nbbo
            list execution_reports
            OrdStatus order_status

        execution_reports = []
        nprice = self.normalize_price(price)
        cum_qty = 0.0
        leaves_qty = qty
        order_id = self.get_order_id()

        # Add the ack response
        order_status = OrdStatus.NEW
        execution_reports.append(
            ExecutionReport(
                order_status,
                self.instmt,
                OrderInfo(
                    order_id,
                    price,
                    qty,
                    side,
                    0,
                    qty),
                TradeInfo(0, 0, 0)))

        best_nprice = self.get_market_nprice(side)

        while (((side == Side.BUY and nprice >= best_nprice) or
                (side == Side.SELL and nprice <= best_nprice)) and
                leaves_qty > EPSILON):
            original_leaves_qty = leaves_qty

            # For each price level, match the quantity
            while (dereference(self.get_market_prices(side)).size() > 0 
                   and leaves_qty > EPSILON):
                # Execute on the matching quantity
                nbbo = self.get_market_order(side)
                matched_qty = min(dereference(nbbo).leaves_qty, leaves_qty)
                dereference(nbbo).leaves_qty = dereference(nbbo).leaves_qty - matched_qty
                dereference(nbbo).cum_qty = dereference(nbbo).cum_qty + matched_qty
                leaves_qty -= matched_qty
                cum_qty += matched_qty

                # Trades on the passive order
                order_status = (
                    OrdStatus.PARTIALLY_FILLED if 
                    dereference(nbbo).leaves_qty > EPSILON
                    else OrdStatus.FILLED)
                execution_reports.append(
                    ExecutionReport(
                        order_status,
                        self.instmt,
                        dereference(nbbo),
                        TradeInfo(
                            self.get_trade_id(),
                            dereference(nbbo).price,
                            matched_qty)))

                # Remove the order if it is fully executed
                if order_status == OrdStatus.FILLED:
                    self.erase_market_order(side)

            # Remove the best price level if no passive order
            # is sitting
            self.erase_empty_market_level(side)

            # Send out the aggressive order trade reports
            order_status = (
                OrdStatus.PARTIALLY_FILLED if 
                leaves_qty > EPSILON
                else OrdStatus.FILLED)
            execution_reports.append(
                ExecutionReport(
                    order_status,
                    self.instmt,
                    OrderInfo(
                        order_id,
                        price,
                        qty,
                        side,
                        original_leaves_qty - leaves_qty,
                        leaves_qty),
                    TradeInfo(
                        self.get_trade_id(),
                        dereference(nbbo).price,
                        matched_qty)))

            # Update the best normalized price
            best_nprice = self.get_market_nprice(side)

        if leaves_qty > EPSILON:
            if side == Side.BUY:
                level_it = self.bids.find(nprice)
                if level_it == self.bids.end():
                    level_it = self.bids.insert(
                        pair[nprice_t, queue_t](nprice, queue_t())).first
            else:
                level_it = self.asks.find(nprice)
                if level_it == self.asks.end():
                    level_it = self.asks.insert(
                        pair[nprice_t, queue_t](nprice, queue_t())).first

            dereference(level_it).second.insert(
                pair[id_t, OrderInfo](
                    order_id,
                    OrderInfo(
                        order_id,
                        price,
                        qty,
                        side,
                        qty - leaves_qty,
                        leaves_qty)))

        return execution_reports

