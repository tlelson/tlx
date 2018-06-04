import os
import tempfile
from decimal import Decimal
from unittest import TestCase
from unittest.mock import patch
from textwrap import dedent
import tlx.dynamodb.batch


@patch('tlx.dynamodb.batch.get_ddb_table', autospec=True)
@patch('tlx.dynamodb.batch.batch_write', autospec=True)
class TestBatchCSVLoad(TestCase):

    def test_load_from_csv1(self, batch_write, get_ddb_table):
        msg = "should form correct item list for boto3 batch_write operation"

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data
        text_data = dedent("""
            ID,Name,Last
            N,S,S
            1,Flojo,Jones
            2,Hubert,McFuddle
        """).strip()

        expected_items = [
            {
                'ID': Decimal('1'),
                'Name': 'Flojo',
                'Last': 'Jones'
            },
            {
                'ID': Decimal('2'),
                'Name': 'Hubert',
                'Last': 'McFuddle'
            }
        ]

        _, path = tempfile.mkstemp()
        try:
            with open(path, 'w') as f:
                f.write(text_data)

            # 2.    Check output
            tlx.dynamodb.batch.load_from_csv(path, 'table')
            get_ddb_table.assert_called_once()
            batch_write.assert_called_with('table1', expected_items)
        finally:
            os.remove(path)

    def test_load_from_csv_nans_popped(self, batch_write, get_ddb_table):
        msg = "nan and inf are not loaded"

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data
        text_data = dedent("""
            ID,Name,Last,Age
            N,S,S,N
            1,Flojo,Jones,18
            2,Hubert,McFuddle,Inf
            3,John,Davies,Nan
        """).strip()

        expected_items = [
            {
                'ID': Decimal('1'),
                'Name': 'Flojo',
                'Last': 'Jones',
                'Age': Decimal('18'),
            },
            {
                'ID': Decimal('2'),
                'Name': 'Hubert',
                'Last': 'McFuddle',
            },
            {
                'ID': Decimal('3'),
                'Name': 'John',
                'Last': 'Davies',
            }
        ]

        _, path = tempfile.mkstemp()
        try:
            with open(path, 'w') as f:
                f.write(text_data)

            # 2.    Check output
            tlx.dynamodb.batch.load_from_csv(path, 'table')
            get_ddb_table.assert_called_once()
            batch_write.assert_called_with('table1', expected_items)
        finally:
            os.remove(path)

    def test_load_from_csv_unsupported_types(self, batch_write, get_ddb_table):
        msg = "unsupported types should raise exception"

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data
        text_data = dedent("""
            ID,Name,Last
            N,S,L
            1,Flojo,['Jones', 'Poo']
            2,Hubert,['McFuddle']
        """).strip()

        _, path = tempfile.mkstemp()
        try:
            with open(path, 'w') as f:
                f.write(text_data)

            # 2.    Check output
            with self.assertRaises(Exception):
                tlx.dynamodb.batch.load_from_csv(path, 'table')

            get_ddb_table.assert_called_once()
            assert not batch_write.called, 'batch_write should not have been called'
        finally:
            os.remove(path)

