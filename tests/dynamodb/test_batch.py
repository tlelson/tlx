import os
import tempfile
import json
from decimal import Decimal
from unittest import TestCase
from unittest.mock import patch
from textwrap import dedent
import tlx.dynamodb.batch


@patch('tlx.dynamodb.batch.get_ddb_table', autospec=True)
@patch('tlx.dynamodb.batch.batch_write', autospec=True)
class TestBatchLoad(TestCase):

    text_input_data = dedent("""
        ID,Name,Last
        N,S,S
        1,Flojo,Jones
        2,Hubert,McFuddle
    """).strip()

    test_bq_data = [
        {"ID": 1, "Name": "Flojo", "Last": "Jones"},
        {"ID": 2, "Name": "Hubert", "Last": "McFuddle"},
    ]

    expected_batch_output = [
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

    def test_load_from_csv1(self, batch_write, get_ddb_table):
        """should form correct item list for boto3 batch_write operation"""

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data

        _, path = tempfile.mkstemp()
        try:
            with open(path, 'w') as f:
                f.write(self.text_input_data)

            # 2.    Check output
            tlx.dynamodb.batch.load_from_csv(path, 'table')
            get_ddb_table.assert_called_once()
            batch_write.assert_called_with('table1', self.expected_batch_output)
        finally:
            os.remove(path)

    def test_load_from_csv_nans_popped(self, batch_write, get_ddb_table):
        """nan and inf are not loaded"""

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data
        _, path = tempfile.mkstemp()
        try:
            with open(path, 'w') as f:
                f.write(self.text_input_data)

            # 2.    Check output
            tlx.dynamodb.batch.load_from_csv(path, 'table')
            get_ddb_table.assert_called_once()
            batch_write.assert_called_with('table1', self.expected_batch_output)
        finally:
            os.remove(path)

    def test_load_from_csv_unsupported_types(self, batch_write, get_ddb_table):
        msg = "unsupported types should raise exception"

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data N.B UNSPPORTED TYPES: List
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
            with self.assertRaises(Exception, msg=msg):
                tlx.dynamodb.batch.load_from_csv(path, 'table')

            get_ddb_table.assert_called_once()
            assert not batch_write.called, 'batch_write should not have been called'
        finally:
            os.remove(path)

    def test_load_from_json_with_id(self, batch_write, get_ddb_table):
        """should form correct item list for boto3 batch_write operation"""

        get_ddb_table.return_value = 'table1'

        # 1.    Get tempfile and write csv data
        _, path = tempfile.mkstemp()
        try:
            # Write to BigQuery style dump file
            with open(path, 'w') as f:
                for row in self.test_bq_data:
                    f.write(json.dumps(row) + '\n')

            # 2.    Check output
            tlx.dynamodb.batch.load_json_dump(path, 'table')
            get_ddb_table.assert_called_once()
            batch_write.assert_called_with('table1', self.expected_batch_output)
        finally:
            os.remove(path)