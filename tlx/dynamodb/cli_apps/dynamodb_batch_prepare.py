from __future__ import print_function
import json
import click


@click.command(context_settings=dict(max_content_width=120, help_option_names=['-h', '--help']))
@click.option('--dump-file', '-d', required=True, type=click.File('rb'), help="File dumped from dynamodb with.")
@click.option('--table-name', '-n', required=True, help="Table to send data to. Table must exist and key schema must match.  Use `aws dynamodb describe-table --table-name <TableName>`")
def main(dump_file, table_name):
    """
        DYNAMO BATCH PREPARE (dbp)

        \b
        `dynamodb-batch-prepare --help`
        OR
        `dbp --help`

        Takes the output of a `scan` operation such as: `aws dynamodb scan --table-name <TableName>`
        and formats for use by:

        `aws dynamodb batch-write-item --request-items file://output.json`
    """

    scan_data = json.load(dump_file)

    items = scan_data['Items']

    batch_request = {
        table_name: [{"PutRequest": {"Item": item}} for item in items]
    }

    print(json.dumps(batch_request, indent=4, separators=(',', ': '), sort_keys=True))
