import sys
import click
from tlx.dynamodb.batch import load_data


@click.command(context_settings=dict(max_content_width=120, help_option_names=['-h', '--help']))
@click.option('--dump-file', '-d', required=True, type=click.File('rb'), help="File dumped from dynamodb with a `scan`.")
@click.option('--table', '-t', required=True, help="Table to send data to. Table must exist and key schema must match.  Use `aws dynamodb describe-table --table-name <TableName>`")
def dbw(dump_file, table=None):
    """
        DYNAMO BATCH WRITE

        Loads the results of a scan opperation into a table.

        \b
        Details:
        Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>`
        and writes to an existing table. Similar to the `aws dynamodb batch-write-item` command except:
            - No limit to amount of items in the upload (25 with awscli)
            - Take the output of a table scan, requiring no reformatting
    """

    try:  # Surpress all exceptions for CLI app
        load_data(dump_file, table)
    except Exception as e:
        print("{}: {}".format(type(e).__name__, e))
        sys.exit(1)
