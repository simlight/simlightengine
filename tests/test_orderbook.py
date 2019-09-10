#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Tests for `simlightengine` package."""
import pytest

from simlightengine.base import (
    Side, OrderBook, OrdStatus)

EPILSON = 1e-10


@pytest.fixture
def order_book():
    return OrderBook(
        instmt='GCH9M9',
        tick_size=0.01)


def add_and_check_order(order_book, price, qty, side):
    ers = order_book.add_order(
        price=price,
        qty=qty,
        side=side)
    assert ers[0].order_status == OrdStatus.NEW
    assert ers[0].instmt == order_book.instmt
    assert abs(ers[0].order_info['price'] - price) < EPILSON
    assert abs(ers[0].order_info['qty'] - qty) < EPILSON
    assert ers[0].order_info['side'] == side
    assert ers[0].order_info['cum_qty'] < EPILSON
    assert abs(ers[0].order_info['leaves_qty'] - qty) < EPILSON

    return ers


def check_order_id(report, id):
    assert report.order_info['order_id'] == id


def check_trades(reports, passive_index, active_index, trade_price):
    total_trade_qty = 0
    for idx in passive_index:
        assert abs(reports[idx].trade_info['trade_price'] - trade_price) < EPILSON
        total_trade_qty += reports[idx].trade_info['trade_qty']


    assert abs(reports[active_index].trade_info['trade_price'] - trade_price) < EPILSON
    assert abs(reports[active_index].trade_info['trade_qty'] - total_trade_qty) < EPILSON


def test_add_order_simple(order_book):
    ers = add_and_check_order(order_book, 1.0, 1.0, Side.BUY)
    assert len(ers) == 1
    check_order_id(ers[0], 1)


def test_add_and_execute_order(order_book):
    ers = add_and_check_order(order_book, 1.0, 1.0, Side.BUY)
    assert len(ers) == 1
    check_order_id(ers[0], 1)

    ers = add_and_check_order(order_book, -1.0, 1.0, Side.SELL)
    assert len(ers) == 3
    check_order_id(ers[0], 2)

    check_trades(
        reports=ers,
        passive_index=[1],
        active_index=2,
        trade_price=1.0)
