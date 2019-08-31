# -*- coding: utf-8 -*-
cpdef enum Side:
    BUY = 1
    SELL = 2

ctypedef double price_t
ctypedef double qty_t
ctypedef unsigned long long id_t


cdef class OrderInfo:
    """Order info.

    The object is stored in the order book queue for
    basic order information, e.g. order id, price,
    qty and side.
    """

    cdef public:
        id_t order_id
        price_t price
        qty_t qty
        Side side
        qty_t cum_qty
        qty_t leaves_qty

    def __cinit__(self, 
                  id_t order_id,
                  price_t price,
                  qty_t qty,
                  Side side):
        self.order_id = order_id
        self.price = price
        self.qty = qty
        self.side = side
        self.cum_qty = 0
        self.leaves_qty = qty

    cpdef dict __dict__(self):
        return {
            'order_id': self.order_id,
            'price': self.price,
            'qty': self.qty,
            'side': self.side,
            'cum_qty': self.cum_qty,
            'leaves_qty': self.leaves_qty
        }

    def __str__(self):
        return str(self.__dict__())

    def __repr__(self):
        return self.__str__()


cdef class Order:
    """Order.

    The object contains the basic order information and other
    order information, e.g. instrument name.
    """

    cdef public:
        str instmt
        OrderInfo order_info


    def __cinit__(self,
                  str instmt,
                  OrderInfo order_info):
        self.instmt = instmt
        self.order_info = order_info

    cpdef dict __dict__(self):
        return dict({
            'instmt': self.instmt,
            **self.order_info
        })
       
    def __str__(self):
        return str(self.__dict__())

    def __repr__(self):
        return self.__str__()
