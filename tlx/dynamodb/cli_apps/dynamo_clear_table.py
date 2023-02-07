import sys
import click
from tlx.dynamodb.table import clear_table


@click.command(context_settings=dict(max_content_width=120, help_option_names=['-h', '--help']))
@click.option('--table', '-t', required=True, help="Table to clear")
def dbw(table):
    """
        DYNAMO TABLE CLEAR

        WILL IMMEDIATELY DELETE ALL ITEMS WITHOUT CONFIRMATION !

    """

    try:  # Surpress all exceptions for CLI app
        clear_table(table)
    except Exception as e:
        print("{}: {}".format(type(e).__name__, e))
        sys.exit(1)
