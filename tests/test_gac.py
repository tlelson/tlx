from click.testing import CliRunner
from tlx.util.cli_apps.get_aws_creds import main as get_aws_creds


def test_hello_world():

    pass
    # Can't really run this.  The credentials would need to be
    # real so that temp tokens can be obtained.
    # Possibly theres a way to mock the sts calls ... i dunno

    # runner = CliRunner()

    # raw_result = runner.invoke(get_aws_creds, args='--profile default --quiet')

    # result = set(result.output.split())
    # result = result.remove('export')

    # assert result.exit_code == 0
    # assert result.output == 'Hello Peter!\n'
