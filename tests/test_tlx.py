from unittest import TestCase
# from tlx.dynamodb.cli_apps import dbw
# from click.testing import CliRunner


class TestTLX(TestCase):
    def test_blank(self):
        pass
        # result = CliRunner().invoke(dbw, ['-d', 'some-file', '-t', 'table-name'])
        # self.assertEqual(result.exit_code, 0, msg="CLI app doesn't take name parameter")
        # self.assertEqual(result.output, "Hallo Derrick\n", msg="wrong text displayed")
