from unittest import TestCase

from tlx.apigateway import (APIGException, proxy_response_handler,
                            require_valid_inputs)
from tlx.dynamodb.aux import json_loads


class TestRequireFieldsFound(TestCase):
    def test_raises(self):
        msg = "An exception should be raised if the required fields are not present"

        supplied = {"first": 1, "nineteenth": 2}
        required = {"first", "second"}

        with self.assertRaises(Exception, msg=msg):
            require_valid_inputs(supplied, required)

    def test_passes(self):
        msg = "Nothing should be returned if the required fields are present"

        supplied = {"first": 1, "nineteenth": 2}
        required = {"first"}

        self.assertIsNone(require_valid_inputs(supplied, required), msg)

    def test_bad_params1(self):
        msg = "An exception should be raised if a parameter key is not a hashable type (str, int, float)"

        supplied = [{"first": 1, "nineteenth": 2}]
        required = {"first"}

        with self.assertRaises(Exception, msg=msg):
            require_valid_inputs(supplied, required)

    def test_bad_params2(self):
        msg = "An exception should be raised if a parameter key is not a hashable type (str, int, float)"

        supplied = [True, None]
        required = {"first"}

        with self.assertRaises(Exception, msg=msg):
            require_valid_inputs(supplied, required)


class TestProxyResponseHandler(TestCase):
    apig_event = {"resource": "yoyo", "queryStringParameters": None, "body": None}

    def test_malformed_event(self):
        @proxy_response_handler
        def dummy_handler(event, context):
            print("received: {(event, context)}".format(**locals()))

        dummy_handler({}, {})

    def test_raised_exception_quiet(self):
        msg = "A generic exception should return a PROXY RESPONSE with status 500"

        @proxy_response_handler(quiet=True)
        def dummy_handler(event, context):
            raise Exception

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res["statusCode"], 500, msg)
        body = json_loads(res["body"])
        self.assertEqual(body, {}, msg)

    def test_raised_exception_verbose(self):
        msg = "A exception should return a PROXY RESPONSE with status 500 AND report the exception message"

        @proxy_response_handler(quiet=False)
        def dummy_handler(event, context):
            raise Exception("test")

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res["statusCode"], 500, msg)
        body = json_loads(res["body"])
        self.assertEqual(body, "Error: test", msg)

    def test_raised_exception_running_local(self):
        msg = "When running_local=True the exception should bubble up"

        @proxy_response_handler(running_local=True, quiet=False)
        def dummy_handler(event, context):
            raise Exception("test")

        with self.assertRaises(Exception, msg=msg):
            dummy_handler(self.apig_event, {})

    def test_raised_APIGException(self):
        msg = "Raising an APIGException should return a PROXY RESPONSE with the desired status"

        @proxy_response_handler
        def dummy_handler(event, context):
            raise APIGException("yoyo", code=404)

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res["statusCode"], 404, msg)
        body = json_loads(res["body"])
        self.assertEqual(body, "Error: yoyo", msg)

    def test_200(self):
        msg = "An exception free execution of the handler should return 200 with the results"

        @proxy_response_handler
        def dummy_handler(event, context):
            return "Hallo"

        res = dummy_handler(self.apig_event, {})
        self.assertEqual(res["statusCode"], 200, msg)
        body = json_loads(res["body"])
        self.assertEqual(body, "Hallo", msg)
